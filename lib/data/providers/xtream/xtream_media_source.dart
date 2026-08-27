import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/account_metadata_provider.dart';
import 'package:stream_hub/core/media/enums/media_source_state.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/events/media_event_bus.dart';
import 'package:stream_hub/core/media/media_source.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';
import 'package:stream_hub/core/streaming/security/sensitive_data_redactor.dart';
import 'package:stream_hub/core/utils/image_url_formatter.dart';
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

  static const String _kLiveCategoryPrefix = 'xtream-cat-';
  static const String _kVodCategoryPrefix = 'xtream-vod-cat-';
  static const String _kSeriesCategoryPrefix = 'xtream-series-cat-';

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

  /// Whether the panel authenticated the supplied credentials.
  ///
  /// `null` until the panel answers `user_info`; `0` means the credentials were
  /// rejected (the panel reports `"Invalid credentials"`); `1` means the
  /// subscription is valid.
  int? _auth;

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
  }) : _id = id,
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
        _fetchMovieCategories(syncStartedAt),
        _fetchSeriesCategories(syncStartedAt),
        _fetchMovies(syncStartedAt),
        _fetchSeries(syncStartedAt),
      ], eagerError: false);

      final liveCategories = results[1] as List<MediaItem>;
      final movieCategories = results[2] as List<MediaItem>;
      final seriesCategories = results[3] as List<MediaItem>;

      _cachedChannels = results[0] as List<MediaItem>;
      _cachedCategories = [
        ...liveCategories,
        ...movieCategories,
        ...seriesCategories,
      ];
      _cachedMovies = results[4] as List<MediaItem>;
      _cachedSeries = results[5] as List<MediaItem>;
      _lastSync = DateTime.now();

      _cachedChannels = _resolveCategoryNames(
        _cachedChannels,
        _categoryNameMap(_cachedCategories, _kLiveCategoryPrefix),
      );
      _cachedMovies = _resolveCategoryNames(
        _cachedMovies,
        _categoryNameMap(_cachedCategories, _kVodCategoryPrefix),
      );
      _cachedSeries = _resolveCategoryNames(
        _cachedSeries,
        _categoryNameMap(_cachedCategories, _kSeriesCategoryPrefix),
      );

      final totalItems =
          _cachedChannels.length + _cachedMovies.length + _cachedSeries.length;

      if (_auth == 0) {
        _state = MediaSourceState.error;
        return MediaSyncResult(
          sourceId: _id,
          success: false,
          error:
              'The Xtream server rejected the username or password. '
              'Double-check the credentials for "$_serverUrl".',
          completedAt: DateTime.now(),
        );
      }

      if (totalItems == 0 && _accountMetadata == null) {
        _state = MediaSourceState.error;
        return MediaSyncResult(
          sourceId: _id,
          success: false,
          error:
              'The panel at "$_serverUrl" returned no content and the account '
              'could not be verified. Check the server URL and credentials.',
          completedAt: DateTime.now(),
        );
      }

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
      _logger.warning(
        'Xtream sync network error',
        tag: 'XtreamMediaSource',
        error: e,
      );
      return null;
    } on TimeoutException catch (e) {
      _logger.warning(
        'Xtream sync timed out',
        tag: 'XtreamMediaSource',
        error: e,
      );
      return null;
    } catch (e, s) {
      _state = MediaSourceState.error;
      _logger.error(
        'Xtream sync failed',
        tag: 'XtreamMediaSource',
        error: e,
        stackTrace: s,
      );
      return MediaSyncResult(
        sourceId: _id,
        success: false,
        error: e.toString(),
        completedAt: DateTime.now(),
      );
    }
  }

  Future<List<MediaItem>> _fetchLiveChannels(DateTime createdAt) async {
    var rawJson = await _getJsonAction('action=live');
    var channels = <MediaItem>[];
    if (rawJson != null && rawJson.isNotEmpty) {
      channels = await compute(
        _parseLiveChannelsIsolated,
        _XtreamParseParams(
          rawJson: rawJson,
          serverUrl: _serverUrl,
          providerId: _id,
          username: _username,
          password: _password,
          createdAt: createdAt,
        ),
      );
    }
    if (channels.isEmpty) {
      final fallbackJson = await _getJsonAction('action=get_live_streams');
      if (fallbackJson != null && fallbackJson.isNotEmpty) {
        channels = await compute(
          _parseLiveChannelsIsolated,
          _XtreamParseParams(
            rawJson: fallbackJson,
            serverUrl: _serverUrl,
            providerId: _id,
            username: _username,
            password: _password,
            createdAt: createdAt,
          ),
        );
      }
    }
    return channels;
  }

  Future<List<MediaItem>> _fetchMovies(DateTime createdAt) async {
    final rawJson = await _getJsonAction('action=get_vod_streams');
    if (rawJson == null || rawJson.isEmpty) return [];

    return await compute(
      _parseMoviesIsolated,
      _XtreamParseParams(
        rawJson: rawJson,
        serverUrl: _serverUrl,
        providerId: _id,
        username: _username,
        password: _password,
        createdAt: createdAt,
      ),
    );
  }

  Future<List<MediaItem>> _fetchSeries(DateTime createdAt) async {
    final rawJson = await _getJsonAction('action=get_series');
    if (rawJson == null || rawJson.isEmpty) return [];

    return await compute(
      _parseSeriesIsolated,
      _XtreamParseParams(
        rawJson: rawJson,
        serverUrl: _serverUrl,
        providerId: _id,
        username: _username,
        password: _password,
        createdAt: createdAt,
      ),
    );
  }

  Future<List<MediaItem>> _fetchLiveCategories(DateTime createdAt) async {
    return _fetchCategories(
      'action=get_live_categories',
      _kLiveCategoryPrefix,
      createdAt,
    );
  }

  Future<List<MediaItem>> _fetchMovieCategories(DateTime createdAt) async {
    return _fetchCategories(
      'action=get_vod_categories',
      _kVodCategoryPrefix,
      createdAt,
    );
  }

  Future<List<MediaItem>> _fetchSeriesCategories(DateTime createdAt) async {
    return _fetchCategories(
      'action=get_series_categories',
      _kSeriesCategoryPrefix,
      createdAt,
    );
  }

  Future<List<MediaItem>> _fetchCategories(
    String action,
    String prefix,
    DateTime createdAt,
  ) async {
    final rawJson = await _getJsonAction(action);
    if (rawJson == null || rawJson.isEmpty) return [];

    return await compute(
      _parseCategoriesIsolated,
      _XtreamCategoryParams(
        rawJson: rawJson,
        providerId: _id,
        prefix: prefix,
        createdAt: createdAt,
      ),
    );
  }

  /// Builds a `category_id -> category_name` lookup for one category type.
  ///
  /// Category IDs are only unique within a type (live / VOD / series), so the
  /// categories are filtered by their `xtream-...-` prefix before indexing.
  Map<String, String> _categoryNameMap(
    List<MediaItem> categories,
    String prefix,
  ) {
    return {
      for (final category in categories)
        if (category.id.startsWith(prefix) &&
            category.metadata['categoryId'] is String)
          category.metadata['categoryId'] as String: category.title,
    };
  }

  /// Replaces raw `category_id` values in a channel's genres with their display
  /// names, falling back to the raw value when no category name is known.
  ///
  /// The raw category id remains available in `metadata['categoryId']`.
  List<MediaItem> _resolveCategoryNames(
    List<MediaItem> items,
    Map<String, String> nameById,
  ) {
    if (nameById.isEmpty) return items;
    return [
      for (final item in items)
        if (item.genres.isEmpty)
          item
        else
          item.copyWith(
            genres: [for (final genre in item.genres) nameById[genre] ?? genre],
          ),
    ];
  }

  Future<dynamic> _fetchJson(String action) async {
    final jsonStr = await _getJsonAction(action);
    if (jsonStr == null || jsonStr.isEmpty) return null;

    try {
      if (jsonStr.length > 50000) {
        return await compute(_decodeJsonIsolated, jsonStr);
      }
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

  Future<String?> _getJsonAction(String action) async {
    final uri = Uri.parse('$_serverUrl/player_api.php').replace(
      queryParameters: {
        'username': _username,
        'password': _password,
        ...Uri.parse('?$action').queryParameters,
      },
    );
    return _getJson(uri);
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
        'Xtream API returned ${response.statusCode} for '
        '${SensitiveDataRedactor.redactUrl(uri.toString())}',
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
  ///
  /// Returns the parsed metadata whenever the panel answers `user_info`
  /// (regardless of whether the credentials were accepted) and `null` when the
  /// request fails or the payload is unexpected. Rejected credentials are
  /// recorded in [auth] so sync can report them to the user.
  Future<AccountMetadata?> _fetchAccountMetadata() async {
    _auth = null;
    try {
      final payload = await _fetchJson('');
      if (payload is! Map) return null;
      final userInfo = payload['user_info'];
      if (userInfo is! Map) return null;

      _auth = _parseAuth(userInfo);
      if (_auth == 0) {
        _logger.warning(
          'Xtream panel rejected credentials for $_serverUrl',
          tag: 'XtreamMediaSource',
        );
      }
      return AccountMetadata.fromUserInfo(userInfo);
    } catch (e) {
      _logger.warning(
        'Failed to fetch account metadata from '
        '${SensitiveDataRedactor.redactUrl('$_serverUrl/player_api.php')}: $e',
        tag: 'XtreamMediaSource',
        error: e,
      );
      return null;
    }
  }

  /// Reads the `auth` flag from a panel `user_info` map (`1` = valid,
  /// `0` = rejected credentials, anything else = unknown).
  static int? _parseAuth(Map<dynamic, dynamic> userInfo) {
    final raw = userInfo['auth'];
    if (raw is int) return raw;
    if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      if (parsed != null) return parsed;
    }
    return null;
  }

  @override
  Future<bool> validate() async {
    try {
      final payload = await _fetchJson('');
      if (payload is! Map) return false;
      final userInfo = payload['user_info'] as Map?;
      _auth = userInfo == null ? null : _parseAuth(userInfo);
      return userInfo != null && _auth == 1;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<MediaHealth> health() async {
    try {
      final uri = Uri.parse('$_serverUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
        },
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
      return MediaHealth(isConnected: false, errors: [e.toString()]);
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
    if (_cachedCategories.isNotEmpty) return _cachedCategories;
    final live = await _fetchLiveCategories(DateTime.now());
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

  static dynamic _decodeJsonIsolated(String raw) => json.decode(raw);
}

class _XtreamParseParams {
  final String rawJson;
  final String serverUrl;
  final String providerId;
  final String username;
  final String password;
  final DateTime createdAt;

  const _XtreamParseParams({
    required this.rawJson,
    required this.serverUrl,
    required this.providerId,
    required this.username,
    required this.password,
    required this.createdAt,
  });
}

class _XtreamCategoryParams {
  final String rawJson;
  final String providerId;
  final String prefix;
  final DateTime createdAt;

  const _XtreamCategoryParams({
    required this.rawJson,
    required this.providerId,
    required this.prefix,
    required this.createdAt,
  });
}

List<MediaItem> _parseLiveChannelsIsolated(_XtreamParseParams params) {
  final dynamic payload;
  try {
    payload = json.decode(params.rawJson);
  } catch (_) {
    return [];
  }
  final data = XtreamMediaSource._extractData(payload);
  if (data == null) return [];

  final channels = <MediaItem>[];
  for (final item in data) {
    if (item is! Map) continue;
    final streamId = item['stream_id']?.toString();
    if (streamId == null || streamId.isEmpty) continue;

    final ext = XtreamMediaSource._liveStreamExtension(item['container_extension']?.toString());
    final name = _asStringIsolated(item['name']) ?? 'Unknown';
    final categoryId = item['category_id']?.toString() ?? '';

    final streamUrl = '${params.serverUrl}/live/${params.username}/${params.password}/$streamId.$ext';
    final poster = ImageUrlFormatter.extractFromMap(item, serverUrl: params.serverUrl);

    channels.add(
      MediaItem(
        id: 'xtream-live-$streamId',
        providerId: params.providerId,
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.channel,
        title: name,
        subtitle: _asStringIsolated(item['epg_channel_id']),
        poster: poster,
        thumbnail: poster,
        genres: categoryId.isNotEmpty ? [categoryId] : [],
        metadata: {
          'streamUrl': streamUrl,
          'streamId': streamId,
          'categoryId': categoryId,
          'epgChannelId': _asStringIsolated(item['epg_channel_id']) ?? '',
          'streamIcon': poster ?? _asStringIsolated(item['stream_icon']) ?? '',
          'tvArchive': item['tv_archive'],
          'tvArchiveDuration': item['tv_archive_duration'],
          'resolution': _asStringIsolated(item['stream_type']) ?? '',
          'serverUrl': params.serverUrl,
          'isLive': true,
        },
        createdAt: params.createdAt,
        updatedAt: params.createdAt,
      ),
    );
  }

  return channels;
}

List<MediaItem> _parseMoviesIsolated(_XtreamParseParams params) {
  final dynamic payload;
  try {
    payload = json.decode(params.rawJson);
  } catch (_) {
    return [];
  }
  final data = XtreamMediaSource._extractData(payload);
  if (data == null) return [];

  final movies = <MediaItem>[];
  for (final item in data) {
    if (item is! Map) continue;
    final streamId = item['stream_id']?.toString();
    if (streamId == null || streamId.isEmpty) continue;

    final ext = XtreamMediaSource._extension(item['container_extension']?.toString());
    final name = _asStringIsolated(item['name']) ?? 'Unknown';
    final categoryId = item['category_id']?.toString() ?? '';

    final streamUrl = '${params.serverUrl}/movie/${params.username}/${params.password}/$streamId.$ext';
    final poster = ImageUrlFormatter.extractFromMap(item, serverUrl: params.serverUrl);
    final backdrop = ImageUrlFormatter.format(item['backdrop_path'], serverUrl: params.serverUrl);
    final rawGenre = _asStringIsolated(item['genre']) ?? '';

    final genres = <String>[];
    if (categoryId.isNotEmpty) {
      genres.add(categoryId);
    }
    if (rawGenre.isNotEmpty) {
      for (final g in rawGenre.split(RegExp(r'[,/|]'))) {
        final clean = g.trim();
        if (clean.isNotEmpty && !genres.contains(clean)) {
          genres.add(clean);
        }
      }
    }

    movies.add(
      MediaItem(
        id: 'xtream-movie-$streamId',
        providerId: params.providerId,
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.movie,
        title: name,
        poster: poster,
        thumbnail: poster,
        backdrop: backdrop,
        genres: genres,
        rating: _parseRatingIsolated(item['rating']),
        description: _asStringIsolated(item['plot']),
        metadata: {
          'streamUrl': streamUrl,
          'streamId': streamId,
          'categoryId': categoryId,
          'containerExtension': _asStringIsolated(item['container_extension']) ?? '',
          'genre': _asStringIsolated(item['genre']) ?? '',
          'plot': _asStringIsolated(item['plot']) ?? '',
          'year': _asStringIsolated(item['year']) ?? '',
          'duration': _asStringIsolated(item['duration']) ?? '',
          'rating': _asStringIsolated(item['rating']) ?? '',
          'added': _asStringIsolated(item['added']) ?? '',
          'directSource': _asStringIsolated(item['direct_source']) ?? '',
          'backdropPath': _asStringIsolated(item['backdrop_path']) ?? '',
          'streamIcon': poster ?? _asStringIsolated(item['stream_icon']) ?? '',
          'movieImage': _asStringIsolated(item['movie_image']) ?? '',
          'cover': _asStringIsolated(item['cover']) ?? _asStringIsolated(item['cover_big']) ?? '',
          'serverUrl': params.serverUrl,
          'isVod': true,
        },
        createdAt: params.createdAt,
        updatedAt: params.createdAt,
      ),
    );
  }

  return movies;
}

List<MediaItem> _parseSeriesIsolated(_XtreamParseParams params) {
  final dynamic payload;
  try {
    payload = json.decode(params.rawJson);
  } catch (_) {
    return [];
  }
  final data = XtreamMediaSource._extractData(payload);
  if (data == null) return [];

  final series = <MediaItem>[];
  for (final item in data) {
    if (item is! Map) continue;
    final seriesId = item['series_id']?.toString();
    if (seriesId == null || seriesId.isEmpty) continue;

    final name = _asStringIsolated(item['name']) ?? 'Unknown';
    final categoryId = item['category_id']?.toString() ?? '';
    final poster = ImageUrlFormatter.extractFromMap(item, serverUrl: params.serverUrl);
    final backdrop = ImageUrlFormatter.format(item['backdrop_path'], serverUrl: params.serverUrl);
    final rawGenre = _asStringIsolated(item['genre']) ?? '';

    final genres = <String>[];
    if (categoryId.isNotEmpty) {
      genres.add(categoryId);
    }
    if (rawGenre.isNotEmpty) {
      for (final g in rawGenre.split(RegExp(r'[,/|]'))) {
        final clean = g.trim();
        if (clean.isNotEmpty && !genres.contains(clean)) {
          genres.add(clean);
        }
      }
    }

    final seasons = _parseSeasonsIsolated(item['seasons']);

    series.add(
      MediaItem(
        id: 'xtream-series-$seriesId',
        providerId: params.providerId,
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.series,
        title: name,
        poster: poster,
        thumbnail: poster,
        backdrop: backdrop,
        genres: genres,
        rating: _parseRatingIsolated(item['rating']),
        description: _asStringIsolated(item['plot']),
        metadata: {
          'seriesId': seriesId,
          'streamId': item['stream_id']?.toString() ?? '',
          'categoryId': categoryId,
          'genre': _asStringIsolated(item['genre']) ?? '',
          'plot': _asStringIsolated(item['plot']) ?? '',
          'year': _asStringIsolated(item['year']) ?? '',
          'rating': _asStringIsolated(item['rating']) ?? '',
          'added': _asStringIsolated(item['added']) ?? '',
          'backdropPath': _asStringIsolated(item['backdrop_path']) ?? '',
          'cover': poster ?? _asStringIsolated(item['cover']) ?? _asStringIsolated(item['cover_big']) ?? '',
          'streamIcon': _asStringIsolated(item['stream_icon']) ?? '',
          'serverUrl': params.serverUrl,
          'seasonCount': seasons,
          'isSeries': true,
        },
        createdAt: params.createdAt,
        updatedAt: params.createdAt,
      ),
    );
  }

  return series;
}

List<MediaItem> _parseCategoriesIsolated(_XtreamCategoryParams params) {
  final dynamic payload;
  try {
    payload = json.decode(params.rawJson);
  } catch (_) {
    return [];
  }
  final data = XtreamMediaSource._extractData(payload);
  if (data == null) return [];

  final categories = <MediaItem>[];
  for (final item in data) {
    if (item is! Map) continue;
    final categoryId = item['category_id']?.toString() ?? '';
    final categoryName = _asStringIsolated(item['category_name']) ?? '';
    if (categoryId.isEmpty || categoryName.isEmpty) continue;

    categories.add(
      MediaItem(
        id: '${params.prefix}$categoryId',
        providerId: params.providerId,
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.collection,
        title: categoryName,
        metadata: {'categoryId': categoryId, 'parentId': item['parent_id']},
        createdAt: params.createdAt,
        updatedAt: params.createdAt,
      ),
    );
  }

  return categories;
}

String? _asStringIsolated(dynamic value) {
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

double? _parseRatingIsolated(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    final rating = double.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (rating != null && rating > 0 && rating <= 10) return rating;
  }
  return null;
}

int _parseSeasonsIsolated(dynamic raw) {
  if (raw is List) return raw.length;
  if (raw is Map) return raw.length;
  if (raw is String && raw.isNotEmpty) {
    return int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }
  return 0;
}
