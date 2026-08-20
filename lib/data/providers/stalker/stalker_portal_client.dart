import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';

/// Content types supported by the Stalker portal API.
enum StalkerContentType { live, vod, series }

/// Stalker API `type` value used for each content type.
///
/// The portal uses `itv` (not `live`) for the live TV channel list.
extension StalkerContentTypeMapping on StalkerContentType {
  String get apiType {
    switch (this) {
      case StalkerContentType.live:
        return 'itv';
      case StalkerContentType.vod:
        return 'vod';
      case StalkerContentType.series:
        return 'series';
    }
  }
}

/// Result of the Stalker portal handshake.
class StalkerHandshakeResult {
  final String token;
  final String? serial;
  final Map<String, dynamic> raw;

  const StalkerHandshakeResult({
    required this.token,
    this.serial,
    this.raw = const {},
  });
}

/// Raised when the portal responds with an HTTP error or an unexpected
/// payload. Network failures ([SocketException], [TimeoutException]) are NOT
/// wrapped so callers can retry them.
///
/// [statusCode] is set when the portal answered with a non-200 HTTP status.
/// Callers can use it to detect transient conditions such as rate limiting
/// (HTTP 429).
class StalkerPortalException implements Exception {
  final String message;
  final String? action;
  final int? statusCode;
  final bool isEmptyResponse;
  final Object? originalError;

  const StalkerPortalException(
    this.message, {
    this.action,
    this.statusCode,
    this.isEmptyResponse = false,
    this.originalError,
  });

  @override
  String toString() =>
      'StalkerPortalException: $message (action: ${action ?? 'unknown'})';
}

/// Low-level client for the Stalker Portal (MAG/STB middleware) HTTP API.
///
/// Implements the standard portal protocol:
///
/// * `handshake` — exchanges a MAC address (plus device details) for a
///   short-lived portal token.
/// * `get_profile` — returns the authenticated subscriber profile.
/// * `get_categories` / `get_ordered_list` — live TV categories and channels.
/// * `get_vod_categories` / `get_vod_list` — VOD categories and movies.
/// * `get_series_categories` / `get_series_list` — series categories and shows.
/// * `create_link` — turns a stored `cmd` into a playable stream URL.
///
/// The portal script path is auto-detected: most deployments expose it at
/// `/server/load.php` or `/stalker_portal/server/load.php`, some at
/// `/portal.php`. The first path that answers with valid JSON wins and is
/// reused for the rest of the session.
///
/// Requests are issued with GET (the standard portal transport). The portal
/// also requires a `Cookie` carrying the device MAC, and serves responses only
/// to a STB-style User-Agent. POST requests are rejected by many portal
/// deployments (Cloudflare 444 / HTML block page), so the client never POSTs.
class StalkerPortalClient {
  static const Duration _kRequestTimeout = Duration(seconds: 15);
  static const String _kUserAgent =
      'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 '
      '(KHTML, like Gecko) MAG200 stbapp ver: 4.8.0 rev: 1.0';
  static const List<String> _kScriptCandidates = [
    '/server/load.php',
    '/stalker_portal/server/load.php',
    '/portal.php',
    '/load.php',
  ];
  static const int _kMaxHttpRetries = 4;
  static const int _kMaxEmptyRetries = 3;
  static const Duration _kRetryBaseDelay = Duration(milliseconds: 1500);
  static const Duration _kMinRequestInterval = Duration(milliseconds: 1500);
  static const Set<int> _kRetryableStatusCodes = {429, 500, 502, 503, 504};

  final String _baseUrl;
  final String _macAddress;
  final String? _serial;
  final LoggingService _logger;
  final HttpClient _httpClient;
  final Duration _retryBaseDelay;

  String? _token;
  Uri? _scriptUri;
  DateTime? _lastRequestAt;
  final Map<String, String> _sessionCookies = {};

  StalkerPortalClient({
    required String baseUrl,
    required String macAddress,
    String? serial,
    String? token,
    LoggingService? logger,
    HttpClient? httpClient,
    Duration retryBaseDelay = _kRetryBaseDelay,
  }) : _baseUrl = _normalizeBaseUrl(baseUrl),
       _macAddress = _normalizeMac(macAddress),
       _serial = serial,
       _token = token,
       _logger = logger ?? LoggingService(),
       _httpClient = httpClient ?? createDohAwareHttpClient(),
       _retryBaseDelay = retryBaseDelay;

  String? get token => _token;
  String get macAddress => _macAddress;
  String get baseUrl => _baseUrl;

  Future<void> dispose() async {
    _httpClient.close(force: true);
  }

  /// Performs the STB handshake and stores the returned portal token.
  Future<StalkerHandshakeResult> handshake() async {
    final data = await _request('handshake');
    final js = _envelope(data);

    final rawToken =
        _stringAt(js, ['token', 'data.token'])?.trim() ??
        _stringAt(data, ['token', 'data.token'])?.trim() ??
        '';
    if (rawToken.isEmpty) {
      throw const StalkerPortalException(
        'Handshake did not return a portal token.',
        action: 'handshake',
      );
    }

    _token = rawToken;
    final serial = _stringAt(js, ['serial', 'data.serial']) ??
        _stringAt(data, ['serial', 'data.serial']);

    _logger.info('Stalker handshake complete for $_macAddress', tag: 'StalkerPortalClient');
    return StalkerHandshakeResult(token: rawToken, serial: serial, raw: data);
  }

  /// Returns the authenticated subscriber profile.
  ///
  /// An empty portal response (some portals throttle with an empty body) is
  /// retried, then tolerated and yields an empty profile.
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final data = await _request(
        'get_profile',
        allowEmpty: true,
        retryEmpty: true,
      );
      final js = data['js'];
      if (js is Map) {
        if (js['data'] is Map) {
          return Map<String, dynamic>.from(js['data'] as Map);
        }
        return Map<String, dynamic>.from(js);
      }
      if (data['data'] is Map) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      return data;
    } on StalkerPortalException catch (e) {
      if (e.statusCode == 429 || e.isEmptyResponse) {
        _logger.warning(
          'Stalker get_profile throttled, continuing with session: ${e.message}',
          tag: 'StalkerPortalClient',
        );
        return const {};
      }
      rethrow;
    }
  }

  /// Live TV / VOD / Series categories.
  ///
  /// For live TV (itv), Stalker/Ministra portals expose genres via `get_genres`.
  /// For VOD and Series, portals support `get_categories`, `get_vod_categories`,
  /// `get_series_categories`, or `get_genres`.
  Future<List<Map<String, dynamic>>> getCategories(
    StalkerContentType type,
  ) async {
    try {
      if (type == StalkerContentType.live) {
        final genres = await _tryGetCategoriesAction('get_genres', extra: {'type': 'itv'});
        if (genres.isNotEmpty) return genres;

        final genresStb = await _tryGetCategoriesAction('get_genres', extra: {'type': 'stb'});
        if (genresStb.isNotEmpty) return genresStb;

        final catItv = await _tryGetCategoriesAction('get_categories', extra: {'type': 'itv'});
        if (catItv.isNotEmpty) return catItv;

        final catStb = await _tryGetCategoriesAction('get_categories', extra: {'type': 'stb'});
        if (catStb.isNotEmpty) return catStb;

        return const [];
      }

      if (type == StalkerContentType.vod) {
        final catVod = await _tryGetCategoriesAction('get_categories', extra: {'type': 'vod'});
        if (catVod.isNotEmpty) return catVod;

        final vodCat = await _tryGetCategoriesAction('get_vod_categories', extra: {'type': 'vod'});
        if (vodCat.isNotEmpty) return vodCat;

        final genresVod = await _tryGetCategoriesAction('get_genres', extra: {'type': 'vod'});
        if (genresVod.isNotEmpty) return genresVod;

        return const [];
      }

      if (type == StalkerContentType.series) {
        final catSeries = await _tryGetCategoriesAction('get_categories', extra: {'type': 'series'});
        if (catSeries.isNotEmpty) return catSeries;

        final seriesCat = await _tryGetCategoriesAction('get_series_categories', extra: {'type': 'series'});
        if (seriesCat.isNotEmpty) return seriesCat;

        final genresSeries = await _tryGetCategoriesAction('get_genres', extra: {'type': 'series'});
        if (genresSeries.isNotEmpty) return genresSeries;

        return const [];
      }

      final data = await _request(
        'get_categories',
        extra: {'type': type.apiType},
        allowEmpty: true,
      );
      return _extractList(data);
    } catch (e) {
      _logger.warning(
        'Stalker getCategories (${type.name}) error: $e',
        tag: 'StalkerPortalClient',
      );
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _tryGetCategoriesAction(
    String action, {
    Map<String, dynamic>? extra,
  }) async {
    try {
      final data = await _request(action, extra: extra, allowEmpty: true);
      return _extractList(data);
    } catch (_) {
      return const [];
    }
  }

  /// Live TV channel list (`get_ordered_list?type=itv`), fetching all pages.
  Future<List<Map<String, dynamic>>> getOrderedList(
    StalkerContentType type,
  ) async {
    return _fetchPaginatedList(
      'get_ordered_list',
      extra: {'type': type.apiType},
      retryEmpty: true,
    );
  }

  /// VOD movie list, fetching all pages.
  ///
  /// Tries the dedicated `get_vod_list` action first, then falls back to
  /// `get_ordered_list?type=vod` because some portals (notably Ministra-based
  /// deployments) only serve VOD through the shared ordered-list action.
  Future<List<Map<String, dynamic>>> getVodList() async {
    final movies = await _fetchPaginatedList(
      'get_vod_list',
      extra: {'type': 'vod'},
      retryEmpty: false,
    );
    if (movies.isNotEmpty) return movies;

    return _fetchPaginatedList(
      'get_ordered_list',
      extra: {'type': 'vod'},
      retryEmpty: false,
    );
  }

  /// Series list (each show carries its own `seasons`/`episodes`), fetching all pages.
  ///
  /// Tries the dedicated `get_series_list` action first, then falls back to
  /// `get_ordered_list?type=series` for portals that only serve series
  /// through the shared ordered-list action.
  Future<List<Map<String, dynamic>>> getSeriesList() async {
    final series = await _fetchPaginatedList(
      'get_series_list',
      extra: {'type': 'series'},
      retryEmpty: false,
    );
    if (series.isNotEmpty) return series;

    return _fetchPaginatedList(
      'get_ordered_list',
      extra: {'type': 'series'},
      retryEmpty: false,
    );
  }

  /// Fetches a paginated catalog action from the Stalker portal.
  Future<List<Map<String, dynamic>>> _fetchPaginatedList(
    String action, {
    Map<String, dynamic>? extra,
    int maxItems = 10000,
    bool retryEmpty = false,
  }) async {
    final allItems = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    var page = 1;
    const maxPages = 50;

    while (allItems.length < maxItems && page <= maxPages) {
      final params = <String, dynamic>{
        ...?extra,
        'p': page,
        'page': page,
        'max_rows': 500,
      };
      final data = await _request(
        action,
        extra: params,
        allowEmpty: true,
        retryEmpty: retryEmpty && page == 1,
      );

      final batch = _extractList(data);
      if (batch.isEmpty) break;

      var addedInBatch = 0;
      for (final item in batch) {
        final id =
            item['id']?.toString() ??
            item['stream_id']?.toString() ??
            item['name']?.toString() ??
            '';
        if (id.isNotEmpty) {
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            allItems.add(item);
            addedInBatch++;
          }
        } else {
          allItems.add(item);
          addedInBatch++;
        }
      }

      final js = data['js'];
      final totalRaw = (js is Map ? js['total_items'] ?? js['total'] : null) ??
          data['total_items'] ??
          data['total'];
      final totalItems = int.tryParse(totalRaw?.toString() ?? '');
      if (totalItems != null && allItems.length >= totalItems) {
        break;
      }

      if (addedInBatch == 0 || (batch.length < 10 && page > 1)) {
        break;
      }

      if (page == 1 && totalItems == null && batch.length < 14) {
        break;
      }

      page++;
    }

    return allItems;
  }

  /// Converts a stored `cmd` into a playable stream URL.
  ///
  /// Tries standard `type=stb` router action and fallback `type=apiType`.
  /// Handles nested JSON wrappers, string responses, lists, command wrappers
  /// (ffmpeg, auto, ffrt), and relative URLs.
  Future<String> createLink({
    required StalkerContentType type,
    required String cmd,
    String? genre,
  }) async {
    final candidates = <Map<String, dynamic>>[
      {
        'type': 'stb',
        'cmd': cmd,
        if (genre != null && genre.isNotEmpty) 'genre': genre,
      },
      {
        'type': type.apiType,
        'cmd': cmd,
        if (genre != null && genre.isNotEmpty) 'genre': genre,
      },
    ];

    for (final extraParams in candidates) {
      try {
        final data = await _request(
          'create_link',
          extra: extraParams,
          allowEmpty: true,
        );

        final resolved = _extractStreamUrlFromResponse(data, _baseUrl);
        if (resolved != null && resolved.isNotEmpty) {
          return resolved;
        }
      } catch (e) {
        _logger.debug(
          'Stalker create_link attempt with type=${extraParams['type']} failed: $e',
          tag: 'StalkerPortalClient',
        );
      }
    }

    final direct = _extractStreamUrl(cmd, _baseUrl);
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    throw const StalkerPortalException(
      'Portal did not return a playable stream URL.',
      action: 'create_link',
    );
  }

  Future<Map<String, dynamic>> _request(
    String action, {
    Map<String, dynamic>? extra,
    bool allowEmpty = false,
    bool retryEmpty = false,
  }) async {
    final params = <String, dynamic>{
      'type': 'stb',
      'action': action,
      'token': _token ?? '',
      'mac': _macAddress,
      'Mac': _macAddress,
      'sn': _serial ?? _macAddress,
      'device_id': _serial ?? _macAddress,
      'stb_type': 'MAG250',
      'ver': '4.8.0',
      'JsHttpRequest': '${DateTime.now().millisecondsSinceEpoch}-xml',
      ...?extra,
    };

    if (_scriptUri != null) {
      return _getJson(
        _scriptUri!,
        params,
        allowEmpty: allowEmpty,
        retryEmpty: retryEmpty,
      );
    }

    final candidates = _scriptCandidates();
    Object? lastError;
    for (final uri in candidates) {
      try {
        final response = await _getJson(
          uri,
          params,
          allowEmpty: allowEmpty,
          retryEmpty: retryEmpty,
        );
        _scriptUri = uri;
        return response;
      } on StalkerPortalException catch (e) {
        lastError = e;
      }
    }

    throw StalkerPortalException(
      'Could not reach the Stalker portal script at $_baseUrl. '
      'Tried: ${candidates.join(', ')}.',
      action: action,
      originalError: lastError,
    );
  }

  /// Absolute URIs to probe for the portal script.
  ///
  /// Absolute path candidates like `/server/load.php` are resolved against the
  /// origin (scheme://host:port) as well as against the base URL path, because
  /// some portals serve the UI from a subpath (e.g. `/c/`) while the API lives
  /// at the web root (`/server/load.php`).
  List<Uri> _scriptCandidates() {
    final base = Uri.tryParse(_baseUrl);
    final candidates = <Uri>[];

    if (base != null && base.path.toLowerCase().endsWith('.php')) {
      candidates.add(base);
    }

    final origin = base != null && base.hasScheme
        ? Uri(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null)
        : null;

    for (final path in _kScriptCandidates) {
      if (origin != null) {
        final originUri = origin.resolve(path);
        if (!candidates.contains(originUri)) {
          candidates.add(originUri);
        }
      }
      final appended = Uri.tryParse('$_baseUrl$path');
      if (appended != null && !candidates.contains(appended)) {
        candidates.add(appended);
      }
      if (_baseUrl.endsWith('/c') || _baseUrl.endsWith('/c/')) {
        final stripped = _baseUrl.replaceAll(RegExp(r'/c/?$'), '');
        final replaced = Uri.tryParse('$stripped$path');
        if (replaced != null && !candidates.contains(replaced)) {
          candidates.add(replaced);
        }
      }
    }
    return candidates;
  }

  /// Builds the portal cookie header.
  ///
  /// The Stalker API identifies the device from the `mac` cookie and also
  /// honours `sn` (serial number), `token`, `PHPSESSID`, and other session
  /// cookies returned in `Set-Cookie` responses.
  String _cookieHeader() {
    final mac = _macAddress;
    final serial = (_serial ?? _macAddress).isNotEmpty
        ? (_serial ?? _macAddress)
        : mac;
    final cookies = <String, String>{
      'mac': mac,
      'sn': serial,
      'stb_lang': 'en',
      'timezone': 'UTC',
      ..._sessionCookies,
    };
    if (_token != null && _token!.isNotEmpty) {
      cookies['token'] = _token!;
    }
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  void _saveCookies(HttpClientResponse response) {
    for (final cookie in response.cookies) {
      _sessionCookies[cookie.name] = cookie.value;
    }
    final rawSetCookies = response.headers[HttpHeaders.setCookieHeader];
    if (rawSetCookies != null) {
      for (final raw in rawSetCookies) {
        try {
          final cookie = Cookie.fromSetCookieValue(raw);
          _sessionCookies[cookie.name] = cookie.value;
        } catch (_) {}
      }
    }
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri,
    Map<String, dynamic> params, {
    bool allowEmpty = false,
    bool retryEmpty = false,
  }) async {
    var attempt = 0;
    var emptyAttempt = 0;
    while (true) {
      await _throttle();
      try {
        return await _getJsonOnce(uri, params);
      } on StalkerPortalException catch (e) {
        if (e.isEmptyResponse) {
          // Portals throttle by answering with an empty body. Data actions
          // retry it like a 429; when the budget is exhausted they either
          // degrade to an empty result (allowEmpty) or fail.
          if (retryEmpty && emptyAttempt < _kMaxEmptyRetries) {
            emptyAttempt++;
            final delay = _retryDelayFor(emptyAttempt, e);
            _logger.warning(
              'Stalker portal returned an empty response (possibly '
              'throttled); retrying in ${delay.inMilliseconds}ms '
              '(attempt $emptyAttempt/$_kMaxEmptyRetries)...',
              tag: 'StalkerPortalClient',
              error: e,
            );
            await Future.delayed(delay);
            continue;
          }
          if (allowEmpty) return const {};
          rethrow;
        }

        final retryable = _isRetryable(e);
        if (!retryable || attempt >= _kMaxHttpRetries) rethrow;

        attempt++;
        final delay = _retryDelayFor(attempt, e);
        _logger.warning(
          'Stalker request throttled (${e.message}); retrying in '
          '${delay.inMilliseconds}ms (attempt $attempt/$_kMaxHttpRetries)...',
          tag: 'StalkerPortalClient',
          error: e,
        );
        await Future.delayed(delay);
      }
    }
  }

  Future<Map<String, dynamic>> _getJsonOnce(
    Uri uri,
    Map<String, dynamic> params,
  ) async {
    final query = Uri(
      queryParameters: params.map((key, value) => MapEntry(key, '$value')),
    ).query;
    final requestUri = query.isEmpty ? uri : uri.replace(query: query);

    final request = await _httpClient.getUrl(requestUri).timeout(_kRequestTimeout);
    request.headers.set(HttpHeaders.userAgentHeader, _kUserAgent);
    request.headers.set('X-User-Agent', 'Model: MAG250; Link: WiFi');
    request.headers.set(HttpHeaders.cookieHeader, _cookieHeader());
    if (_token != null && _token!.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    }

    final response = await request.close().timeout(_kRequestTimeout);
    _saveCookies(response);

    final bytes = await response.fold<List<int>>(
      [],
      (prev, chunk) => prev..addAll(chunk),
    ).timeout(_kRequestTimeout);
    final rawBody = utf8.decode(bytes, allowMalformed: true);
    final body = _cleanResponseBody(rawBody);

    if (response.statusCode != 200) {
      throw StalkerPortalException(
        'Portal returned HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
        originalError: body.isNotEmpty ? body : null,
      );
    }

    final contentType = response.headers.contentType?.mimeType ?? '';
    if ((contentType.contains('text/html') || _looksLikeHtml(body)) &&
        !body.contains('{"js"') &&
        !body.contains('{"data"')) {
      throw StalkerPortalException(
        'Portal script returned HTML instead of JSON.',
        originalError: body.isNotEmpty ? body : null,
      );
    }

    if (body.trim().isEmpty) {
      throw const StalkerPortalException(
        'Portal returned an empty response.',
        isEmptyResponse: true,
      );
    }

    final decoded = json.decode(body);
    if (decoded is List) {
      return {'js': decoded, 'data': decoded};
    }
    if (decoded is! Map) {
      throw const StalkerPortalException('Unexpected portal response format.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static String _cleanResponseBody(String raw) {
    var text = raw.trim();
    if (text.contains('/*-USER-START*/')) {
      final startIndex =
          text.indexOf('/*-USER-START*/') + '/*-USER-START*/'.length;
      final endIndex = text.lastIndexOf('/*-USER-END*/');
      if (endIndex > startIndex) {
        text = text.substring(startIndex, endIndex).trim();
      } else {
        text = text.substring(startIndex).trim();
      }
    }
    text = text.replaceAll(RegExp(r'^<script[^>]*>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'</script>$', caseSensitive: false), '');
    return text.trim();
  }

  /// Whether [e] describes a transient failure worth retrying.
  ///
  /// Rate limiting (429) and gateway errors (500/502/503/504) are retried
  /// because the portal throttles requests per source IP and a brief backoff
  /// usually resolves them. All other failures are treated as permanent.
  static bool _isRetryable(StalkerPortalException e) {
    final code = e.statusCode;
    return code != null && _kRetryableStatusCodes.contains(code);
  }

  /// Computes the retry delay: the portal's `Retry-After` header when present,
  /// otherwise exponential backoff with a small random jitter.
  Duration _retryDelayFor(int attempt, StalkerPortalException e) {
    final retryAfter = _retryAfterSeconds(e.originalError);
    if (retryAfter != null) {
      return Duration(seconds: retryAfter.clamp(1, 30));
    }

    final random = attempt * 173 + DateTime.now().millisecondsSinceEpoch % 97;
    final jitter = random % 250;
    return _retryBaseDelay * (1 << (attempt - 1)) +
        Duration(milliseconds: jitter);
  }

  /// Reads a numeric `Retry-After` value from a 429 error payload if present.
  static int? _retryAfterSeconds(Object? originalError) {
    final body = originalError?.toString();
    if (body == null || body.isEmpty) return null;
    final match = RegExp(r'Retry-After:\s*(\d+)', caseSensitive: false)
        .firstMatch(body);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// Enforces a minimum interval between portal requests.
  ///
  /// Portals commonly rate-limit by IP and reject bursts of requests with
  /// HTTP 429. Staggering catalog sync requests reduces how often the limiter
  /// trips in the first place.
  Future<void> _throttle() async {
    final last = _lastRequestAt;
    if (last != null) {
      final remaining = _kMinRequestInterval - DateTime.now().difference(last);
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
    }
    _lastRequestAt = DateTime.now();
  }

  static Map<String, dynamic> _envelope(Map<String, dynamic> data) {
    final js = data['js'];
    if (js is Map) return Map<String, dynamic>.from(js);
    return data;
  }

  static List<Map<String, dynamic>> _extractList(Map<String, dynamic> data) {
    final js = data['js'];
    if (js is List) {
      return _asMapList(js);
    }
    if (js is Map) {
      if (js['data'] is List) {
        return _asMapList(js['data']);
      }
      if (js['items'] is List) {
        return _asMapList(js['items']);
      }
    }
    if (data['data'] is List) {
      return _asMapList(data['data']);
    }
    if (data['items'] is List) {
      return _asMapList(data['items']);
    }
    return const [];
  }

  static List<Map<String, dynamic>> _asMapList(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static String? _stringAt(
    Map<String, dynamic> data,
    List<String> paths,
  ) {
    for (final path in paths) {
      final parts = path.split('.');
      dynamic current = data;
      var found = true;
      for (final part in parts) {
        if (current is Map && current.containsKey(part)) {
          current = current[part];
        } else {
          found = false;
          break;
        }
      }
      if (found && current != null) {
        return current.toString();
      }
    }
    return null;
  }

  static String? _extractStreamUrlFromResponse(
    Map<String, dynamic> data, [
    String? baseUrl,
  ]) {
    // 1. Check data['js'] as String
    final js = data['js'];
    if (js is String && js.trim().isNotEmpty) {
      final url = _extractStreamUrl(js, baseUrl);
      if (url != null) return url;
    }
    // 2. Check data['js'] as Map
    if (js is Map) {
      final url = _stringAt(Map<String, dynamic>.from(js), [
        'url',
        'data.url',
        'cmd',
        'data.cmd',
        'stream_url',
        'data.stream_url',
      ]);
      if (url != null && url.isNotEmpty) {
        final extracted = _extractStreamUrl(url, baseUrl);
        if (extracted != null) return extracted;
      }
    }
    // 3. Check data['js'] as List
    if (js is List && js.isNotEmpty) {
      for (final item in js) {
        if (item is Map) {
          final url = _stringAt(Map<String, dynamic>.from(item), [
            'url',
            'data.url',
            'cmd',
            'data.cmd',
            'stream_url',
          ]);
          if (url != null && url.isNotEmpty) {
            final extracted = _extractStreamUrl(url, baseUrl);
            if (extracted != null) return extracted;
          }
        } else if (item is String) {
          final extracted = _extractStreamUrl(item, baseUrl);
          if (extracted != null) return extracted;
        }
      }
    }
    // 4. Check data direct fields
    final direct = _stringAt(data, [
      'url',
      'data.url',
      'cmd',
      'data.cmd',
      'stream_url',
      'data.stream_url',
    ]);
    if (direct != null && direct.isNotEmpty) {
      final extracted = _extractStreamUrl(direct, baseUrl);
      if (extracted != null) return extracted;
    }

    return null;
  }

  /// Extracts the stream URL from a `cmd` or response value which may be an
  /// `ffmpeg -i 'URL' ...`, `ffrt URL`, `auto /media/...` command or raw URL.
  static String? _extractStreamUrl(String input, [String? baseUrl]) {
    var trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Clean common command / proxy wrappers
    const prefixes = [
      'ffmpeg -re -i ',
      'ffmpeg -i ',
      'ffmpeg ',
      'ffrt4 ',
      'ffrt3 ',
      'ffrt2 ',
      'ffrt ',
      'auto ',
    ];
    for (final p in prefixes) {
      if (trimmed.toLowerCase().startsWith(p)) {
        trimmed = trimmed.substring(p.length).trim();
      }
    }

    // Unquote if wrapped in quotes
    if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
      trimmed = trimmed.substring(1, trimmed.length - 1).trim();
    }

    // Match HTTP/HTTPS full URL
    final httpMatch = RegExp(r'''https?://[^\s"'<>]+''', caseSensitive: false).firstMatch(trimmed);
    if (httpMatch != null) {
      return _sanitizeUrl(httpMatch.group(0)!);
    }

    // Match stream protocols
    final protoMatch = RegExp(r'''(rtmp|rtmps|rtsp|mms|udp)://[^\s"'<>]+''', caseSensitive: false).firstMatch(trimmed);
    if (protoMatch != null) {
      return _sanitizeUrl(protoMatch.group(0)!);
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null &&
        (uri.scheme == 'http' ||
            uri.scheme == 'https' ||
            uri.scheme == 'rtmp' ||
            uri.scheme == 'rtsp' ||
            uri.scheme == 'rtmps' ||
            uri.scheme == 'mms' ||
            uri.scheme == 'udp')) {
      return trimmed;
    }

    if (baseUrl != null && baseUrl.isNotEmpty) {
      if (trimmed.startsWith('/') || (trimmed.contains('.') && !trimmed.contains(' '))) {
        final base = Uri.tryParse(baseUrl);
        if (base != null && base.hasScheme && base.host.isNotEmpty) {
          return base.resolve(trimmed).toString();
        }
      }
    }

    return null;
  }

  static String _sanitizeUrl(String value) {
    var url = value.trim();
    while (url.endsWith(')') || url.endsWith(']') || url.endsWith('"')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static bool _looksLikeHtml(String body) {
    final trimmed = body.trimLeft();
    return trimmed.startsWith('<') && trimmed.toLowerCase().contains('<html');
  }

  /// Ensures the portal URL carries a scheme so [Uri] resolution works.
  ///
  /// Users often paste a bare host like `portal.example.com` (optionally with a
  /// path such as `/c/`). Without a scheme, `Uri.parse` treats the host as a
  /// path, producing an empty `host` and a confusing `ArgumentError` later.
  static String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.isEmpty) {
      return 'http://$trimmed';
    }
    return trimmed;
  }

  static String _normalizeMac(String mac) {
    final cleaned = mac.trim().toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    if (cleaned.length != 12) return mac.trim();
    final pairs = <String>[];
    for (var i = 0; i < 12; i += 2) {
      pairs.add(cleaned.substring(i, i + 2));
    }
    return pairs.join(':');
  }
}
