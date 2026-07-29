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
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/models/media_health.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/media_statistics.dart';
import 'package:stream_hub/data/parsers/xmltv_parser.dart';
import 'package:stream_hub/data/services/xmltv_download_service.dart';
import 'package:stream_hub/data/services/xmltv_cache_service.dart';
import 'package:stream_hub/data/services/xmltv_merge_service.dart';
import 'package:stream_hub/data/services/xmltv_statistics_service.dart';
import 'package:stream_hub/data/matchers/channel_matcher.dart';
import 'package:stream_hub/data/engines/epg_engine.dart';
import 'package:stream_hub/data/engines/timeline_engine.dart';

const _kCacheTtl = Duration(hours: 24);

class XMLTVMediaSource implements MediaSource {
  final String _id;
  final XMLTVConfig config;
  final MediaEventBus? _eventBus;

  @override
  String get id => _id;

  @override
  MediaSourceType get type => MediaSourceType.xmltv;

  MediaSourceState _state = MediaSourceState.created;

  @override
  MediaSourceState get state => _state;

  set state(MediaSourceState value) => _state = value;

  @override
  MediaEventBus? get eventBus => _eventBus;

  final LoggingService _logger;
  final XMLTVDownloadService _downloadService;
  final XMLTVParser _parser;
  final XMLTVCacheService _cacheService;
  final XMLTVMergeService _mergeService;
  final XMLTVStatisticsService _statisticsService;
  final ChannelMatcher _channelMatcher;
  final EPGEngine _epgEngine;
  final TimelineEngine _timelineEngine;

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

  XMLTVMediaSource({
    required String id,
    required this.config,
    MediaEventBus? eventBus,
    XMLTVDownloadService? downloadService,
    XMLTVParser? parser,
    XMLTVCacheService? cacheService,
    XMLTVMergeService? mergeService,
    XMLTVStatisticsService? statisticsService,
    ChannelMatcher? channelMatcher,
    EPGEngine? epgEngine,
    TimelineEngine? timelineEngine,
    LoggingService? logger,
  })  : _id = id,
        _eventBus = eventBus,
        _logger = logger ?? Get.find<LoggingService>(),
        _downloadService = downloadService ?? XMLTVDownloadService(Get.find<LoggingService>()),
        _parser = parser ?? XMLTVParser(),
        _cacheService = cacheService ?? Get.find<XMLTVCacheService>(),
        _mergeService = mergeService ?? Get.find<XMLTVMergeService>(),
        _statisticsService = statisticsService ?? Get.find<XMLTVStatisticsService>(),
        _channelMatcher = channelMatcher ?? Get.find<ChannelMatcher>(),
        _epgEngine = epgEngine ?? Get.find<EPGEngine>(),
        _timelineEngine = timelineEngine ?? Get.find<TimelineEngine>();

  @override
  Future<void> initialize() async {
    _logger.info('Initializing XMLTV source: $_id', tag: 'XMLTVMediaSource');
    state = MediaSourceState.initializing;

    if (_eventBus != null) {
      _eventBus.publish(SyncStartedEvent(sourceId: _id, occurredAt: DateTime.now()));
    }

    final cached = await _cacheService.getCachedGuide(_id);
    if (cached != null && !cached.isExpired && cached.guide.programs.isNotEmpty) {
      _epgEngine.loadGuide(cached.guide);
      _timelineEngine.loadGuide(cached.guide);
      _broadcastChannels(cached.guide.channels);
      _broadcastPrograms(cached.guide.programs);
      _logger.info(
        'Loaded ${cached.guide.channels.length} channels and ${cached.guide.programs.length} programs from cache',
        tag: 'XMLTVMediaSource',
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
    _logger.info('Connecting XMLTV source: $_id', tag: 'XMLTVMediaSource');
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
    _logger.info('Disconnecting XMLTV source: $_id', tag: 'XMLTVMediaSource');
    _currentCancellationToken?.cancel();
    _currentCancellationToken = null;
    state = MediaSourceState.offline;
  }

  @override
  Future<void> dispose() async {
    _logger.info('Disposing XMLTV source: $_id', tag: 'XMLTVMediaSource');
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
    _logger.info('Refreshing XMLTV source: $_id', tag: 'XMLTVMediaSource');
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
    _logger.info('Syncing XMLTV source: $_id', tag: 'XMLTVMediaSource');
    state = MediaSourceState.syncing;

    final stopwatch = Stopwatch()..start();
    _currentCancellationToken?.cancel();
    _currentCancellationToken = CancellationToken();

    try {
      final progressController = StreamController<DownloadProgress>.broadcast();
      late final XMLTVDownloadResult downloadResult;
      try {
        downloadResult = await _downloadService.download(
          config: config,
          progressController: progressController,
          cancellationToken: _currentCancellationToken,
        );
      } finally {
        await progressController.close();
      }

      final guide = _parser.parse(
        downloadResult.content,
        sourceId: _id,
      );

      final matchedChannels = _channelMatcher.matchChannels(
        guide.channels,
      );

      final enrichedGuide = _mergeService.enrichGuide(guide, matchedChannels);

      _epgEngine.storeGuide(enrichedGuide);
      _timelineEngine.loadGuide(enrichedGuide);

      final cache = XMLTVGuideCache(
        sourceId: _id,
        guide: enrichedGuide,
        contentHash: _cacheService.computeContentHash(downloadResult.content),
        cachedAt: DateTime.now(),
        expiresAt: DateTime.now().add(_kCacheTtl),
        sizeBytes: downloadResult.sizeBytes,
        encoding: downloadResult.encoding,
        version: config.guideVersion,
      );

      await _cacheService.cacheGuide(cache);

      _broadcastChannels(enrichedGuide.channels);
      _broadcastPrograms(enrichedGuide.programs);

      final mediaItems = enrichedGuide.programs
          .map((p) => p.toMediaItem(_id))
          .toList(growable: false);

      _categoriesController.add(_buildCategoryItems(enrichedGuide.programs));

      state = MediaSourceState.connected;

      if (_eventBus != null) {
        _eventBus.publish(CatalogUpdatedEvent(
          sourceId: _id,
          addedItems: mediaItems.length,
          occurredAt: DateTime.now(),
        ));
      }

      _logger.info(
        'XMLTV source synced: ${enrichedGuide.channels.length} channels, ${enrichedGuide.programs.length} programs in ${stopwatch.elapsedMilliseconds}ms',
        tag: 'XMLTVMediaSource',
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
        'XMLTV sync failed for source $_id',
        tag: 'XMLTVMediaSource',
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

    final cached = await _cacheService.getCachedGuide(_id);
    final lastSync = cached?.cachedAt;

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
    final cached = await _cacheService.getCachedGuide(_id);
    if (cached == null) {
      return MediaStatistics(lastSync: DateTime.now());
    }

    final stats = _statisticsService.calculateStatistics(cached.guide);
    return MediaStatistics(
      totalItems: stats.totalPrograms,
      channels: stats.totalChannels,
      movies: 0,
      series: 0,
      episodes: 0,
      programs: stats.totalPrograms,
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
    final cached = await _cacheService.getCachedGuide(_id);
    if (cached == null) return [];
    return _buildCategoryItems(cached.guide.programs);
  }

  @override
  Future<List<MediaItem>> getChannels() async {
    final cached = await _cacheService.getCachedGuide(_id);
    if (cached == null) return [];
    return cached.guide.channels.map((c) => c.toMediaItem(_id)).toList();
  }

  @override
  Future<List<MediaItem>> getMovies() async => [];

  @override
  Future<List<MediaItem>> getSeries() async => [];

  @override
  Future<List<MediaItem>> getPrograms() async {
    final cached = await _cacheService.getCachedGuide(_id);
    if (cached == null) return [];
    return cached.guide.programs.map((p) => p.toMediaItem(_id)).toList();
  }

  void _broadcastChannels(List<XMLTVChannel> channels) {
    final items = channels.map((c) => c.toMediaItem(_id)).toList(growable: false);
    _channelsController.add(items);
  }

  void _broadcastPrograms(List<XMLTVProgram> programs) {
    final items = programs.map((p) => p.toMediaItem(_id)).toList(growable: false);
    _programsController.add(items);
  }

  List<MediaItem> _buildCategoryItems(List<XMLTVProgram> programs) {
    final groups = <String, List<XMLTVProgram>>{};
    for (final program in programs) {
      for (final category in program.categories) {
        groups.putIfAbsent(category, () => []).add(program);
      }
    }

    var categoryIndex = 0;
    return groups.entries.map((entry) {
      final slug = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      final safeSlug = slug.isEmpty ? 'category' : slug;
      final index = categoryIndex++;
      return MediaItem(
        id: '$_id-category-$index-$safeSlug',
        providerId: _id,
        providerType: MediaSourceType.xmltv,
        mediaType: MediaType.collection,
        title: entry.key,
        subtitle: '${entry.value.length} programs',
        genres: [entry.key],
        metadata: {'category': entry.key, 'programCount': entry.value.length},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }).toList(growable: false);
  }
}