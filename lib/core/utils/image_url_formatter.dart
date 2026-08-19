import 'dart:convert';
import '../../data/models/media_item.dart';

class ImageUrlFormatter {
  static const String tmdbBaseUrl = 'https://image.tmdb.org/t/p/w500';

  /// Regex pattern to identify TMDB artwork hashes (typically 15+ alphanumeric chars).
  static final RegExp _tmdbHashPattern = RegExp(
    r'^[a-zA-Z0-9_-]{15,}\.(jpg|jpeg|png|webp|svg)$',
    caseSensitive: false,
  );

  /// Regex pattern to identify any standard image filename without subdirectories.
  static final RegExp _bareImagePattern = RegExp(
    r'^[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp|svg)$',
    caseSensitive: false,
  );

  /// Formats any raw image string into a valid, displayable absolute URL.
  ///
  /// Handles:
  /// - TMDB image paths (e.g. `/7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg` -> `https://image.tmdb.org/t/p/w500/7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg`)
  /// - Explicit TMDB prefixes (e.g. `/t/p/w500/abc.jpg` -> `https://image.tmdb.org/t/p/w500/abc.jpg`)
  /// - Full HTTP/HTTPS URLs (safely encoded for spaces and special characters)
  /// - Protocol-relative URLs (e.g. `//image.tmdb.org/...` -> `https://image.tmdb.org/...`)
  /// - Server / Portal relative paths (using serverUrl or portalUrl from metadata)
  /// - JSON-encoded array strings (e.g. `"[\"/path.jpg\"]"`)
  static String? format(
    dynamic raw, {
    String? serverUrl,
    MediaItem? item,
  }) {
    if (raw == null) return null;
    String str;
    if (raw is List) {
      if (raw.isEmpty) return null;
      str = raw.first?.toString().trim() ?? '';
    } else {
      str = raw.toString().trim();
    }

    if (str.isEmpty ||
        str == 'null' ||
        str == '[]' ||
        str == '{}' ||
        str == 'false' ||
        str == 'true' ||
        str == '0' ||
        str == 'N/A' ||
        str == 'n/a' ||
        str == 'none' ||
        str == 'undefined') {
      return null;
    }

    // Handle JSON array string e.g. "[\"/poster.jpg\"]" or "[\"http://...\"]"
    if (str.startsWith('[') && str.endsWith(']')) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is List && decoded.isNotEmpty) {
          return format(decoded.first, serverUrl: serverUrl, item: item);
        }
      } catch (_) {
        var inner = str.substring(1, str.length - 1).trim();
        if ((inner.startsWith('"') && inner.endsWith('"')) ||
            (inner.startsWith("'") && inner.endsWith("'"))) {
          inner = inner.substring(1, inner.length - 1).trim();
        }
        if (inner.isNotEmpty) {
          return format(inner, serverUrl: serverUrl, item: item);
        }
      }
      return null;
    }

    // Strip wrapping quotes e.g. "\"http://...\""
    if ((str.startsWith('"') && str.endsWith('"')) ||
        (str.startsWith("'") && str.endsWith("'"))) {
      str = str.substring(1, str.length - 1).trim();
    }

    // Remove any newlines or tabs
    str = str.replaceAll(RegExp(r'[\r\n\t]'), '').trim();

    // Replace escaped forward slashes and backslashes
    str = str.replaceAll(r'\/', '/').replaceAll(r'\', '/');

    // Extract any embedded absolute URL (e.g. "http://panel:8080/https://image.tmdb.org/...")
    final httpIdx = str.lastIndexOf('http://');
    final httpsIdx = str.lastIndexOf('https://');
    final lastAbsIdx = httpsIdx > 0 ? httpsIdx : (httpIdx > 0 ? httpIdx : -1);
    if (lastAbsIdx > 0) {
      str = str.substring(lastAbsIdx);
    }

    // Protocol-relative URLs
    if (str.startsWith('//')) {
      str = 'https:$str';
    }

    // Force HTTPS on TMDB image domains
    if (str.startsWith('http://image.tmdb.org') ||
        str.startsWith('http://images.tmdb.org') ||
        str.startsWith('http://themoviedb.org') ||
        str.startsWith('http://www.themoviedb.org')) {
      str = str.replaceFirst('http://', 'https://');
    }

    // If the string contains TMDB's path prefix "/t/p/" anywhere, extract TMDB image URL
    final tpIdx = str.indexOf('/t/p/');
    if (tpIdx != -1) {
      final tmdbSubpath = str.substring(tpIdx);
      return _safeEncode('https://image.tmdb.org$tmdbSubpath');
    }

    // Already an absolute HTTP/HTTPS URL
    if (str.startsWith('http://') || str.startsWith('https://')) {
      return _safeEncode(str);
    }

    // Explicit TMDB path prefix
    if (str.startsWith('t/p/')) {
      return _safeEncode('https://image.tmdb.org/$str');
    }

    final effectiveServerUrl = serverUrl ??
        item?.metadata['serverUrl']?.toString() ??
        item?.metadata['portalUrl']?.toString() ??
        '';

    // Relative path starting with /
    if (str.startsWith('/')) {
      final pathWithoutSlash = str.substring(1);

      // Check if it's a TMDB hash (e.g. /7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg)
      if (_tmdbHashPattern.hasMatch(pathWithoutSlash)) {
        return _safeEncode('$tmdbBaseUrl$str');
      }

      // Single filename after slash (e.g. /inception.jpg)
      if (!pathWithoutSlash.contains('/')) {
        if (effectiveServerUrl.isNotEmpty) {
          final cleanBase = effectiveServerUrl.replaceAll(RegExp(r'/+$'), '');
          return _safeEncode('$cleanBase$str');
        }
        return _safeEncode('$tmdbBaseUrl$str');
      }

      // Multi-segment path is relative to server/portal (e.g. /images/poster.jpg)
      if (effectiveServerUrl.isNotEmpty) {
        final cleanBase = effectiveServerUrl.replaceAll(RegExp(r'/+$'), '');
        return _safeEncode('$cleanBase$str');
      }
      return _safeEncode('$tmdbBaseUrl$str');
    }

    // Bare TMDB hash filename without leading slash (e.g. 7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg)
    if (_tmdbHashPattern.hasMatch(str)) {
      return _safeEncode('$tmdbBaseUrl/$str');
    }

    // Other bare image files without leading slash (e.g. abc.jpg)
    if (_bareImagePattern.hasMatch(str)) {
      if (effectiveServerUrl.isNotEmpty) {
        final cleanBase = effectiveServerUrl.replaceAll(RegExp(r'/+$'), '');
        return _safeEncode('$cleanBase/$str');
      }
      return _safeEncode('$tmdbBaseUrl/$str');
    }

    // Bare numeric IDs (e.g. "123")
    if (int.tryParse(str) != null) {
      return str;
    }

    // Multi-segment relative path on the server/portal
    if (effectiveServerUrl.isNotEmpty && (str.contains('/') || str.contains('.'))) {
      final cleanBase = effectiveServerUrl.replaceAll(RegExp(r'/+$'), '');
      return _safeEncode('$cleanBase/$str');
    }

    return _safeEncode(str);
  }

  static String _safeEncode(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.hasScheme) {
        return uri.toString();
      }
      return Uri.encodeFull(url);
    } catch (_) {
      return Uri.encodeFull(url);
    }
  }

  /// Resolves the best available poster/cover image URL from a [MediaItem].
  ///
  /// Evaluates direct properties ([MediaItem.poster], [MediaItem.thumbnail],
  /// [MediaItem.backdrop]) and falls back to all known image keys in [MediaItem.metadata].
  static String? extractFromMediaItem(MediaItem item) {
    // 1. Direct properties (only non-empty formatted values)
    for (final prop in [item.poster, item.thumbnail, item.backdrop]) {
      final formatted = format(prop, item: item);
      if (formatted != null && formatted.isNotEmpty) {
        return formatted;
      }
    }

    // 2. Metadata map fallback
    final serverUrl = item.metadata['serverUrl']?.toString() ??
        item.metadata['portalUrl']?.toString();
    return extractFromMap(item.metadata, serverUrl: serverUrl);
  }

  /// Extracts an ordered list of all candidate artwork URLs from a [MediaItem].
  static List<String> extractCandidatesFromMediaItem(MediaItem item) {
    final urls = <String>{};
    for (final prop in [item.poster, item.thumbnail, item.backdrop]) {
      final formatted = format(prop, item: item);
      if (formatted != null && formatted.isNotEmpty) {
        urls.add(formatted);
      }
    }

    final serverUrl = item.metadata['serverUrl']?.toString() ??
        item.metadata['portalUrl']?.toString();
    for (final key in const [
      'stream_icon',
      'streamIcon',
      'cover_big',
      'coverBig',
      'cover',
      'cover_image',
      'coverImage',
      'movie_image',
      'movieImage',
      'movie_cover',
      'movieCover',
      'screenshot_uri',
      'screenshotUri',
      'poster_path',
      'posterPath',
      'poster',
      'poster_url',
      'posterUrl',
      'backdrop_path',
      'backdropPath',
      'backdrop',
    ]) {
      final val = item.metadata[key];
      final formatted = format(val, serverUrl: serverUrl);
      if (formatted != null && formatted.isNotEmpty) {
        urls.add(formatted);
      }
    }

    return urls.toList(growable: false);
  }

  /// Extracts the best available poster/cover image URL from a raw map
  /// (e.g. Xtream or Stalker API JSON object or MediaItem metadata).
  static String? extractFromMap(
    Map map, {
    String? serverUrl,
  }) {
    for (final key in const [
      'stream_icon',
      'streamIcon',
      'cover_big',
      'coverBig',
      'cover',
      'cover_image',
      'coverImage',
      'movie_image',
      'movieImage',
      'movie_cover',
      'movieCover',
      'screenshot_uri',
      'screenshotUri',
      'poster_path',
      'posterPath',
      'poster',
      'poster_url',
      'posterUrl',
      'icon',
      'icon_url',
      'iconUrl',
      'logo',
      'tvgLogo',
      'tvg-logo',
      'tvg_logo',
      'screenshot',
      'stream_icon_url',
      'streamIconUrl',
      'pic',
      'image',
      'img',
      'thumbnail',
      'thumb',
      'backdrop_path',
      'backdropPath',
      'backdrop',
    ]) {
      final val = map[key];
      final formatted = format(val, serverUrl: serverUrl);
      if (formatted != null && formatted.isNotEmpty) {
        return formatted;
      }
    }

    // Check nested objects (e.g. info, movie_data, data)
    for (final nestedKey in const ['info', 'movie_data', 'movieData', 'data']) {
      final nested = map[nestedKey];
      if (nested is Map) {
        final nestedPoster = extractFromMap(nested, serverUrl: serverUrl);
        if (nestedPoster != null && nestedPoster.isNotEmpty) {
          return nestedPoster;
        }
      }
    }

    return null;
  }
}

