import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/media_source.dart';
import 'package:stream_hub/core/media/enums/media_source_state.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/events/media_event_bus.dart';
import 'package:stream_hub/core/media/events/media_event.dart';
import 'package:stream_hub/data/models/m3u_models.dart';
import 'package:stream_hub/data/models/media_health.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/media_statistics.dart';
import 'package:stream_hub/data/parsers/m3u_parser.dart';
import 'package:stream_hub/data/services/m3u_download_service.dart';
import 'package:stream_hub/data/services/playlist_cache_service.dart';
import 'package:stream_hub/data/services/playlist_statistics_service.dart';
import 'package:stream_hub/data/services/playlist_validation_service.dart';

const _kCacheTtl = Duration(hours: 12);

class M3UMediaSource implements MediaSource {
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
    if (cached != null && cached.channels.isNotEmpty) {
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

      _broadcastChannels(playlist.channels);

      final mediaItems = playlist.channels
          .map((c) => c.toMediaItem(_id))
          .toList(growable: false);

      _categoriesController.add(_buildCategoryItems(playlist.channels));

      state = MediaSourceState.connected;

      if (_eventBus != null) {
        _eventBus.publish(CatalogUpdatedEvent(
          sourceId: _id,
          addedItems: mediaItems.length,
          occurredAt: DateTime.now(),
        ));
      }

      _logger.info(
        'M3U source synced: ${mediaItems.length} channels in ${stopwatch.elapsedMilliseconds}ms',
        tag: 'M3UMediaSource',
      );

      return MediaSyncResult(
        sourceId: _id,
        success: true,
        added: mediaItems.length,
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

  @override
  Future<bool> validate() async {
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
    final cached = await _cacheService.getCachedPlaylist(_id);
    if (cached == null) {
      return MediaStatistics(lastSync: DateTime.now());
    }

    final stats = cached.statistics;
    return MediaStatistics(
      totalItems: stats.totalItems,
      channels: stats.channels + stats.radioCount,
      movies: 0,
      series: 0,
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
    final cached = await _cacheService.getCachedPlaylist(_id);
    if (cached == null) return [];
    return _buildCategoryItems(cached.channels);
  }

  @override
  Future<List<MediaItem>> getChannels() async {
    final cached = await _cacheService.getCachedPlaylist(_id);
    if (cached == null) return [];
    return cached.channels.map((c) => c.toMediaItem(_id)).toList();
  }

  @override
  Future<List<MediaItem>> getMovies() async => [];

  @override
  Future<List<MediaItem>> getSeries() async => [];

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
