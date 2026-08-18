import '../../data/models/media_item.dart';

class ImageUrlFormatter {
  static const String tmdbBaseUrl = 'https://image.tmdb.org/t/p/w500';

  /// Formats any raw image string into a valid, displayable absolute URL.
  ///
  /// Handles:
  /// - TMDB image paths (e.g. `/abc.jpg` -> `https://image.tmdb.org/t/p/w500/abc.jpg`)
  /// - Raw TMDB filenames (e.g. `abc.jpg` -> `https://image.tmdb.org/t/p/w500/abc.jpg`)
  /// - Full HTTP/HTTPS URLs (safely encoded for spaces and special characters)
  /// - Protocol-relative URLs (e.g. `//image.tmdb.org/...` -> `https://image.tmdb.org/...`)
  /// - Server / Portal relative paths (using serverUrl or portalUrl from metadata)
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
        str == 'false') {
      return null;
    }

    // Strip wrapping quotes e.g. "\"http://...\""
    if ((str.startsWith('"') && str.endsWith('"')) ||
        (str.startsWith("'") && str.endsWith("'"))) {
      str = str.substring(1, str.length - 1).trim();
    }

    // Replace escaped forward slashes and backslashes
    str = str.replaceAll(r'\/', '/').replaceAll(r'\', '/');

    // Protocol-relative URLs
    if (str.startsWith('//')) {
      str = 'https:$str';
    }

    // Force HTTPS on TMDB image domains
    if (str.startsWith('http://image.tmdb.org')) {
      str = str.replaceFirst('http://image.tmdb.org', 'https://image.tmdb.org');
    }

    // Already an absolute HTTP/HTTPS URL
    if (str.startsWith('http://') || str.startsWith('https://')) {
      return _safeEncode(str);
    }

    // Explicit TMDB path prefix
    if (str.startsWith('/t/p/')) {
      return _safeEncode('https://image.tmdb.org$str');
    }

    final effectiveServerUrl = serverUrl ??
        item?.metadata['serverUrl']?.toString() ??
        item?.metadata['portalUrl']?.toString() ??
        '';

    // TMDB relative path starting with /
    if (str.startsWith('/')) {
      final pathWithoutSlash = str.substring(1);
      // Single filename after slash (e.g. /1E5baAaEse26fej7uHcjOgEE2t2.jpg) is TMDB
      if (!pathWithoutSlash.contains('/')) {
        return _safeEncode('$tmdbBaseUrl$str');
      }
      // Multi-segment path is relative to server/portal
      if (effectiveServerUrl.isNotEmpty) {
        final origin = Uri.tryParse(effectiveServerUrl)?.origin ??
            effectiveServerUrl.replaceAll(RegExp(r'/+$'), '');
        return _safeEncode('$origin$str');
      }
      return _safeEncode('$tmdbBaseUrl$str');
    }

    // Bare TMDB filename without leading slash (e.g. 1E5baAaEse26fej7uHcjOgEE2t2.jpg)
    final isBareImageFile = RegExp(
      r'^[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp|svg)$',
      caseSensitive: false,
    ).hasMatch(str);

    if (isBareImageFile) {
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
    return null;
  }
}

