import 'dart:async';
import 'package:hive/hive.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/services/free_tv_catalog_builder.dart';
import 'package:stream_hub/data/services/free_tv_reachability_service.dart';
import 'package:stream_hub/data/services/free_tv_service.dart';

/// Repository managing the Free Live TV catalog, caching, favorites, and history.
class FreeTvRepository {
  static const String kBoxCatalog = 'free_tv_catalog';
  static const String kBoxFavorites = 'free_tv_favorites';
  static const String kBoxRecent = 'free_tv_recent';
  static const String kBoxReachability = 'free_tv_reachability';

  static const String kKeyChannels = 'channels_data';
  static const String kKeyCachedAt = 'cached_at';
  static const String kKeyWorkingIds = 'working_ids';
  static const String kKeyWorkingCheckedAt = 'working_checked_at';

  static const Duration kCacheTtl = Duration(hours: 12);
  static const Duration kReachabilityTtl = Duration(hours: 24);
  static const int kMaxRecentChannels = 20;

  final FreeTvService _service;
  final FreeTvReachabilityService _reachability;
  final LoggingService _logger;

  Box? _catalogBox;
  Box? _favoritesBox;
  Box? _recentBox;
  Box? _reachabilityBox;

  final StreamController<Set<String>> _favoritesController =
      StreamController<Set<String>>.broadcast();

  FreeTvRepository({
    FreeTvService? service,
    FreeTvReachabilityService? reachability,
    LoggingService? logger,
  })  : _service = service ?? FreeTvService(),
        _reachability = reachability ?? FreeTvReachabilityService(),
        _logger = logger ?? LoggingService();

  Future<void> _ensureBoxesOpen() async {
    _catalogBox ??= await _openBoxSafe(kBoxCatalog);
    _favoritesBox ??= await _openBoxSafe(kBoxFavorites);
    _recentBox ??= await _openBoxSafe(kBoxRecent);
    _reachabilityBox ??= await _openBoxSafe(kBoxReachability);
  }

  Future<Box> _openBoxSafe(String name) async {
    try {
      if (Hive.isBoxOpen(name)) {
        return Hive.box(name);
      }
      return await Hive.openBox(name);
    } catch (e) {
      _logger.warning('Error opening box $name, attempting reset: $e',
          tag: 'FreeTvRepository');
      try {
        await Hive.deleteBoxFromDisk(name);
        return await Hive.openBox(name);
      } catch (err) {
        _logger.error('Failed to create box $name: $err',
            tag: 'FreeTvRepository');
        rethrow;
      }
    }
  }

  /// Returns the catalog of free channels. Uses local cache if available and not expired.
  Future<List<FreeTvChannel>> getCatalog({bool forceRefresh = false}) async {
    await _ensureBoxesOpen();

    final favorites = getFavoriteIds();

    if (!forceRefresh) {
      final cached = _loadFromCache(favorites);
      if (cached != null && cached.isNotEmpty) {
        _logger.info('Returning ${cached.length} channels from Hive cache.',
            tag: 'FreeTvRepository');
        return cached;
      }
    }

    try {
      final freshChannels = await _service.fetchCatalog();
      if (freshChannels.isNotEmpty) {
        await _saveToCache(freshChannels);
        // Apply favorite states
        return freshChannels.map((ch) {
          final isFav = favorites.contains(ch.id);
          return isFav ? ch.copyWith(isFavorite: true) : ch;
        }).toList();
      }
    } catch (e) {
      _logger.warning(
        'Failed to fetch fresh catalog from API. Checking fallback cache...',
        tag: 'FreeTvRepository',
      );
      final fallback = _loadFromCache(favorites, ignoreExpiry: true);
      if (fallback != null && fallback.isNotEmpty) {
        _logger.info(
          'API failed, but loaded ${fallback.length} channels from fallback cache.',
          tag: 'FreeTvRepository',
        );
        return fallback;
      }
      rethrow;
    }

    return const [];
  }

  /// Returns the curated (recommended) subset of the catalog.
  Future<List<FreeTvChannel>> getRecommended({bool forceRefresh = false}) async {
    final catalog = await getCatalog(forceRefresh: forceRefresh);
    final recommended = catalog
        .where((c) => c.qualityTier == FreeTvQualityTier.recommended)
        .toList();
    recommended.sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
    return recommended;
  }

  /// Returns the catalog filtered to channels known to be working, based on
  /// the cached reachability snapshot.
  ///
  /// Fast and offline-first: it reads cached probe results and never blocks on
  /// a fresh probe. If the cached snapshot is unavailable or stale, call
  /// [refreshWorkingStatus] to re-probe.
  Future<List<FreeTvChannel>> getWorkingCatalog({
    bool forceRefresh = false,
  }) async {
    final catalog = await getCatalog(forceRefresh: forceRefresh);
    await _ensureBoxesOpen();

    // If the snapshot is stale (or being force-refreshed), don't serve it —
    // the caller should re-probe via [refreshWorkingStatus].
    if (forceRefresh || !workingCacheIsFresh()) return const [];

    final workingIds = _loadWorkingIds();
    if (workingIds.isEmpty) return const [];

    final workingSet = workingIds;
    return catalog
        .where((c) => workingSet.contains(c.id))
        .map((c) => c.isWorking == true ? c : c.copyWith(isWorking: true))
        .toList();
  }

  /// Whether the cached reachability snapshot is fresh enough to serve.
  bool workingCacheIsFresh() {
    if (_reachabilityBox == null) return false;
    final checkedAtMs = _reachabilityBox!.get(kKeyWorkingCheckedAt);
    if (checkedAtMs is! int) return false;
    final checkedAt = DateTime.fromMillisecondsSinceEpoch(checkedAtMs);
    return DateTime.now().difference(checkedAt) <= kReachabilityTtl;
  }

  /// Probes [channels] for reachability with a bounded concurrency pool,
  /// persists the results to the Hive cache, and returns the probed channels
  /// (each with `isWorking` set). Results are persisted incrementally so a
  /// partial probe survives an app restart.
  Future<List<FreeTvChannel>> refreshWorkingStatus(
    List<FreeTvChannel> channels, {
    int concurrency = 16,
    Duration timeout = const Duration(seconds: 5),
    int? maxChannels,
  }) async {
    await _ensureBoxesOpen();

    final candidates = maxChannels != null && maxChannels > 0
        ? channels.take(maxChannels).toList()
        : channels;

    _logger.info(
      'Probing reachability for ${candidates.length} Free TV channels '
      '(concurrency: $concurrency)...',
      tag: 'FreeTvRepository',
    );

    final workingIds = _loadWorkingIds().toSet();

    final probed = await _reachability.probeMany(
      candidates,
      concurrency: concurrency,
      timeout: timeout,
      onProbed: (ch) {
        if (ch.isWorking == true) {
          workingIds.add(ch.id);
        } else {
          workingIds.remove(ch.id);
        }
        _persistWorkingIds(workingIds, checkedAt: DateTime.now());
      },
    );

    final workingCount = probed.where((c) => c.isWorking == true).length;
    _logger.info(
      'Reachability probe complete: $workingCount/${probed.length} working.',
      tag: 'FreeTvRepository',
    );
    return probed;
  }

  List<String> _loadWorkingIds() {
    if (_reachabilityBox == null) return const [];
    final raw = _reachabilityBox!.get(kKeyWorkingIds);
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }

  Future<void> _persistWorkingIds(
    Set<String> workingIds, {
    DateTime? checkedAt,
  }) async {
    if (_reachabilityBox == null) return;
    try {
      await _reachabilityBox!.put(kKeyWorkingIds, workingIds.toList());
      if (checkedAt != null) {
        await _reachabilityBox!.put(
          kKeyWorkingCheckedAt,
          checkedAt.millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      _logger.warning('Failed to persist reachability cache: $e',
          tag: 'FreeTvRepository');
    }
  }

  List<FreeTvChannel>? _loadFromCache(Set<String> favorites,
      {bool ignoreExpiry = false}) {
    if (_catalogBox == null) return null;

    final cachedAtMs = _catalogBox!.get(kKeyCachedAt);
    if (cachedAtMs is int && !ignoreExpiry) {
      final cachedTime = DateTime.fromMillisecondsSinceEpoch(cachedAtMs);
      if (DateTime.now().difference(cachedTime) > kCacheTtl) {
        _logger.info('Free TV Hive cache expired.', tag: 'FreeTvRepository');
        return null;
      }
    }

    final rawData = _catalogBox!.get(kKeyChannels);
    if (rawData is List) {
      try {
        final List<FreeTvChannel> channels = [];
        for (final item in rawData) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final ch = FreeTvChannel.fromJson(
              map,
              isFavorite: favorites.contains(map['id']),
            );
            if (ch.hasStream) {
              channels.add(ch);
            }
          }
        }
        return channels;
      } catch (e) {
        _logger.warning('Failed to parse cached channels: $e',
            tag: 'FreeTvRepository');
        return null;
      }
    }
    return null;
  }

  Future<void> _saveToCache(List<FreeTvChannel> channels) async {
    if (_catalogBox == null) return;
    try {
      final rawList = channels.map((c) => c.toJson()).toList();
      await _catalogBox!.put(kKeyChannels, rawList);
      await _catalogBox!.put(kKeyCachedAt, DateTime.now().millisecondsSinceEpoch);
      _logger.info('Saved ${channels.length} channels to Hive cache.',
          tag: 'FreeTvRepository');
    } catch (e) {
      _logger.error('Failed to save catalog to Hive cache: $e',
          tag: 'FreeTvRepository');
    }
  }

  // --- Favorites Management ---

  Set<String> getFavoriteIds() {
    if (_favoritesBox == null) return const {};
    final raw = _favoritesBox!.get('favorite_ids');
    if (raw is List) {
      return raw.map((e) => e.toString()).toSet();
    }
    return const {};
  }

  Future<bool> isFavorite(String channelId) async {
    await _ensureBoxesOpen();
    return getFavoriteIds().contains(channelId);
  }

  Future<bool> toggleFavorite(String channelId) async {
    await _ensureBoxesOpen();
    final favs = getFavoriteIds().toSet();
    final nowFavorite = !favs.contains(channelId);

    if (nowFavorite) {
      favs.add(channelId);
    } else {
      favs.remove(channelId);
    }

    await _favoritesBox!.put('favorite_ids', favs.toList());
    _favoritesController.add(favs);
    return nowFavorite;
  }

  Stream<Set<String>> watchFavorites() => _favoritesController.stream;

  // --- Recently Watched Management ---

  Future<List<FreeTvChannel>> getRecentlyWatched() async {
    await _ensureBoxesOpen();
    if (_recentBox == null) return const [];

    final raw = _recentBox!.get('recent_channels');
    if (raw is List) {
      final favorites = getFavoriteIds();
      final List<FreeTvChannel> recent = [];
      for (final item in raw) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final ch = FreeTvChannel.fromJson(
            map,
            isFavorite: favorites.contains(map['id']),
          );
          recent.add(ch);
        }
      }
      return recent;
    }
    return const [];
  }

  /// Diagnostics metrics from the most recent catalog build.
  FreeTvCatalogDiagnostics? get lastDiagnostics => _service.lastDiagnostics;

  Future<void> recordWatch(FreeTvChannel channel) async {
    await _ensureBoxesOpen();
    if (_recentBox == null) return;

    try {
      final currentRecent = await getRecentlyWatched();
      final updated = <FreeTvChannel>[
        channel.copyWith(lastWatched: DateTime.now()),
        ...currentRecent.where((c) => c.id != channel.id),
      ];

      final capped = updated.take(kMaxRecentChannels).toList();
      final rawList = capped.map((c) => c.toJson()).toList();
      await _recentBox!.put('recent_channels', rawList);
    } catch (e) {
      _logger.warning('Failed to record watched channel: $e',
          tag: 'FreeTvRepository');
    }
  }

  void dispose() {
    _favoritesController.close();
  }
}
