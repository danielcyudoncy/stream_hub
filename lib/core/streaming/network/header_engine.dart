import 'dart:convert';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/security/sensitive_data_redactor.dart';

/// Builds and merges the complete set of HTTP headers attached to a resolved
/// stream. Supports User-Agent, Referer, Origin, Authorization, Bearer Token,
/// Cookies, Accept, Accept-Language, Accept-Encoding, and custom headers.
class HeaderEngine {
  static const String kDefaultUserAgent = 'StreamHubPro/1.0';

  /// Builds the header set for a stream request.
  ///
  /// Priority (highest last): provider headers < built-in identity headers <
  /// explicit overrides.
  Map<String, String> buildHeaders({
    String? userAgent,
    String? referer,
    String? origin,
    String? bearerToken,
    Map<String, String>? cookies,
    Map<String, String>? providerHeaders,
    Map<String, String>? custom,
    bool includeAccept = true,
    bool includeCookies = true,
    bool includeBearer = true,
  }) {
    final headers = <String, String>{
      if (includeAccept) 'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'identity',
      'User-Agent': userAgent ?? kDefaultUserAgent,
    };

    if (providerHeaders != null) {
      headers.addAll(providerHeaders);
    }
    if (referer != null && referer.isNotEmpty) {
      headers['Referer'] = referer;
    }
    if (origin != null && origin.isNotEmpty) {
      headers['Origin'] = origin;
    }
    if (includeBearer && bearerToken != null && bearerToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }
    if (includeCookies && cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] = serializeCookies(cookies);
    }
    if (custom != null) {
      headers.addAll(custom);
    }

    _validate(headers);
    return headers;
  }

  /// Builds headers directly from a provider session.
  Map<String, String> fromSession(
    ProviderSession session, {
    Map<String, String>? custom,
    bool includeAuth = true,
  }) {
    return buildHeaders(
      userAgent: session.userAgent,
      referer: session.referer,
      origin: session.origin,
      bearerToken: includeAuth ? session.bearerToken : null,
      cookies: includeAuth ? session.cookies : null,
      providerHeaders: session.headers,
      custom: custom,
      includeBearer: includeAuth,
      includeCookies: includeAuth,
    );
  }

  /// Serializes a cookie map into a single Cookie header value.
  static String serializeCookies(Map<String, String> cookies) {
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// Parses a Cookie header value into a map.
  static Map<String, String> parseCookies(String cookieHeader) {
    final result = <String, String>{};
    for (final part in cookieHeader.split(';')) {
      final pair = part.trim();
      if (pair.isEmpty) continue;
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      result[pair.substring(0, eq)] = pair.substring(eq + 1);
    }
    return result;
  }

  /// Creates a Basic Authorization header value from credentials.
  static String basicAuth(String username, String password) {
    final credentials = '$username:$password';
    return 'Basic ${base64Encode(utf8.encode(credentials))}';
  }

  void _validate(Map<String, String> headers) {
    for (final entry in headers.entries) {
      if (entry.key.contains('\r') ||
          entry.key.contains('\n') ||
          entry.value.contains('\r') ||
          entry.value.contains('\n')) {
        throw FormatException('Header contains invalid line breaks.');
      }
    }
  }

  /// Debug-safe description of a header set.
  Map<String, String> redacted(Map<String, String> headers) {
    return SensitiveDataRedactor.redactHeaders(headers);
  }
}
