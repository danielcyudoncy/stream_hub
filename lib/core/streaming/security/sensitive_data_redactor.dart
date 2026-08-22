import 'dart:convert';

/// Redacts sensitive values (passwords, tokens, cookies, MAC addresses, etc.)
/// from log messages and user-facing output.
///
/// The Stream Engine never logs raw credentials. This helper guarantees that
/// sensitive values are scrubbed before anything reaches the logger.
class SensitiveDataRedactor {
  static const _placeholder = '[REDACTED]';

  /// Known sensitive header names (case-insensitive).
  static const Set<String> sensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'api-key',
    'x-auth-token',
    'x-access-token',
    'token',
  };

  /// Header values or tokens that must never be logged.
  static const Set<String> sensitiveQueryKeys = {
    'token',
    'password',
    'pass',
    'auth',
    'key',
    'api_key',
    'apikey',
    'signature',
    'mac',
    'user',
    'username',
    'login',
  };

  /// Redacts the value of sensitive HTTP headers.
  static Map<String, String> redactHeaders(Map<String, String> headers) {
    return headers.map((key, value) {
      if (sensitiveHeaders.contains(key.toLowerCase())) {
        return MapEntry(key, _placeholder);
      }
      return MapEntry(key, value);
    });
  }

  /// Redacts sensitive query parameters from a URL.
  ///
  /// Also masks credential-bearing components outside the query string:
  /// - userinfo (`user:password@host`)
  /// - Xtream-style path credentials (`/live/<user>/<pass>/<id>.ts`,
  ///   `/movie/<user>/<pass>/...`, `/series/<user>/<pass>/...`)
  static String redactUrl(String url) {
    var result = url;
    try {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.queryParameters.isNotEmpty) {
        final safeQuery = uri.queryParameters.map((key, value) {
          final lower = key.toLowerCase();
          final isSensitive =
              sensitiveQueryKeys.any((k) => lower.contains(k));
          return MapEntry(key, isSensitive ? _placeholder : value);
        });
        result = uri.replace(queryParameters: safeQuery).toString();
      }
    } on FormatException {
      // Fall through to component masking below.
    }
    // Uri rejects '[' / ']' inside the authority component, so userinfo is
    // masked textually after composition.
    return _maskPathCredentials(
      _maskUserInfo(result.replaceAll(_encodedPlaceholder, _placeholder)),
    );
  }

  static const _encodedPlaceholder = '%5BREDACTED%5D';

  static final RegExp _userInfoPattern = RegExp(r'(://)([^@/?#]+)@');

  /// Masks the userinfo component (`user:password@host`) of any URI.
  static String _maskUserInfo(String url) {
    return url.replaceAllMapped(_userInfoPattern, (m) => '${m[1]}$_placeholder@');
  }

  static final RegExp _pathCredentialPattern = RegExp(
    r'/(?:live|movie|series)/([^/?#]+)/([^/?#]+)',
    caseSensitive: false,
  );

  /// Masks both username and password segments of Xtream-style stream paths.
  /// The trailing resource identifier (e.g. `/2539.ts`) stays readable so logs
  /// remain useful for debugging channel issues.
  static String _maskPathCredentials(String url) {
    return url.replaceAllMapped(_pathCredentialPattern, (_) {
      return '/$_placeholder/$_placeholder';
    });
  }

  /// Redacts known sensitive values that appear in [message].
  static String redact(String message, Iterable<String?> secrets) {
    var result = message;
    for (final secret in secrets) {
      if (secret != null && secret.isNotEmpty) {
        result = result.replaceAll(secret, _placeholder);
      }
    }
    return result;
  }

  /// Redacts everything in a map of headers and a URL for logging.
  static String describeRequest(String url, Map<String, String> headers) {
    return 'url=${redactUrl(url)} headers=${json.encode(redactHeaders(headers))}';
  }
}
