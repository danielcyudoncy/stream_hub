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
  static String redactUrl(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return url;
      if (uri.queryParameters.isEmpty) return url;

      final safeQuery = uri.queryParameters.map((key, value) {
        final lower = key.toLowerCase();
        final isSensitive = sensitiveQueryKeys.any((k) => lower.contains(k));
        return MapEntry(key, isSensitive ? _placeholder : value);
      });

      return uri.replace(queryParameters: safeQuery).toString();
    } on FormatException {
      return url;
    }
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
