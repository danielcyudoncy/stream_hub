import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';

/// Content types supported by the Stalker portal API.
enum StalkerContentType { live, vod, series }

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
class StalkerPortalException implements Exception {
  final String message;
  final String? action;
  final Object? originalError;

  const StalkerPortalException(
    this.message, {
    this.action,
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
class StalkerPortalClient {
  static const Duration _kRequestTimeout = Duration(seconds: 15);
  static const List<String> _kScriptCandidates = [
    '/server/load.php',
    '/stalker_portal/server/load.php',
    '/portal.php',
  ];

  final String _baseUrl;
  final String _macAddress;
  final String? _serial;
  final LoggingService _logger;
  final HttpClient _httpClient;

  String? _token;
  String? _scriptPath;

  StalkerPortalClient({
    required String baseUrl,
    required String macAddress,
    String? serial,
    String? token,
    LoggingService? logger,
    HttpClient? httpClient,
  }) : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
       _macAddress = _normalizeMac(macAddress),
       _serial = serial,
       _token = token,
       _logger = logger ?? LoggingService(),
       _httpClient = httpClient ?? createDohAwareHttpClient();

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
        _stringAt(js, ['token', 'data.token'])?.trim() ?? '';
    if (rawToken.isEmpty) {
      throw const StalkerPortalException(
        'Handshake did not return a portal token.',
        action: 'handshake',
      );
    }

    _token = rawToken;
    final serial = _stringAt(js, ['serial', 'data.serial']);

    _logger.info('Stalker handshake complete for $_macAddress', tag: 'StalkerPortalClient');
    return StalkerHandshakeResult(token: rawToken, serial: serial, raw: data);
  }

  /// Returns the authenticated subscriber profile.
  Future<Map<String, dynamic>> getProfile() async {
    final data = await _request('get_profile');
    final js = _envelope(data);
    final profile = js['data'];
    if (profile is Map) {
      return Map<String, dynamic>.from(profile);
    }
    return const {};
  }

  /// Live TV / VOD / Series categories.
  Future<List<Map<String, dynamic>>> getCategories(
    StalkerContentType type,
  ) async {
    final data = await _request(
      'get_categories',
      extra: {'type': type.name},
    );
    return _asMapList(_envelope(data)['data']);
  }

  /// Live TV channel list (`get_ordered_list?type=live`).
  Future<List<Map<String, dynamic>>> getOrderedList(
    StalkerContentType type,
  ) async {
    final data = await _request(
      'get_ordered_list',
      extra: {'type': type.name},
    );
    return _asMapList(_envelope(data)['data']);
  }

  /// VOD movie list.
  Future<List<Map<String, dynamic>>> getVodList() async {
    final data = await _request('get_vod_list', extra: {'type': 'vod'});
    return _asMapList(_envelope(data)['data']);
  }

  /// Series list (each show carries its own `seasons`/`episodes`).
  Future<List<Map<String, dynamic>>> getSeriesList() async {
    final data = await _request(
      'get_series_list',
      extra: {'type': 'series'},
    );
    return _asMapList(_envelope(data)['data']);
  }

  /// Converts a stored `cmd` into a playable stream URL.
  ///
  /// Some portals answer with a direct `url`, others embed the stream inside an
  /// `ffmpeg -i 'URL' ...` command. When the portal returns neither, the input
  /// `cmd` is used as a fallback (many portals ship it as a direct URL).
  Future<String> createLink({
    required StalkerContentType type,
    required String cmd,
    String? genre,
  }) async {
    final data = await _request(
      'create_link',
      extra: {
        'type': type.name,
        'cmd': cmd,
        if (genre != null && genre.isNotEmpty) 'genre': genre,
      },
    );
    final js = _envelope(data);

    final url = _stringAt(js, ['url', 'data.url']);
    if (url != null && url.isNotEmpty) {
      return _sanitizeUrl(url);
    }

    final portalCmd = _stringAt(js, ['cmd', 'data.cmd']);
    if (portalCmd != null && portalCmd.isNotEmpty) {
      final extracted = _extractStreamUrl(portalCmd);
      if (extracted != null) return extracted;
    }

    final direct = _extractStreamUrl(cmd);
    if (direct != null) return direct;

    throw const StalkerPortalException(
      'Portal did not return a playable stream URL.',
      action: 'create_link',
    );
  }

  Future<Map<String, dynamic>> _request(
    String action, {
    Map<String, dynamic>? extra,
  }) async {
    final params = <String, dynamic>{
      'type': 'stb',
      'action': action,
      'token': _token ?? '',
      'Mac': _macAddress,
      'sn': _serial ?? _macAddress,
      'ver': '4.8.0',
      'JsHttpRequest': '1-xml',
      ...?extra,
    };

    if (_scriptPath != null) {
      return _postJson(_scriptPath!, params);
    }

    Object? lastError;
    for (final candidate in _kScriptCandidates) {
      try {
        final response = await _postJson(candidate, params);
        _scriptPath = candidate;
        return response;
      } on StalkerPortalException catch (e) {
        lastError = e;
      }
    }

    throw StalkerPortalException(
      'Could not reach the Stalker portal script at $_baseUrl.',
      action: action,
      originalError: lastError,
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> params,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = await _httpClient.postUrl(uri).timeout(_kRequestTimeout);
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/x-www-form-urlencoded',
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'StreamHubPro/1.0');
    request.write(
      Uri(queryParameters: params.map((key, value) => MapEntry(key, '$value'))).query,
    );

    final response = await request.close().timeout(_kRequestTimeout);
    final bytes = await response.fold<List<int>>(
      [],
      (prev, chunk) => prev..addAll(chunk),
    );
    final body = utf8.decode(bytes, allowMalformed: true);

    if (response.statusCode != 200) {
      throw StalkerPortalException(
        'Portal returned HTTP ${response.statusCode}.',
        originalError: body.isNotEmpty ? body : null,
      );
    }

    final contentType = response.headers.contentType?.mimeType ?? '';
    if (contentType.contains('text/html') || _looksLikeHtml(body)) {
      throw StalkerPortalException(
        'Portal script returned HTML instead of JSON.',
        originalError: body.isNotEmpty ? body : null,
      );
    }

    final decoded = json.decode(body);
    if (decoded is! Map) {
      throw const StalkerPortalException('Unexpected portal response format.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static Map<String, dynamic> _envelope(Map<String, dynamic> data) {
    final js = data['js'];
    if (js is Map) return Map<String, dynamic>.from(js);
    return data;
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

  /// Extracts the stream URL from a `cmd` value which is usually an
  /// `ffmpeg -i 'URL' ...` command. Falls back to the raw value when it is
  /// already a plain http(s) URL.
  static String? _extractStreamUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final match = RegExp(r'''https?://[^\s"'<>]+''').firstMatch(trimmed);
    if (match != null) {
      return _sanitizeUrl(match.group(0)!);
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null &&
        (uri.scheme == 'http' ||
            uri.scheme == 'https' ||
            uri.scheme == 'rtmp' ||
            uri.scheme == 'rtsp')) {
      return trimmed;
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
