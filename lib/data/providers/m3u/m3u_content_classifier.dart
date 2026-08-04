import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/m3u_models.dart';

/// Classifies M3U playlist entries into live channels, movies and series.
///
/// Classification signal priority:
/// 1. The `tvg-type` EXTINF attribute (authoritative).
/// 2. The stream URL path (e.g. `/movie/`, `/series/`).
/// 3. The group-title keywords (weakest signal).
class M3UContentClassifier {
  static const _tvgTypeMovie = 'movie';
  static const _tvgTypeVod = 'vod';
  static const _tvgTypeSeries = 'series';
  static const _tvgTypeTvShow = 'tvshow';
  static const _tvgTypeShow = 'show';
  static const _tvgTypeLive = 'live';
  static const _tvgTypeChannel = 'channel';
  static const _tvgTypeTv = 'tv';

  static const _urlMovieSegments = {'movie', 'movies', 'vod', 'films'};
  static const _urlSeriesSegments = {'series', 'tv series', 'tv show', 'tvshow'};

  static const _groupMovieKeywords = {'movie', 'movies', 'film', 'films', 'vod'};
  static const _groupSeriesKeywords = {
    'series',
    'tv show',
    'tv shows',
    'tvshow',
    'shows',
  };

  const M3UContentClassifier._();

  static MediaType classify(M3UChannel channel) {
    final tvgType = _normalize(channel.attributes['tvg-type']);
    if (tvgType != null && tvgType.isNotEmpty) {
      return _classifyByTvgType(tvgType);
    }

    final urlType = _classifyByUrl(channel.streamUrl);
    if (urlType != null) {
      return urlType;
    }

    return _classifyByGroup(channel.group);
  }

  static MediaType _classifyByTvgType(String type) {
    if (type.contains(_tvgTypeMovie) ||
        type == _tvgTypeVod ||
        type.contains('film')) {
      return MediaType.movie;
    }
    if (type.contains(_tvgTypeSeries) ||
        type == _tvgTypeTvShow ||
        type.contains('tvshow') ||
        type.contains(_tvgTypeShow)) {
      return MediaType.series;
    }
    if (type.contains(_tvgTypeLive) ||
        type.contains(_tvgTypeChannel) ||
        type.contains(_tvgTypeTv)) {
      return MediaType.channel;
    }
    return MediaType.channel;
  }

  static MediaType? _classifyByUrl(String? streamUrl) {
    if (streamUrl == null || streamUrl.isEmpty) return null;

    final uri = Uri.tryParse(streamUrl);
    if (uri == null || uri.host.isEmpty) return null;

    final segments = uri.pathSegments
        .map(_normalize)
        .whereType<String>()
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);

    if (segments.any(_urlMovieSegments.contains)) {
      return MediaType.movie;
    }
    if (segments.any(_urlSeriesSegments.contains)) {
      return MediaType.series;
    }
    return null;
  }

  static MediaType _classifyByGroup(String? group) {
    final normalized = _normalize(group);
    if (normalized == null || normalized.isEmpty) return MediaType.channel;

    if (_groupMovieKeywords.any(normalized.contains)) {
      return MediaType.movie;
    }
    if (_groupSeriesKeywords.any(normalized.contains)) {
      return MediaType.series;
    }
    return MediaType.channel;
  }

  static String? _normalize(String? value) {
    if (value == null) return null;
    return value
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
