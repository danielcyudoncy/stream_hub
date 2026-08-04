import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/account_metadata_provider.dart';
import 'package:stream_hub/core/media/enums/media_source_state.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/events/media_event_bus.dart';
import 'package:stream_hub/core/media/media_source.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';
import 'package:stream_hub/data/models/account_metadata.dart';
import 'package:stream_hub/data/models/media_health.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/media_statistics.dart';

/// Full Xtream Codes media source.
///
/// Synchronizes the complete panel catalog into normalized [MediaItem]s:
///
/// - Live TV channels (`action=live`) and live categories
/// - VOD movies (`action=get_vod_streams`) and movie categories
/// - Series (`action=get_series`) and series categories
///
/// Live and movie items carry an authenticated `streamUrl` in their metadata so
/// they play directly. Series items carry only a `seriesId`; their first
/// playable episode is resolved lazily at play time through the
/// `XtreamStreamResolver` (`action=get_series_info`).
///
/// The source never talks to the UI or the player; it only produces normalized
/// media models.
class XtreamMediaSource implements MediaSource, AccountMetadataProvider {
  static const Duration _kRequestTimeout = Duration(seconds: 20);

  final String _id;
  final String _serverUrl;
  final String _username;
  final String _password;
  final int _maxRetries;
  final Duration _retryDelay;
  final LoggingService _logger;
  final HttpClient _client = createDohAwareHttpClient();

  MediaSourceState _state = MediaSourceState.created;

  AccountMetadata? _accountMetadata;

  @override
  AccountMetadata? get accountMetadata => _accountMetadata;

  List<MediaItem> _cachedChannels = [];
  List<MediaItem> _cachedCategories = [];
  List<MediaItem> _cachedMovies = [];
  List<MediaItem> _cachedSeries = [];
  DateTime _lastSync = DateTime.now();

  @override
  String get id => _id;

  @override
  MediaSourceType get type => MediaSourceType.xtream;

  @override
  MediaSourceState get state => _state;

  @override
  MediaEventBus? get eventBus => null;

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

  XtreamMediaSource({
    required String id,
    Map<String, dynamic>? config,
    LoggingService? logger,
  })  : _id = id,
        _serverUrl = _normalizeServerUrl(config?['sourceUrl'] as String? ?? ''),
        _username = config?['username'] as String? ?? '',
        _password = config?['password'] as String? ?? '',
        _maxRetries = (config?['maxRetries'] as int? ?? 3).clamp(0, 10).toInt(),
        _retryDelay = Duration(
          seconds: (config?['retryDelay'] as int? ?? 2).clamp(1, 60).toInt(),
        ),
        _logger = logger ?? Get.find<LoggingService>();

  static String _normalizeServerUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return '';
    if (!url.contains('://')) {
      url = 'http://$url';
    }
    return url.replaceAll(RegExp(r'/+$'), '');
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
    _client.close(force: true);
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
          'Xtream sync failed, retrying in ${delay.inSeconds}s '
          '(attempt ${attempt + 1}/$_maxRetries)...',
          tag: 'XtreamMediaSource',
        );
        await Future.delayed(delay);
      }
    }

    _state = MediaSourceState.error;
    return MediaSyncResult(
      sourceId: _id,
      success: false,
      error:
          'Could not connect to "$_serverUrl". Check that the server is '
          'online and the URL is correct.',
      completedAt: DateTime.now(),
    );
  }

  Future<MediaSyncResult?> _trySyncOnce(DateTime syncStartedAt) async {
    try {
      final accountMetadata = await _fetchAccountMetadata();
      if (accountMetadata != null) {
        _accountMetadata = accountMetadata;
      }

      final results = await Future.wait<dynamic>([
        _fetchLiveChannels(syncStartedAt),
        _fetchLiveCategories(syncStartedAt),
        _fetchMovies(syncStartedAt),
        _fetchSeries(syncStartedAt),
      ], eagerError: false);

      _cachedChannels = results[0] as List<MediaItem>;
      _cachedCategories = results[1] as List<MediaItem>;
      _cachedMovies = results[2] as List<MediaItem>;
      _cachedSeries = results[3] as List<MediaItem>;
      _lastSync = DateTime.now();

      _channelsController.add(_cachedChannels);
      _categoriesController.add(_cachedCategories);
      _moviesController.add(_cachedMovies);
      _seriesController.add(_cachedSeries);

      _state = MediaSourceState.ready;
      _logger.info(
        'Xtream sync complete: ${_cachedChannels.length} channels, '
        '${_cachedMovies.length} movies, ${_cachedSeries.length} series, '
        '${_cachedCategories.length} categories',
        tag: 'XtreamMediaSource',
      );

      return MediaSyncResult(
        sourceId: _id,
        success: true,
        added:
            _cachedChannels.length +
            _cachedMovies.length +
            _cachedSeries.length +
            _cachedCategories.length,
        completedAt: _lastSync,
      );
    } on SocketException catch (e) {
      _logger.warning('Xtream sync network error', tag: 'XtreamMediaSource', error: e);
      return null;
    } on TimeoutException catch (e) {
      _logger.warning('Xtream sync timed out', tag: 'XtreamMediaSource', error: e);
      return null;
    } catch (e, s) {
      _state = MediaSourceState.error;
      _logger.error('Xtream sync failed', tag: 'XtreamMediaSource', error: e, stackTrace: s);
      return MediaSyncResult(
        sourceId: _id,
        success: false,
        error: e.toString(),
        completedAt: DateTime.now(),
      );
    }
  }

  Future<List<MediaItem>> _fetchLiveChannels(DateTime createdAt) async {
    var payload = await _fetchJson('action=live');
    var data = _extractData(payload);

    if (data == null) {
      // Some panels do not implement action=live and only answer the
      // action=get_live_streams endpoint. Fall back before giving up.
      payload = await _fetchJson('action=get_live_streams');
      data = _extractData(payload);
    }

    if (data == null) return [];

    final channels = <MediaItem>[];
    for (final item in data) {
      if (item is! Map) continue;
      final streamId = item['stream_id']?.toString();
      if (streamId == null || streamId.isEmpty) continue;

      final ext = _liveStreamExtension(item['container_extension']?.toString());
      final name = _asString(item['name']) ?? 'Unknown';
      final categoryId = item['category_id']?.toString() ?? '';

      final streamUrl = _liveStreamUrl(streamId, ext);

      channels.add(
        MediaItem(
          id: 'xtream-live-$streamId',
          providerId: _id,
          providerType: MediaSourceType.xtream,
          mediaType: MediaType.channel,
          title: name,
          subtitle: _asString(item['epg_channel_id']),
          poster: (_asString(item['stream_icon']) ?? '').isNotEmpty
              ? _asString(item['stream_icon'])
              : null,
          genres: categoryId.isNotEmpty ? [categoryId] : [],
          metadata: _liveMetadata(item, streamId, streamUrl, categoryId),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
    }

    return channels;
  }

  Map<String, dynamic> _liveMetadata(
    Map item,
    String streamId,
    String streamUrl,
    String categoryId,
  ) {
    return {
      'streamUrl': streamUrl,
      'streamId': streamId,
      'categoryId': categoryId,
      'epgChannelId': _asString(item['epg_channel_id']) ?? '',
      'streamIcon': _asString(item['stream_icon']) ?? '',
      'tvArchive': item['tv_archive'],
      'tvArchiveDuration': item['tv_archive_duration'],
      'resolution': _asString(item['stream_type']) ?? '',
      'isLive': true,
    };
  }

  Future<List<MediaItem>> _fetchMovies(DateTime createdAt) async {
    final data = _extractData(await _fetchJson('action=get_vod_streams'));
    if (data == null) return [];

    final movies = <MediaItem>[];
    for (final item in data) {
      if (item is! Map) continue;
      final streamId = item['stream_id']?.toString();
      if (streamId == null || streamId.isEmpty) continue;

      final ext = _extension(item['container_extension']?.toString());
      final name = _asString(item['name']) ?? 'Unknown';
      final categoryId = item['category_id']?.toString() ?? '';

      final streamUrl = _movieStreamUrl(streamId, ext);
      final poster = (_asString(item['stream_icon']) ?? '').isNotEmpty
          ? _asString(item['stream_icon'])
          : null;

      movies.add(
        MediaItem(
          id: 'xtream-movie-$streamId',
          providerId: _id,
          providerType: MediaSourceType.xtream,
          mediaType: MediaType.movie,
          title: name,
          poster: poster,
          backdrop: (_asString(item['backdrop_path']) ?? '').isNotEmpty
              ? _asString(item['backdrop_path'])
              : null,
          genres: categoryId.isNotEmpty ? [categoryId] : [],
          rating: _parseRating(item['rating']),
          description: _asString(item['plot']),
          metadata: _vodMetadata(item, streamId, streamUrl, categoryId),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
    }

    return movies;
  }

  Map<String, dynamic> _vodMetadata(
    Map item,
    String streamId,
    String streamUrl,
    String categoryId,
  ) {
    return {
      'streamUrl': streamUrl,
      'streamId': streamId,
      'categoryId': categoryId,
      'containerExtension': _asString(item['container_extension']) ?? '',
      'genre': _asString(item['genre']) ?? '',
      'plot': _asString(item['plot']) ?? '',
      'year': _asString(item['year']) ?? '',
      'duration': _asString(item['duration']) ?? '',
      'rating': _asString(item['rating']) ?? '',
      'added': _asString(item['added']) ?? '',
      'directSource': _asString(item['direct_source']) ?? '',
      'backdropPath': _asString(item['backdrop_path']) ?? '',
      'isVod': true,
    };
  }

  Future<List<MediaItem>> _fetchSeries(DateTime createdAt) async {
    final data = _extractData(await _fetchJson('action=get_series'));
    if (data == null) return [];

    final series = <MediaItem>[];
    for (final item in data) {
      if (item is! Map) continue;
      final seriesId = item['series_id']?.toString();
      if (seriesId == null || seriesId.isEmpty) continue;

      final name = _asString(item['name']) ?? 'Unknown';
      final categoryId = item['category_id']?.toString() ?? '';

      series.add(
        MediaItem(
          id: 'xtream-series-$seriesId',
          providerId: _id,
          providerType: MediaSourceType.xtream,
          mediaType: MediaType.series,
          title: name,
          poster: (_asString(item['cover']) ?? '').isNotEmpty
              ? _asString(item['cover'])
              : null,
          backdrop: (_asString(item['backdrop_path']) ?? '').isNotEmpty
              ? _asString(item['backdrop_path'])
              : null,
          genres: categoryId.isNotEmpty ? [categoryId] : [],
          rating: _parseRating(item['rating']),
          description: _asString(item['plot']),
          metadata: _seriesMetadata(item, seriesId, categoryId),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
    }

    return series;
  }

  Map<String, dynamic> _seriesMetadata(
    Map item,
    String seriesId,
    String categoryId,
  ) {
    final seasons = _parseSeasons(item['seasons']);
    return {
      'seriesId': seriesId,
      'categoryId': categoryId,
      'genre': _asString(item['genre']) ?? '',
      'plot': _asString(item['plot']) ?? '',
      'year': _asString(item['year']) ?? '',
      'rating': _asString(item['rating']) ?? '',
      'added': _asString(item['added']) ?? '',
      'backdropPath': _asString(item['backdrop_path']) ?? '',
      'seasonCount': seasons,
      'isSeries': true,
    };
  }

  int _parseSeasons(dynamic raw) {
    if (raw is List) return raw.length;
    if (raw is Map) return raw.length;
    if (raw is String && raw.isNotEmpty) {
      return int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return 0;
  }

  /// Extracts a string from a JSON value. Some panels emit empty lists (or
  /// other non-string values) for optional string fields such as
  /// `backdrop_path`, so a plain `as String?` cast would abort the whole sync.
  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List) {
      if (value.isEmpty) return null;
      final first = value.first;
      return first is String ? first : first?.toString();
    }
    if (value is Map) return null;
    return value.toString();
  }

  Future<List<MediaItem>> _fetchLiveCategories(DateTime createdAt) async {
    return _fetchCategories('action=get_live_categories', 'xtream-cat', createdAt);
  }

  Future<List<MediaItem>> _fetchMovieCategories(DateTime createdAt) async {
    return _fetchCategories(
      'action=get_vod_categories',
      'xtream-vod-cat',
      createdAt,
    );
  }

  Future<List<MediaItem>> _fetchSeriesCategories(DateTime createdAt) async {
    return _fetchCategories(
      'action=get_series_categories',
      'xtream-series-cat',
      createdAt,
    );
  }

  Future<List<MediaItem>> _fetchCategories(
    String action,
    String prefix,
    DateTime createdAt,
  ) async {
    final data = _extractData(await _fetchJson(action));
    if (data == null) return [];

    final categories = <MediaItem>[];
    for (final item in data) {
      if (item is! Map) continue;
      final categoryId = item['category_id']?.toString() ?? '';
      final categoryName = _asString(item['category_name']) ?? '';
      if (categoryId.isEmpty || categoryName.isEmpty) continue;

      categories.add(
        MediaItem(
          id: '$prefix-$categoryId',
          providerId: _id,
          providerType: MediaSourceType.xtream,
          mediaType: MediaType.collection,
          title: categoryName,
          metadata: {
            'categoryId': categoryId,
            'parentId': item['parent_id'],
          },
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
    }

    return categories;
  }

  Future<dynamic> _fetchJson(String action) async {
    final uri = Uri.parse(
      '$_serverUrl/player_api.php?username=$_username&password=$_password&$action',
    );

    final jsonStr = await _getJson(uri);
    if (jsonStr == null) return null;

    try {
      return json.decode(jsonStr);
    } catch (e) {
      _logger.warning(
        'Xtream API returned malformed JSON for $action',
        tag: 'XtreamMediaSource',
        error: e,
      );
      return null;
    }
  }

  /// Extracts the item list from a panel payload.
  ///
  /// Standard panels wrap lists in `{"data": [...]}` while some panels (and
  /// several real-world deployments) return a bare top-level array for every
  /// list endpoint. Both shapes are handled here.
  static List<dynamic>? _extractData(dynamic payload) {
    if (payload is List) return payload;
    if (payload is Map && payload['data'] is List) {
      return payload['data'] as List;
    }
    return null;
  }

  Future<String?> _getJson(Uri uri) async {
    final request = await _client.getUrl(uri).timeout(_kRequestTimeout);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'StreamHubPro/1.0');

    final response = await request.close().timeout(_kRequestTimeout);
    if (response.statusCode != 200) {
      _logger.warning(
        'Xtream API returned ${response.statusCode} for $uri',
        tag: 'XtreamMediaSource',
      );
      return null;
    }

    final bytes = await response.fold<List<int>>(
      [],
      (prev, chunk) => prev..addAll(chunk),
    );
    return utf8.decode(bytes);
  }

  /// Fetches the panel `user_info` and parses subscription account metadata.
  /// Returns `null` when the request fails or the payload is unexpected.
  Future<AccountMetadata?> _fetchAccountMetadata() async {
    try {
      final payload = await _fetchJson('');
      if (payload is! Map) return null;
      final userInfo = payload['user_info'];
      if (userInfo is! Map) return null;
      return AccountMetadata.fromUserInfo(userInfo);
    } catch (e) {
      _logger.warning(
        'Failed to fetch account metadata',
        tag: 'XtreamMediaSource',
        error: e,
      );
      return null;
    }
  }

  @override
  Future<bool> validate() async {
    try {
      final payload = await _fetchJson('');
      if (payload is! Map) return false;
      final userInfo = payload['user_info'] as Map?;
      return userInfo != null && userInfo['auth'] == 1;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<MediaHealth> health() async {
    try {
      final uri = Uri.parse(
        '$_serverUrl/player_api.php?username=$_username&password=$_password',
      );
      final stopwatch = Stopwatch()..start();
      final request = await _client.getUrl(uri).timeout(_kRequestTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(_kRequestTimeout);
      stopwatch.stop();

      final isConnected = response.statusCode == 200;
      return MediaHealth(
        isConnected: isConnected,
        latencyMs: stopwatch.elapsedMilliseconds,
        isAuthenticated: isConnected,
        lastSync: _lastSync,
        errors: isConnected ? [] : ['HTTP ${response.statusCode}'],
      );
    } catch (e) {
      return MediaHealth(
        isConnected: false,
        errors: [e.toString()],
      );
    }
  }

  @override
  Future<MediaStatistics> statistics() async {
    final channels = _cachedChannels.length;
    final movies = _cachedMovies.length;
    final series = _cachedSeries.length;
    final categories = _cachedCategories.length;
    return MediaStatistics(
      totalItems: channels + movies + series + categories,
      channels: channels,
      movies: movies,
      series: series,
      categories: categories,
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
  Future<List<MediaItem>> getCategories() async {
    final live = _cachedCategories;
    final movies = await _fetchMovieCategories(DateTime.now());
    final series = await _fetchSeriesCategories(DateTime.now());
    return [...live, ...movies, ...series];
  }

  @override
  Future<List<MediaItem>> getChannels() async => _cachedChannels;

  @override
  Future<List<MediaItem>> getMovies() async => _cachedMovies;

  @override
  Future<List<MediaItem>> getSeries() async => _cachedSeries;

  @override
  Future<List<MediaItem>> getPrograms() async => [];

  String _liveStreamUrl(String streamId, String ext) {
    return '$_serverUrl/live/$_username/$_password/$streamId.$ext';
  }

  String _movieStreamUrl(String streamId, String ext) {
    return '$_serverUrl/movie/$_username/$_password/$streamId.$ext';
  }

  String _seriesStreamUrl(String episodeId, String ext) {
    return '$_serverUrl/series/$_username/$_password/$episodeId.$ext';
  }

  /// Builds an authenticated stream URL for a series episode, used by the
  /// Xtream stream resolver when a series is played.
  String buildSeriesEpisodeUrl(String episodeId, String ext) {
    return _seriesStreamUrl(episodeId, ext);
  }

  static String _extension(String? raw) {
    final ext = (raw ?? '').trim().toLowerCase().replaceFirst('.', '');
    if (ext.isEmpty) return 'mkv';
    return ext;
  }

  /// Resolves the container extension for a live channel.
  ///
  /// Panels frequently omit `container_extension` on live streams. IPTV live
  /// content is served as MPEG-TS by convention, so fall back to `ts` (matching
  /// the account's output format) rather than the VOD default (`mkv`). Using
  /// `mkv` here produces a bogus extension that misclassifies the stream and
  /// breaks live playback.
  static String _liveStreamExtension(String? raw) {
    final ext = (raw ?? '').trim().toLowerCase().replaceFirst('.', '');
    if (ext.isEmpty) return 'ts';
    return ext;
  }

  double? _parseRating(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final rating = double.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (rating != null && rating > 0 && rating <= 10) return rating;
    }
    return null;
  }
}
