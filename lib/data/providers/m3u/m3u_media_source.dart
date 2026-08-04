import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/account_metadata_provider.dart';
import 'package:stream_hub/core/media/media_source.dart';
import 'package:stream_hub/core/media/enums/media_source_state.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/events/media_event_bus.dart';
import 'package:stream_hub/core/media/events/media_event.dart';
import 'package:stream_hub/data/models/m3u_models.dart';
import 'package:stream_hub/data/models/account_metadata.dart';
import 'package:stream_hub/data/models/media_health.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/media_statistics.dart';
import 'package:stream_hub/data/parsers/m3u_parser.dart';
import 'package:stream_hub/data/providers/m3u/m3u_content_classifier.dart';
import 'package:stream_hub/data/providers/xtream/xtream_media_source.dart';
import 'package:stream_hub/data/providers/xtream/xtream_url_detector.dart';
import 'package:stream_hub/data/services/m3u_download_service.dart';
import 'package:stream_hub/data/services/playlist_cache_service.dart';
import 'package:stream_hub/data/services/playlist_statistics_service.dart';
import 'package:stream_hub/data/services/playlist_validation_service.dart';

const _kCacheTtl = Duration(hours: 12);

class M3UMediaSource implements MediaSource, AccountMetadataProvider {
  final String _id;
  final M3UConfig config;
  final MediaEventBus? _eventBus;

  @override
  String get id => _id;

  @override
  MediaSourceType get type => MediaSourceType.m3u;

  MediaSourceState _state = MediaSourceState.created;

  @override
  MediaSourceState get state => _state;

  set state(MediaSourceState value) => _state = value;

  @override
  MediaEventBus? get eventBus => _eventBus;

  final LoggingService _logger;
  final M3UDownloadService _downloadService;
  final M3UParser _parser;
  final PlaylistCacheService _cacheService;
  final PlaylistValidationService _validationService;
  final PlaylistStatisticsService _statisticsService;

  final StreamController<List<MediaItem>> _categoriesController =
      StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _channelsController =
      StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _moviesController =
      StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _seriesController =
      StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _programsController =
      StreamController<List<MediaItem>>.broadcast();

  CancellationToken? _currentCancellationToken;

  XtreamMediaSource? _xtreamSource;

  /// True when the configured URL is an Xtream panel export (`get.php` /
  /// `player_api.php` with credentials) rather than a plain M3U playlist.
  bool get _isXtreamExport =>
      config.localPath == null &&
      XtreamUrlDetector.isXtreamExport(config.sourceUrl);

  @override
  AccountMetadata? get accountMetadata => _xtreamSource?.accountMetadata;

  M3UMediaSource({
    required String id,
    required this.config,
    MediaEventBus? eventBus,
    M3UDownloadService? downloadService,
    M3UParser? parser,
    PlaylistCacheService? cacheService,
    PlaylistValidationService? validationService,
    PlaylistStatisticsService? statisticsService,
    LoggingService? logger,
  })  : _id = id,
        _eventBus = eventBus,
        _logger = logger ?? Get.find<LoggingService>(),
        _downloadService = downloadService ?? M3UDownloadService(Get.find<LoggingService>()),
        _parser = parser ?? M3UParser(),
        _cacheService = cacheService ?? Get.find<PlaylistCacheService>(),
        _validationService = validationService ?? Get.find<PlaylistValidationService>(),
        _statisticsService = statisticsService ?? Get.find<PlaylistStatisticsService>();

  @override
  Future<void> initialize() async {
    _logger.info('Initializing M3U source: $_id', tag: 'M3UMediaSource');
    state = MediaSourceState.initializing;

    if (_eventBus != null) {
      _eventBus.publish(SyncStartedEvent(sourceId: _id, occurredAt: DateTime.now()));
    }

    final cached = await _cacheService.getCachedPlaylist(_id);
    if (cached != null && cached.channels.isNotEmpty && !_isXtreamExport) {
      _broadcastChannels(cached.channels);
      _logger.info(
        'Loaded ${cached.channels.length} channels from cache',
        tag: 'M3UMediaSource',
      );
    }

    state = MediaSourceState.ready;

    if (_eventBus != null) {
      _eventBus.publish(SyncFinishedEvent(
        sourceId: _id,
        success: true,
        occurredAt: DateTime.now(),
      ));
    }
  }

  @override
  Future<void> connect() async {
    _logger.info('Connecting M3U source: $_id', tag: 'M3UMediaSource');
    state = MediaSourceState.initializing;

    if (_eventBus != null) {
      _eventBus.publish(SyncStartedEvent(sourceId: _id, occurredAt: DateTime.now()));
    }

    try {
      await initialize();
      state = MediaSourceState.ready;
      if (_eventBus != null) {
        _eventBus.publish(MediaSourceConnectedEvent(
          sourceId: _id,
          type: type,
          occurredAt: DateTime.now(),
        ));
      }
    } catch (e) {
      state = MediaSourceState.error;
      if (_eventBus != null) {
        _eventBus.publish(SyncFinishedEvent(
          sourceId: _id,
          success: false,
          error: e.toString(),
          occurredAt: DateTime.now(),
        ));
      }
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _logger.info('Disconnecting M3U source: $_id', tag: 'M3UMediaSource');
    _currentCancellationToken?.cancel();
    _currentCancellationToken = null;
    state = MediaSourceState.offline;
  }

  @override
  Future<void> dispose() async {
    _logger.info('Disposing M3U source: $_id', tag: 'M3UMediaSource');
    _currentCancellationToken?.cancel();
    _currentCancellationToken = null;

    await _categoriesController.close();
    await _channelsController.close();
    await _moviesController.close();
    await _seriesController.close();
    await _programsController.close();

    final delegate = _xtreamSource;
    if (delegate != null) {
      await delegate.dispose();
      _xtreamSource = null;
    }

    state = MediaSourceState.disposed;
  }

  @override
  Future<void> refresh() async {
    _logger.info('Refreshing M3U source: $_id', tag: 'M3UMediaSource');
    if (state == MediaSourceState.disposed) {
      throw const UnknownException(
        message: 'Cannot refresh disposed source',
        code: 'SOURCE_DISPOSED',
      );
    }

    state = MediaSourceState.syncing;
    await sync();
    state = MediaSourceState.connected;
  }

  @override
  Future<MediaSyncResult> sync() async {
    _logger.info('Syncing M3U source: $_id', tag: 'M3UMediaSource');
    state = MediaSourceState.syncing;

    if (_isXtreamExport) {
      return _syncViaXtreamApi();
    }

    final stopwatch = Stopwatch()..start();
    _currentCancellationToken?.cancel();
    _currentCancellationToken = CancellationToken();

    try {
      final progressController = StreamController<DownloadProgress>.broadcast();
      late final String rawContent;
      try {
        rawContent = await _downloadService.download(
          config: config,
          progressController: progressController,
          cancellationToken: _currentCancellationToken,
        );
      } finally {
        await progressController.close();
      }

      final validation = _validationService.validate(rawContent);
      final playlist = _parser.parse(rawContent);

      final stats = _statisticsService.calculateStatistics(playlist, stopwatch.elapsed);

      final hash = _cacheService.computeContentHash(rawContent);
      final now = DateTime.now();
      final cache = M3UPlaylistCache(
        sourceId: _id,
        rawPlaylist: rawContent,
        channels: playlist.channels,
        statistics: stats,
        validation: validation,
        cachedAt: now,
        expiresAt: now.add(_kCacheTtl),
        contentHash: hash,
      );

      await _cacheService.cachePlaylist(cache);

      final liveChannels = <M3UChannel>[];
      final movieChannels = <M3UChannel>[];
      final seriesChannels = <M3UChannel>[];
      for (final channel in playlist.channels) {
        switch (M3UContentClassifier.classify(channel)) {
          case MediaType.movie:
            movieChannels.add(channel);
          case MediaType.series:
            seriesChannels.add(channel);
          default:
            liveChannels.add(channel);
        }
      }

      _broadcastChannels(liveChannels);
      _moviesController.add(
        movieChannels.map((c) => c.toMediaItem(_id, mediaType: MediaType.movie)).toList(),
      );
      _seriesController.add(
        seriesChannels.map((c) => c.toMediaItem(_id, mediaType: MediaType.series)).toList(),
      );

      final mediaItems = liveChannels
          .map((c) => c.toMediaItem(_id))
          .toList(growable: false);
      final totalItems =
          liveChannels.length + movieChannels.length + seriesChannels.length;

      _categoriesController.add(_buildCategoryItems(liveChannels));

      state = MediaSourceState.connected;

      if (_eventBus != null) {
        _eventBus.publish(CatalogUpdatedEvent(
          sourceId: _id,
          addedItems: totalItems,
          occurredAt: DateTime.now(),
        ));
      }

      _logger.info(
        'M3U source synced: ${mediaItems.length} channels, '
        '${movieChannels.length} movies, ${seriesChannels.length} series '
        'in ${stopwatch.elapsedMilliseconds}ms',
        tag: 'M3UMediaSource',
      );

      return MediaSyncResult(
        sourceId: _id,
        success: true,
        added: totalItems,
        updated: 0,
        removed: 0,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      stopwatch.stop();
      state = MediaSourceState.error;

      _logger.error(
        'M3U sync failed for source $_id',
        tag: 'M3UMediaSource',
        error: e,
      );

      if (_eventBus != null) {
        _eventBus.publish(SyncFinishedEvent(
          sourceId: _id,
          success: false,
          error: e.toString(),
          occurredAt: DateTime.now(),
        ));
      }

      return MediaSyncResult(
        sourceId: _id,
        success: false,
        error: e.toString(),
        completedAt: DateTime.now(),
      );
    } finally {
      _currentCancellationToken = null;
    }
  }

  /// Handles URLs that are actually Xtream panel exports by syncing through
  /// the panel's JSON API. This mirrors how mature IPTV apps behave: an M3U
  /// export generated by an Xtream panel can be orders of magnitude larger
  /// than the JSON API and may be impossible to download.
  Future<MediaSyncResult> _syncViaXtreamApi() async {
    final stopwatch = Stopwatch()..start();
    _logger.info(
      'Detected Xtream panel export URL; syncing through the Xtream JSON API '
      'instead of downloading the M3U.',
      tag: 'M3UMediaSource',
    );

    final delegate = _xtreamSource ??= _createXtreamDelegate();
    final result = await delegate.sync();

    if (result.success) {
      _channelsController.add(await delegate.getChannels());
      _moviesController.add(await delegate.getMovies());
      _seriesController.add(await delegate.getSeries());
      _categoriesController.add(await delegate.getCategories());
      state = MediaSourceState.connected;
    } else {
      state = MediaSourceState.error;
    }

    if (_eventBus != null) {
      _eventBus.publish(CatalogUpdatedEvent(
        sourceId: _id,
        addedItems: result.added,
        occurredAt: DateTime.now(),
      ));
    }

    _logger.info(
      'Xtream API sync completed: ${result.added} items in '
      '${stopwatch.elapsedMilliseconds}ms',
      tag: 'M3UMediaSource',
    );

    return result;
  }

  XtreamMediaSource _createXtreamDelegate() {
    final parts = XtreamUrlDetector.parse(config.sourceUrl);
    final xtreamConfig = <String, dynamic>{
      'sourceUrl': parts?.serverUrl ?? config.sourceUrl,
      'username': parts?.username ?? config.username ?? '',
      'password': parts?.password ?? config.password ?? '',
    };
    return XtreamMediaSource(id: _id, config: xtreamConfig, logger: _logger);
  }

  @override
  Future<bool> validate() async {
    if (_isXtreamExport) {
      final delegate = _xtreamSource;
      if (delegate != null) return delegate.validate();
      return true;
    }

    if (config.sourceUrl.isEmpty && config.localPath == null) {
      return false;
    }

    if (config.localPath != null) {
      final file = File(config.localPath!);
      return await file.exists();
    }

    if (config.username != null || config.password != null) {
      return true;
    }

    try {
      final uri = Uri.parse(config.sourceUrl);
      if (!uri.isAbsolute) return false;
      if (uri.scheme == 'http' || uri.scheme == 'https') return true;
      return uri.userInfo.isNotEmpty;
    } on FormatException {
      return false;
    }
  }

  @override
  Future<MediaHealth> health() async {
    final delegate = _xtreamSource;
    if (delegate != null) return delegate.health();

    final errors = <String>[];
    bool isConnected = false;
    int latencyMs = 0;

    if (state == MediaSourceState.connected) {
      isConnected = true;
    }

    try {
      final stopwatch = Stopwatch()..start();
      final result = await validate();
      stopwatch.stop();
      latencyMs = stopwatch.elapsedMilliseconds;

      if (!result) {
        errors.add('Source validation failed');
      }
    } catch (e) {
      errors.add('Health check failed: $e');
    }

    final cached = await _cacheService.getCachedPlaylist(_id);
    final lastSync = cached?.statistics.lastSync;

    return MediaHealth(
      isConnected: isConnected,
      latencyMs: latencyMs,
      isAuthenticated: config.username != null || config.password != null,
      lastSync: lastSync,
      errors: errors,
    );
  }

  @override
  Future<MediaStatistics> statistics() async {
    final delegate = _xtreamSource;
    if (delegate != null) return delegate.statistics();

    final cached = await _cacheService.getCachedPlaylist(_id);
    if (cached == null) {
      return MediaStatistics(lastSync: DateTime.now());
    }

    final stats = cached.statistics;
    var movieCount = 0;
    var seriesCount = 0;
    for (final channel in cached.channels) {
      switch (M3UContentClassifier.classify(channel)) {
        case MediaType.movie:
          movieCount++;
        case MediaType.series:
          seriesCount++;
        default:
          break;
      }
    }
    return MediaStatistics(
      totalItems: stats.totalItems,
      channels: stats.channels + stats.radioCount,
      movies: movieCount,
      series: seriesCount,
      episodes: 0,
      programs: 0,
      categories: stats.categories,
      syncDuration: stats.syncDuration,
      lastSync: stats.lastSync,
    );
  }

  @override
  Stream<List<MediaItem>> get categoriesStream => _categoriesController.stream;

  @override
  Stream<List<MediaItem>> get channelsStream => _channelsController.stream;

  @override
  Stream<List<MediaItem>> get moviesStream => _moviesController.stream;

  @override
  Stream<List<MediaItem>> get seriesStream => _seriesController.stream;

  @override
  Stream<List<MediaItem>> get programsStream => _programsController.stream;

  @override
  Future<List<MediaItem>> getCategories() async {
    final delegate = _xtreamSource;
    if (delegate != null) return delegate.getCategories();

    final cached = await _cacheService.getCachedPlaylist(_id);
    if (cached == null) return [];
    return _buildCategoryItems(cached.channels);
  }

  @override
  Future<List<MediaItem>> getChannels() async {
    final delegate = _xtreamSource;
    if (delegate != null) return delegate.getChannels();

    final cached = await _cacheService.getCachedPlaylist(_id);
    if (cached == null) return [];
    return cached.channels
        .where((c) => M3UContentClassifier.classify(c) == MediaType.channel)
        .map((c) => c.toMediaItem(_id))
        .toList();
  }

  @override
  Future<List<MediaItem>> getMovies() async {
    final delegate = _xtreamSource;
    if (delegate != null) return delegate.getMovies();

    final cached = await _cacheService.getCachedPlaylist(_id);
    if (cached == null) return [];
    return cached.channels
        .where((c) => M3UContentClassifier.classify(c) == MediaType.movie)
        .map((c) => c.toMediaItem(_id, mediaType: MediaType.movie))
        .toList();
  }

  @override
  Future<List<MediaItem>> getSeries() async {
    final delegate = _xtreamSource;
    if (delegate != null) return delegate.getSeries();

    final cached = await _cacheService.getCachedPlaylist(_id);
    if (cached == null) return [];
    return cached.channels
        .where((c) => M3UContentClassifier.classify(c) == MediaType.series)
        .map((c) => c.toMediaItem(_id, mediaType: MediaType.series))
        .toList();
  }

  @override
  Future<List<MediaItem>> getPrograms() async => [];

  void _broadcastChannels(List<M3UChannel> channels) {
    final items = channels.map((c) => c.toMediaItem(_id)).toList(growable: false);
    _channelsController.add(items);
  }

  List<MediaItem> _buildCategoryItems(List<M3UChannel> channels) {
    final groups = <String, List<M3UChannel>>{};
    for (final channel in channels) {
      final group = channel.group ?? 'Ungrouped';
      groups.putIfAbsent(group, () => []).add(channel);
    }

    var categoryIndex = 0;
    return groups.entries.map((entry) {
      final slug = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      final safeSlug = slug.isEmpty ? 'group' : slug;
      final index = categoryIndex++;
      return MediaItem(
        id: '$_id-category-$index-$safeSlug',
        providerId: _id,
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.collection,
        title: entry.key,
        subtitle: '${entry.value.length} channels',
        genres: [entry.key],
        metadata: {'group': entry.key, 'channelCount': entry.value.length},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }).toList(growable: false);
  }
}
