import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';

/// Normalizes, canonicalizes, and sanitizes stream URLs before they reach a
/// player or download engine.
class UrlNormalizer {
  static const Set<String> supportedSchemes = {
    'http',
    'https',
    'rtsp',
    'rtmp',
    'rtmps',
    'mms',
  };

  static const Set<String> unsupportedButKnown = {
    'ftp',
    'file',
    'data',
    'udp',
    'tcp',
  };

  /// Parses and validates the URL, throwing [StreamMalformedUrlException] for
  /// malformed input and [StreamUnsupportedProtocolException] for protocols
  /// that can never be played.
  Uri parse(String url) {
    if (url.trim().isEmpty) {
      throw const StreamMalformedUrlException(message: 'Stream URL is empty.');
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.isEmpty || uri.scheme.length == 1) {
      throw const StreamMalformedUrlException(
        message: 'Stream URL could not be parsed.',
      );
    }
    if (unsupportedButKnown.contains(uri.scheme.toLowerCase())) {
      throw StreamUnsupportedProtocolException(
        message: 'Protocol "${uri.scheme}" is not supported.',
      );
    }
    return uri;
  }

  bool isSupported(String url) {
    try {
      return supportedSchemes.contains(parse(url).scheme.toLowerCase());
    } on ApplicationException {
      return false;
    }
  }

  /// Canonicalizes the URL: lowercases scheme/host, encodes illegal characters,
  /// strips empty query parameters, removes fragments, and sorts the query
  /// string for cache-key stability.
  String canonicalize(String url) {
    final uri = parse(url);
    var result = uri.removeFragment();

    result = result.replace(scheme: uri.scheme.toLowerCase());

    if (uri.host.isNotEmpty) {
      result = result.replace(host: uri.host.toLowerCase());
    }

    final query = _cleanQuery(uri.queryParameters);
    result = result.replace(queryParameters: query.isEmpty ? null : query);

    return result.toString();
  }

  Map<String, String> _cleanQuery(Map<String, String> query) {
    final cleaned = <String, String>{};
    for (final entry in query.entries) {
      if (entry.value.isEmpty) continue;
      cleaned[entry.key] = entry.value;
    }
    return cleaned;
  }

  /// Resolves a possibly relative URL against a base URL (e.g. a playlist URL
  /// or provider server URL).
  String resolveRelative(String url, String baseUrl) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw const StreamMalformedUrlException(
        message: 'Stream URL could not be parsed.',
      );
    }
    if (uri.isAbsolute) return url;
    final base = Uri.tryParse(baseUrl);
    if (base == null || !base.isAbsolute) return url;
    return base.resolveUri(uri).toString();
  }

  /// Removes duplicate query parameters by keeping the last value.
  String removeDuplicateParameters(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final query = uri.queryParametersAll;
    final hasDuplicates = query.values.any((values) => values.length > 1);
    if (!hasDuplicates) return url;

    final deduped = <String, String>{};
    for (final entry in query.entries) {
      deduped[entry.key] = entry.value.last;
    }
    return uri.replace(queryParameters: deduped).toString();
  }

  /// Strips credentials embedded in a URL (`user:pass@host`). The extracted
  /// credentials should be supplied via headers instead.
  ({String url, String? userInfo}) stripUserInfo(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return (url: url, userInfo: null);
    if (uri.userInfo.isEmpty) return (url: url, userInfo: null);
    final stripped = uri.replace(userInfo: '');
    return (url: stripped.toString(), userInfo: uri.userInfo);
  }
}
