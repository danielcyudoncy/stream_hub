import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_state.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/events/media_event_bus.dart';
import 'package:stream_hub/core/media/media_source.dart';
import 'package:stream_hub/data/models/media_health.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/media_statistics.dart';
import 'package:stream_hub/data/providers/stalker/stalker_portal_client.dart';

/// [MediaSource] implementation for Stalker Portal (MAG/STB middleware)
/// providers.
///
/// Performs a real portal handshake (MAC → token), then ingests live TV
/// channels, VOD movies, series (and their episodes) into the catalog. Stream
/// playback is deferred to [create_link] at play time by
/// `StalkerStreamResolver`.
class StalkerMediaSource implements MediaSource {
  final String _id;
  final String _portalUrl;
  final String _macAddress;
  final String? _deviceId;
  final int _maxRetries;
  final Duration _retryDelay;
  final LoggingService _logger;

  MediaSourceState _state = MediaSourceState.created;
  StalkerPortalClient? _portalClient;
  String? _token;

  List<MediaItem> _cachedCategories = [];
  List<MediaItem> _cachedChannels = [];
  List<MediaItem> _cachedMovies = [];
  List<MediaItem> _cachedSeries = [];
  DateTime _lastSync = DateTime.now();

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

  StalkerMediaSource({
    required String id,
    Map<String, dynamic>? config,
    LoggingService? logger,
  }) : _id = id,
       _portalUrl =
           ((config?['portalUrl'] ?? config?['sourceUrl']) as String? ?? '')
               .replaceAll(RegExp(r'/+$'), ''),
       _macAddress = config?['macAddress'] as String? ?? '',
       _deviceId = config?['deviceId'] as String? ?? config?['serial'] as String?,
       _maxRetries = (config?['maxRetries'] as int? ?? 3).clamp(0, 10).toInt(),
       _retryDelay = Duration(
         seconds: (config?['retryDelay'] as int? ?? 2).clamp(1, 60).toInt(),
       ),
       _logger = logger ?? Get.find<LoggingService>();

  @override
  String get id => _id;

  @override
  MediaSourceType get type => MediaSourceType.stalker;

  @override
  MediaSourceState get state => _state;

  @override
  MediaEventBus? get eventBus => null;

  StalkerPortalClient _getPortalClient() {
    final existing = _portalClient;
    if (existing != null) return existing;
    final client = StalkerPortalClient(
      baseUrl: _portalUrl,
      macAddress: _macAddress,
      serial: _deviceId,
      token: _token,
      logger: _logger,
    );
    _portalClient = client;
    return client;
  }

  @override
  Future<void> initialize() async {
    _state = MediaSourceState.ready;
  }

  @override
  Future<void> connect() async {
    _state = MediaSourceState.connected;
  }

  @override
  Future<void> disconnect() async {
    _state = MediaSourceState.offline;
  }

  @override
  Future<void> dispose() async {
    await _portalClient?.dispose();
    _portalClient = null;
    await _categoriesController.close();
    await _channelsController.close();
    await _moviesController.close();
    await _seriesController.close();
    await _programsController.close();
  }

  @override
  Future<void> refresh() async {
    await sync();
  }

  @override
  Future<MediaSyncResult> sync() async {
    _state = MediaSourceState.syncing;
    final syncStartedAt = DateTime.now();

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      final result = await _trySyncOnce(syncStartedAt);
      if (result != null) return result;

      if (attempt < _maxRetries) {
        final delay = _retryDelay * (1 << attempt);
        _logger.warning(
          'Stalker sync failed, retrying in ${delay.inSeconds}s '
          '(attempt ${attempt + 1}/$_maxRetries)...',
          tag: 'StalkerMediaSource',
        );
        await Future.delayed(delay);
      }
    }

    _state = MediaSourceState.error;
    return MediaSyncResult(
      sourceId: _id,
      success: false,
      error:
          'Could not connect to "$_portalUrl". Check that the server is online '
          'and the MAC address is correct.',
      completedAt: DateTime.now(),
    );
  }

  Future<MediaSyncResult?> _trySyncOnce(DateTime syncStartedAt) async {
    try {
      final client = _getPortalClient();

      final handshake = await client.handshake();
      _token = handshake.token;

      final profile = await client.getProfile();
      final authStatus = profile['auth_status']?.toString();
      if (authStatus != null && authStatus != '1') {
        _state = MediaSourceState.error;
        return MediaSyncResult(
          sourceId: _id,
          success: false,
          error:
              'The portal rejected MAC address "$_macAddress". Check that the '
              'MAC is registered with your provider.',
          completedAt: DateTime.now(),
        );
      }

      final liveCategories = await client.getCategories(StalkerContentType.live);
      final channels = await client.getOrderedList(StalkerContentType.live);
      final vodCategories = await client.getCategories(StalkerContentType.vod);
      final movies = await client.getVodList();
      final seriesCategories =
          await client.getCategories(StalkerContentType.series);
      final series = await client.getSeriesList();

      final categories = _buildCategories(
        liveCategories,
        vodCategories,
        seriesCategories,
        syncStartedAt,
      );
      final channelItems = _buildChannels(channels, liveCategories, syncStartedAt);
      final movieItems = _buildMovies(movies, vodCategories, syncStartedAt);
      final seriesItems = _buildSeries(series, seriesCategories, syncStartedAt);

      // A portal that throttles may answer with empty bodies across the board.
      // Retrying the sync rather than reporting a successful-but-empty library
      // avoids silently losing the user's content on a transient throttle.
      if (channelItems.isEmpty && movieItems.isEmpty && seriesItems.isEmpty) {
        _logger.warning(
          'Stalker sync loaded no media (possibly throttled), will retry',
          tag: 'StalkerMediaSource',
        );
        return null;
      }

      _cachedCategories = categories;
      _cachedChannels = channelItems;
      _cachedMovies = movieItems;
      _cachedSeries = seriesItems;
      _lastSync = DateTime.now();

      _categoriesController.add(categories);
      _channelsController.add(channelItems);
      _moviesController.add(movieItems);
      _seriesController.add(seriesItems);

      _state = MediaSourceState.ready;
      _logger.info(
        'Stalker sync complete: ${channelItems.length} channels, '
        '${movieItems.length} movies, ${seriesItems.length} series',
        tag: 'StalkerMediaSource',
      );

      return MediaSyncResult(
        sourceId: _id,
        success: true,
        added: channelItems.length + movieItems.length + seriesItems.length,
        completedAt: _lastSync,
      );
    } on SocketException catch (e) {
      _logger.warning('Stalker sync network error', tag: 'StalkerMediaSource', error: e);
      return null;
    } on TimeoutException catch (e) {
      _logger.warning('Stalker sync timed out', tag: 'StalkerMediaSource', error: e);
      return null;
    } on StalkerPortalException catch (e) {
      final status = e.statusCode;
      final transient = e.isEmptyResponse ||
          (status != null && const {429, 500, 502, 503, 504}.contains(status));
      if (transient) {
        _logger.warning(
          'Stalker portal throttled (${e.message}), will retry',
          tag: 'StalkerMediaSource',
          error: e,
        );
        return null;
      }
      _state = MediaSourceState.error;
      _logger.error('Stalker portal error during sync', tag: 'StalkerMediaSource', error: e);
      return MediaSyncResult(
        sourceId: _id,
        success: false,
        error: e.message,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      _state = MediaSourceState.error;
      _logger.error('Stalker sync failed', tag: 'StalkerMediaSource', error: e);
      return MediaSyncResult(
        sourceId: _id,
        success: false,
        error: e.toString(),
        completedAt: DateTime.now(),
      );
    }
  }

  List<MediaItem> _buildCategories(
    List<Map<String, dynamic>> live,
    List<Map<String, dynamic>> vod,
    List<Map<String, dynamic>> series,
    DateTime createdAt,
  ) {
    final categories = <MediaItem>[];

    void add(List<Map<String, dynamic>> raw, String type) {
      for (final c in raw) {
        final genreId = c['id']?.toString() ?? '';
        final title = c['title']?.toString() ?? '';
        if (genreId.isEmpty || title.isEmpty) continue;
        categories.add(MediaItem(
          id: 'stalker-$_id-cat-$type-$genreId',
          providerId: _id,
          providerType: MediaSourceType.stalker,
          mediaType: MediaType.collection,
          title: title,
          metadata: {
            'genreId': genreId,
            'genre': title,
            'type': type,
          },
          createdAt: createdAt,
          updatedAt: createdAt,
        ));
      }
    }

    add(live, 'live');
    add(vod, 'vod');
    add(series, 'series');
    return categories;
  }

  List<MediaItem> _buildChannels(
    List<Map<String, dynamic>> raw,
    List<Map<String, dynamic>> categories,
    DateTime createdAt,
  ) {
    final genreNames = _genreNameMap(categories);
    final items = <MediaItem>[];

    for (final c in raw) {
      final streamId = c['id']?.toString() ?? '';
      final name = c['name']?.toString() ?? '';
      if (streamId.isEmpty || name.isEmpty) continue;

      final genreId = c['genre_id']?.toString() ?? '';
      final genreName = genreNames[genreId] ?? genreId;
      final cmd = c['cmd']?.toString() ?? '';
      final logo = c['logo']?.toString() ?? '';
      final number = c['number']?.toString() ?? '';
      final directSource = c['direct_source']?.toString() ?? '';

      items.add(MediaItem(
        id: 'stalker-$_id-live-$streamId',
        providerId: _id,
        providerType: MediaSourceType.stalker,
        mediaType: MediaType.channel,
        title: name,
        subtitle: number.isNotEmpty ? 'CH $number' : null,
        poster: logo.isNotEmpty ? logo : null,
        genres: genreName.isNotEmpty ? [genreName] : [],
        metadata: {
          'type': 'live',
          'cmd': cmd,
          'genreId': genreId,
          'genre': genreName,
          'streamId': streamId,
          'number': number,
          'directSource': directSource,
          if (directSource.isNotEmpty) 'streamUrl': directSource,
          'tvArchive': c['tv_archive'],
          'epgChannelId': c['epg']?.toString() ?? c['epg_name']?.toString() ?? '',
          'portalUrl': _portalUrl,
        },
        createdAt: createdAt,
        updatedAt: createdAt,
      ));
    }

    return items;
  }

  List<MediaItem> _buildMovies(
    List<Map<String, dynamic>> raw,
    List<Map<String, dynamic>> categories,
    DateTime createdAt,
  ) {
    final genreNames = _genreNameMap(categories);
    final items = <MediaItem>[];

    for (final m in raw) {
      final streamId = m['id']?.toString() ?? '';
      final name = m['name']?.toString() ?? '';
      if (streamId.isEmpty || name.isEmpty) continue;

      final genreId = m['genre_id']?.toString() ?? '';
      final genreName = genreNames[genreId] ?? genreId;
      final cmd = m['cmd']?.toString() ?? '';
      final directSource = m['direct_source']?.toString() ?? '';
      final cover = m['cover_big']?.toString() ?? m['cover']?.toString() ?? '';
      final rating = double.tryParse(m['rating_imdb']?.toString() ?? '');

      items.add(MediaItem(
        id: 'stalker-$_id-vod-$streamId',
        providerId: _id,
        providerType: MediaSourceType.stalker,
        mediaType: MediaType.movie,
        title: name,
        description: m['description']?.toString(),
        poster: cover.isNotEmpty ? cover : null,
        backdrop: cover.isNotEmpty ? cover : null,
        genres: genreName.isNotEmpty ? [genreName] : [],
        rating: rating,
        metadata: {
          'type': 'vod',
          'cmd': cmd,
          'genreId': genreId,
          'genre': genreName,
          'streamId': streamId,
          'directSource': directSource,
          if (directSource.isNotEmpty) 'streamUrl': directSource,
          'hd': m['hd'],
          'added': m['added'],
          'portalUrl': _portalUrl,
        },
        createdAt: createdAt,
        updatedAt: createdAt,
      ));
    }

    return items;
  }

  List<MediaItem> _buildSeries(
    List<Map<String, dynamic>> raw,
    List<Map<String, dynamic>> categories,
    DateTime createdAt,
  ) {
    final genreNames = _genreNameMap(categories);
    final items = <MediaItem>[];

    for (final s in raw) {
      final streamId = s['id']?.toString() ?? '';
      final name = s['name']?.toString() ?? '';
      if (streamId.isEmpty || name.isEmpty) continue;

      final genreId = s['genre_id']?.toString() ?? '';
      final genreName = genreNames[genreId] ?? genreId;
      final cmd = s['cmd']?.toString() ?? '';
      final cover = s['cover_big']?.toString() ?? s['cover']?.toString() ?? '';
      final seasons = s['seasons'];
      final seasonsList = seasons is List ? seasons.whereType<Map>().toList() : <Map>[];

      items.add(MediaItem(
        id: 'stalker-$_id-series-$streamId',
        providerId: _id,
        providerType: MediaSourceType.stalker,
        mediaType: MediaType.series,
        title: name,
        poster: cover.isNotEmpty ? cover : null,
        backdrop: cover.isNotEmpty ? cover : null,
        genres: genreName.isNotEmpty ? [genreName] : [],
        metadata: {
          'type': 'series',
          'cmd': cmd,
          'genreId': genreId,
          'genre': genreName,
          'streamId': streamId,
          'seasonCount': seasonsList.length,
          'portalUrl': _portalUrl,
        },
        createdAt: createdAt,
        updatedAt: createdAt,
      ));

      for (final season in seasonsList) {
        final seasonId = season['id']?.toString() ?? '';
        final seasonName = season['name']?.toString() ?? '';
        final episodes = season['episodes'];
        if (episodes is! List) continue;

        for (final e in episodes) {
          if (e is! Map) continue;
          final episodeId = e['id']?.toString() ?? '';
          if (episodeId.isEmpty) continue;

          final episodeName = e['name']?.toString() ?? '';
          final episodeCmd = e['cmd']?.toString() ?? cmd;

          items.add(MediaItem(
            id: 'stalker-$_id-series-$streamId-ep-$episodeId',
            providerId: _id,
            providerType: MediaSourceType.stalker,
            mediaType: MediaType.episode,
            title: episodeName.isNotEmpty ? episodeName : '$name $seasonName',
            subtitle: seasonName.isNotEmpty ? seasonName : null,
            poster: cover.isNotEmpty ? cover : null,
            genres: genreName.isNotEmpty ? [genreName] : [],
            metadata: {
              'type': 'series',
              'cmd': episodeCmd,
              'genreId': genreId,
              'genre': genreName,
              'streamId': episodeId,
              'seriesId': streamId,
              'seriesName': name,
              'seasonId': seasonId,
              'seasonName': seasonName,
              'portalUrl': _portalUrl,
            },
            createdAt: createdAt,
            updatedAt: createdAt,
          ));
        }
      }
    }

    return items;
  }

  Map<String, String> _genreNameMap(List<Map<String, dynamic>> categories) {
    final map = <String, String>{};
    for (final c in categories) {
      final id = c['id']?.toString() ?? '';
      final title = c['title']?.toString() ?? '';
      if (id.isNotEmpty && title.isNotEmpty) map[id] = title;
    }
    return map;
  }

  @override
  Future<bool> validate() async {
    try {
      final client = _getPortalClient();
      if (_token == null) {
        final handshake = await client.handshake();
        _token = handshake.token;
      }
      final profile = await client.getProfile();
      return profile['auth_status']?.toString() == '1';
    } catch (e) {
      return false;
    }
  }

  @override
  Future<MediaHealth> health() async {
    try {
      final client = _getPortalClient();
      final stopwatch = Stopwatch()..start();
      if (_token == null) {
        final handshake = await client.handshake();
        _token = handshake.token;
      }
      final profile = await client.getProfile();
      stopwatch.stop();

      final isAuthenticated = profile['auth_status']?.toString() == '1';
      return MediaHealth(
        isConnected: true,
        latencyMs: stopwatch.elapsedMilliseconds,
        isAuthenticated: isAuthenticated,
        lastSync: _lastSync,
        errors: isAuthenticated ? [] : ['Portal rejected MAC address'],
      );
    } on SocketException catch (e) {
      return MediaHealth(isConnected: false, errors: [e.toString()]);
    } catch (e) {
      return MediaHealth(isConnected: false, errors: [e.toString()]);
    }
  }

  @override
  Future<MediaStatistics> statistics() async {
    final episodes = _cachedSeries
        .where((item) => item.mediaType == MediaType.episode)
        .length;
    return MediaStatistics(
      totalItems: _cachedCategories.length +
          _cachedChannels.length +
          _cachedMovies.length +
          _cachedSeries.length,
      channels: _cachedChannels.length,
      movies: _cachedMovies.length,
      series: _cachedSeries.length - episodes,
      episodes: episodes,
      categories: _cachedCategories.length,
      lastSync: _lastSync,
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
  Future<List<MediaItem>> getCategories() async => _cachedCategories;

  @override
  Future<List<MediaItem>> getChannels() async => _cachedChannels;

  @override
  Future<List<MediaItem>> getMovies() async => _cachedMovies;

  @override
  Future<List<MediaItem>> getSeries() async => _cachedSeries;

  @override
  Future<List<MediaItem>> getPrograms() async => [];
}
