// core/streaming/vod/xtream_vod_info_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/security/sensitive_data_redactor.dart';
import 'package:stream_hub/core/utils/image_url_formatter.dart';
import 'package:stream_hub/data/models/media_item.dart';

/// The parsed `get_vod_info` payload for a VOD movie.
class XtreamVodInfo {
  final String vodId;
  final String name;
  final String? poster;
  final String? backdrop;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final double? rating;
  final String? duration;
  final int? durationSeconds;
  final String? containerExtension;
  final Map<String, dynamic> rawInfo;

  const XtreamVodInfo({
    required this.vodId,
    required this.name,
    this.poster,
    this.backdrop,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.rating,
    this.duration,
    this.durationSeconds,
    this.containerExtension,
    this.rawInfo = const {},
  });
}

/// Fetches and parses Xtream Codes `get_vod_info` payloads.
///
/// Many Xtream IPTV panels omit full artwork from `get_vod_streams` to save
/// bandwidth, providing `cover_big`, `movie_image`, and `backdrop_path` only
/// through the `get_vod_info` endpoint. If the provider still does not supply artwork,
/// it gracefully enriches via public movie metadata search.
class XtreamVodInfoService {
  static const Duration _kRequestTimeout = Duration(seconds: 15);

  final LoggingService _logger;
  final HttpClient _client;
  final Map<String, XtreamVodInfo> _cache = {};
  final Map<String, Future<XtreamVodInfo?>> _inFlight = {};

  XtreamVodInfoService({LoggingService? logger, HttpClient? client})
      : _logger = logger ?? LoggingService(),
        _client = client ?? createDohAwareHttpClient();

  /// Synchronously checks if a poster is already cached in memory for [item].
  String? getCachedPoster(MediaItem item) {
    final streamId = _extractStreamId(item);
    if (streamId.isEmpty) return null;

    final baseUrl = _extractBaseUrl(item);
    if (baseUrl == null || baseUrl.isEmpty) return null;

    final cleanBaseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cacheKey = '$cleanBaseUrl:$streamId';
    final cached = _cache[cacheKey];
    if (cached != null) {
      final poster = (cached.poster != null && cached.poster!.trim().isNotEmpty) ? cached.poster!.trim() : null;
      final backdrop = (cached.backdrop != null && cached.backdrop!.trim().isNotEmpty) ? cached.backdrop!.trim() : null;
      return poster ?? backdrop;
    }
    return null;
  }

  /// Synchronously checks if a backdrop (or poster) is already cached in memory for [item].
  String? getCachedBackdrop(MediaItem item) {
    final streamId = _extractStreamId(item);
    if (streamId.isEmpty) return null;

    final baseUrl = _extractBaseUrl(item);
    if (baseUrl == null || baseUrl.isEmpty) return null;

    final cleanBaseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cacheKey = '$cleanBaseUrl:$streamId';
    final cached = _cache[cacheKey];
    if (cached != null) {
      final backdrop = (cached.backdrop != null && cached.backdrop!.trim().isNotEmpty) ? cached.backdrop!.trim() : null;
      final poster = (cached.poster != null && cached.poster!.trim().isNotEmpty) ? cached.poster!.trim() : null;
      return backdrop ?? poster;
    }
    return null;
  }

  /// Cleans provider tags from a movie title for metadata search.
  static String cleanMovieTitle(String title) {
    var cleaned = title;
    // Strip language / country prefixes like "|DE| ", "[EN] ", "DE - ", "(FR) "
    cleaned = cleaned.replaceAll(RegExp(r'^[|\[(][A-Za-z0-9_\-\s]{2,6}[|\])]\s*[:\-]?\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'^(?:DE|EN|FR|ES|IT|PL|TR|AR|RU|CN|JP|KR)\s*[:\-]\s*', caseSensitive: false), '');
    // Strip quality / codec / source tags
    cleaned = cleaned.replaceAll(RegExp(r'\b(?:4K|UHD|FHD|HD|1080p|720p|480p|HEVC|H\.?265|H\.?264|AAC|HDR|BluRay|WEB-DL|DVDRip)\b', caseSensitive: false), '');
    // Strip year brackets if enclosed like (2022) or [2023]
    cleaned = cleaned.replaceAll(RegExp(r'\s*\(\d{4}\)\s*'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s*\[\d{4}\]\s*'), ' ');
    // Strip trailing punctuation / spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isEmpty ? title : cleaned;
  }

  /// Fetches and parses movie metadata for [vodId] from the Xtream panel.
  Future<XtreamVodInfo> fetch({
    required String baseUrl,
    required String username,
    required String password,
    required String vodId,
  }) async {
    final cleanBaseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cacheKey = '$cleanBaseUrl:$vodId';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final queryParameters = <String, String>{
      'username': username,
      'password': password,
      'action': 'get_vod_info',
      'vod_id': vodId,
    };

    final uri = Uri.parse('$cleanBaseUrl/player_api.php').replace(
      queryParameters: queryParameters,
    );

    _logger.debug(
      'Fetching VOD info for $vodId: ${SensitiveDataRedactor.redactUrl(uri.toString())}',
      tag: 'XtreamVodInfoService',
    );

    final String body;
    try {
      final request = await _client.getUrl(uri).timeout(_kRequestTimeout);
      final response = await request.close().timeout(_kRequestTimeout);

      if (response.statusCode == 404) {
        throw StreamResolutionException(
          message: 'Xtream panel returned 404 for VOD info $vodId.',
        );
      }

      if (response.statusCode != 200) {
        throw StreamNetworkException(
          message: 'Xtream panel answered HTTP ${response.statusCode} for VOD info $vodId.',
        );
      }

      body = await response.transform(utf8.decoder).join();
    } on SocketException catch (e) {
      _logger.warning('Xtream VOD info socket failure for $vodId', tag: 'XtreamVodInfoService', error: e);
      throw StreamNetworkException(message: 'Connection failed while fetching VOD info for $vodId: $e');
    } on TimeoutException {
      _logger.warning('Xtream VOD info request timed out for $vodId', tag: 'XtreamVodInfoService');
      throw const StreamTimeoutException(message: 'Xtream VOD info request timed out.');
    } catch (e) {
      if (e is StreamEngineException) rethrow;
      _logger.error('Unexpected error fetching VOD info for $vodId', tag: 'XtreamVodInfoService', error: e);
      throw StreamResolutionException(message: 'Failed to fetch VOD info for $vodId: $e');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (e) {
      _logger.warning('Xtream get_vod_info returned malformed JSON for $vodId', tag: 'XtreamVodInfoService', error: e);
      throw StreamResolutionException(message: 'Xtream get_vod_info returned malformed JSON for $vodId: $e');
    }

    if (decoded is! Map) {
      throw StreamResolutionException(message: 'Xtream get_vod_info returned invalid payload for $vodId');
    }

    final infoMap = (decoded['info'] is Map)
        ? (decoded['info'] as Map)
        : ((decoded['data'] is Map && (decoded['data'] as Map)['info'] is Map)
            ? ((decoded['data'] as Map)['info'] as Map)
            : decoded);

    final movieDataMap = (decoded['movie_data'] is Map)
        ? (decoded['movie_data'] as Map)
        : ((decoded['data'] is Map && (decoded['data'] as Map)['movie_data'] is Map)
            ? ((decoded['data'] as Map)['movie_data'] as Map)
            : const {});

    final name = _stringValue(infoMap['name']) ?? _stringValue(movieDataMap['name']) ?? 'Movie';
    var poster = ImageUrlFormatter.extractFromMap(infoMap, serverUrl: cleanBaseUrl) ??
        ImageUrlFormatter.extractFromMap(movieDataMap, serverUrl: cleanBaseUrl);
    var backdrop = ImageUrlFormatter.format(infoMap['backdrop_path'], serverUrl: cleanBaseUrl) ??
        ImageUrlFormatter.format(infoMap['backdrop'], serverUrl: cleanBaseUrl);
    var plot = _stringValue(infoMap['plot']) ?? _stringValue(infoMap['description']);
    var genre = _stringValue(infoMap['genre']);
    var releaseDate = _stringValue(infoMap['releasedate']) ?? _stringValue(infoMap['release_date']);
    var rating = double.tryParse(_stringValue(infoMap['rating']) ?? '');

    // Fallback: If provider returns empty artwork in get_vod_info, resolve from open movie metadata
    if (poster == null && backdrop == null && name.isNotEmpty) {
      final enriched = await _fallbackSearchOpenMetadata(
        vodId: vodId,
        rawName: name,
        containerExtension: _stringValue(movieDataMap['container_extension']) ?? _stringValue(infoMap['container_extension']),
        rawInfo: infoMap.cast<String, dynamic>(),
      );
      if (enriched != null) {
        _cache[cacheKey] = enriched;
        return enriched;
      }
    }

    final parsed = XtreamVodInfo(
      vodId: vodId,
      name: name,
      poster: poster,
      backdrop: backdrop,
      plot: plot,
      cast: _stringValue(infoMap['cast']) ?? _stringValue(infoMap['actors']),
      director: _stringValue(infoMap['director']),
      genre: genre,
      releaseDate: releaseDate,
      rating: rating,
      duration: _stringValue(infoMap['duration']),
      durationSeconds: int.tryParse(_stringValue(infoMap['duration_secs']) ?? ''),
      containerExtension: _stringValue(movieDataMap['container_extension']) ?? _stringValue(infoMap['container_extension']),
      rawInfo: infoMap.cast<String, dynamic>(),
    );

    _logger.info(
      'VOD info parsed for $vodId ($name): poster=$poster, backdrop=$backdrop',
      tag: 'XtreamVodInfoService',
    );

    _cache[cacheKey] = parsed;
    return parsed;
  }

  Future<XtreamVodInfo?> _fallbackSearchOpenMetadata({
    required String vodId,
    required String rawName,
    required String? containerExtension,
    required Map<String, dynamic> rawInfo,
  }) async {
    final cleaned = cleanMovieTitle(rawName);
    if (cleaned.isEmpty) return null;

    try {
      final uri = Uri.parse('https://v3-cinemeta.strem.io/catalog/movie/top/search=${Uri.encodeComponent(cleaned)}.json');
      final request = await _client.getUrl(uri).timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final text = await response.transform(utf8.decoder).join();
        final dynamic json = jsonDecode(text);
        if (json is Map && json['metas'] is List && (json['metas'] as List).isNotEmpty) {
          final first = (json['metas'] as List).first;
          if (first is Map) {
            final poster = _stringValue(first['poster']);
            final backdrop = _stringValue(first['background']);
            final plot = _stringValue(first['description']);
            final rating = double.tryParse(_stringValue(first['imdbRating']) ?? '');
            final year = _stringValue(first['year']);
            final genres = first['genres'];
            final genre = (genres is List) ? genres.join(', ') : _stringValue(first['genre']);
            final castList = first['cast'] ?? first['actors'] ?? first['stars'];
            final cast = (castList is List) ? castList.join(', ') : _stringValue(castList);
            final directorList = first['director'] ?? first['directors'];
            final director = (directorList is List) ? directorList.join(', ') : _stringValue(directorList);

            _logger.info(
              'Enriched movie artwork from metadata for "$rawName" (cleaned: "$cleaned"): poster=$poster',
              tag: 'XtreamVodInfoService',
            );

            return XtreamVodInfo(
              vodId: vodId,
              name: rawName,
              poster: poster,
              backdrop: backdrop,
              plot: plot,
              cast: cast,
              director: director,
              genre: genre,
              releaseDate: year,
              rating: rating,
              containerExtension: containerExtension,
              rawInfo: rawInfo,
            );
          }
        }
      }
    } catch (e) {
      _logger.debug('Metadata fallback lookup failed for "$cleaned": $e', tag: 'XtreamVodInfoService');
    }
    return null;
  }

  /// Convenience method to resolve VOD info for a [MediaItem].
  Future<XtreamVodInfo?> fetchForMediaItem(
    MediaItem item, {
    ProviderSession? session,
  }) async {
    final streamId = _extractStreamId(item);
    if (streamId.isEmpty) return null;

    final baseUrl = _extractBaseUrl(item, session: session);
    final username = _extractUsername(item, session: session);
    final password = _extractPassword(item, session: session);

    if (baseUrl == null || baseUrl.isEmpty || username == null || password == null) {
      return null;
    }

    final cleanBaseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cacheKey = '$cleanBaseUrl:$streamId';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    if (_inFlight.containsKey(cacheKey)) {
      return _inFlight[cacheKey];
    }

    final future = () async {
      try {
        return await fetch(
          baseUrl: cleanBaseUrl,
          username: username,
          password: password,
          vodId: streamId,
        );
      } catch (_) {
        return null;
      } finally {
        _inFlight.remove(cacheKey);
      }
    }();

    _inFlight[cacheKey] = future;
    return future;
  }

  static String _extractStreamId(MediaItem item) {
    return item.metadata['streamId']?.toString() ??
        item.metadata['stream_id']?.toString() ??
        item.metadata['vodId']?.toString() ??
        item.id.replaceFirst(RegExp(r'^xtream-(?:movie-)?'), '');
  }

  static String? _extractBaseUrl(MediaItem item, {ProviderSession? session}) {
    final explicit = session?.baseUrl ?? item.metadata['serverUrl']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final streamUrl = item.metadata['streamUrl']?.toString() ?? item.metadata['stream_url']?.toString();
    if (streamUrl != null && streamUrl.isNotEmpty) {
      final uri = Uri.tryParse(streamUrl);
      if (uri != null && uri.host.isNotEmpty) {
        return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
      }
    }
    return null;
  }

  static String? _extractUsername(MediaItem item, {ProviderSession? session}) {
    final explicit = session?.username ?? item.metadata['username']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final streamUrl = item.metadata['streamUrl']?.toString() ?? item.metadata['stream_url']?.toString();
    if (streamUrl != null && streamUrl.isNotEmpty) {
      final uri = Uri.tryParse(streamUrl);
      if (uri != null) {
        final segments = uri.pathSegments;
        final movieIdx = segments.indexOf('movie');
        if (movieIdx != -1 && segments.length >= movieIdx + 2) {
          return segments[movieIdx + 1];
        }
      }
    }
    return null;
  }

  static String? _extractPassword(MediaItem item, {ProviderSession? session}) {
    final explicit = session?.password ?? item.metadata['password']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final streamUrl = item.metadata['streamUrl']?.toString() ?? item.metadata['stream_url']?.toString();
    if (streamUrl != null && streamUrl.isNotEmpty) {
      final uri = Uri.tryParse(streamUrl);
      if (uri != null) {
        final segments = uri.pathSegments;
        final movieIdx = segments.indexOf('movie');
        if (movieIdx != -1 && segments.length >= movieIdx + 3) {
          return segments[movieIdx + 2];
        }
      }
    }
    return null;
  }

  static String? _stringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is List) {
      if (value.isEmpty) return null;
      final first = value.first;
      return first?.toString().trim();
    }
    return value.toString().trim();
  }
}
