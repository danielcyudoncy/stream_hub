import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';
import 'package:stream_hub/core/utils/image_url_formatter.dart';
import 'package:stream_hub/data/models/media_item.dart';

class TMDBCatalogService {
  static const String defaultApiKey = '7495624011526a75f94bab7b23149630';
  static const String baseUrl = 'https://api.themoviedb.org/3';

  final String apiKey;
  final HttpClient _client;
  final LoggingService _logger;

  // In-memory cache for fast lookups (key -> CachedResponse)
  final Map<String, _CachedEntry> _memoryCache = {};
  static const Duration _cacheTtl = Duration(hours: 12);

  // Genre map for ID -> Name conversion
  final Map<int, String> _movieGenres = {};
  final Map<int, String> _seriesGenres = {};

  TMDBCatalogService({
    String? apiKey,
    HttpClient? client,
    LoggingService? logger,
  })  : apiKey = apiKey ?? defaultApiKey,
        _client = client ?? createDohAwareHttpClient(),
        _logger = logger ?? LoggingService();

  Future<Map<String, dynamic>?> _get(String path, [Map<String, String>? queryParams]) async {
    final params = Map<String, String>.from(queryParams ?? {});
    params['api_key'] = apiKey;

    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);
    final cacheKey = uri.toString();

    final cached = _memoryCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    try {
      final request = await _client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        _memoryCache[cacheKey] = _CachedEntry(json, DateTime.now().add(_cacheTtl));
        return json;
      } else {
        _logger.warning('TMDB API returned HTTP ${response.statusCode} for $path', tag: 'TMDBCatalogService');
      }
    } catch (e) {
      _logger.error('TMDB API request failed for $path', tag: 'TMDBCatalogService', error: e);
    }
    return cached?.data;
  }

  // Ensure genre mapping is loaded
  Future<void> initGenres() async {
    if (_movieGenres.isNotEmpty && _seriesGenres.isNotEmpty) return;

    final movieGenreRes = await _get('/genre/movie/list');
    if (movieGenreRes != null && movieGenreRes['genres'] is List) {
      for (final g in movieGenreRes['genres'] as List) {
        if (g is Map && g['id'] != null && g['name'] != null) {
          _movieGenres[g['id'] as int] = g['name'].toString();
        }
      }
    }

    final seriesGenreRes = await _get('/genre/tv/list');
    if (seriesGenreRes != null && seriesGenreRes['genres'] is List) {
      for (final g in seriesGenreRes['genres'] as List) {
        if (g is Map && g['id'] != null && g['name'] != null) {
          _seriesGenres[g['id'] as int] = g['name'].toString();
        }
      }
    }
  }

  // Movies
  Future<List<MediaItem>> getTrendingMovies({int page = 1}) async {
    await initGenres();
    final data = await _get('/trending/movie/week', {'page': page.toString()});
    return _parseMovies(data);
  }

  Future<List<MediaItem>> getTopRatedMovies({int page = 1}) async {
    await initGenres();
    final data = await _get('/movie/top_rated', {'page': page.toString()});
    return _parseMovies(data);
  }

  Future<List<MediaItem>> getPopularMovies({int page = 1}) async {
    await initGenres();
    final data = await _get('/movie/popular', {'page': page.toString()});
    return _parseMovies(data);
  }

  Future<List<MediaItem>> getMoviesByGenre(int genreId, {int page = 1}) async {
    await initGenres();
    final data = await _get('/discover/movie', {
      'with_genres': genreId.toString(),
      'sort_by': 'popularity.desc',
      'page': page.toString(),
    });
    return _parseMovies(data);
  }

  Map<int, String> get movieGenres => Map.unmodifiable(_movieGenres);

  // Series
  Future<List<MediaItem>> getTrendingSeries({int page = 1}) async {
    await initGenres();
    final data = await _get('/trending/tv/week', {'page': page.toString()});
    return _parseSeries(data);
  }

  Future<List<MediaItem>> getTopRatedSeries({int page = 1}) async {
    await initGenres();
    final data = await _get('/tv/top_rated', {'page': page.toString()});
    return _parseSeries(data);
  }

  Future<List<MediaItem>> getPopularSeries({int page = 1}) async {
    await initGenres();
    final data = await _get('/tv/popular', {'page': page.toString()});
    return _parseSeries(data);
  }

  Future<List<MediaItem>> getSeriesByGenre(int genreId, {int page = 1}) async {
    await initGenres();
    final data = await _get('/discover/tv', {
      'with_genres': genreId.toString(),
      'sort_by': 'popularity.desc',
      'page': page.toString(),
    });
    return _parseSeries(data);
  }

  Map<int, String> get seriesGenres => Map.unmodifiable(_seriesGenres);
  Map<int, String> get tvGenres => seriesGenres;

  // Trailer URL resolution
  Future<String?> getMovieTrailer(int tmdbId) => getTrailerUrl(tmdbId, isSeries: false);
  Future<String?> getSeriesTrailer(int tmdbId) => getTrailerUrl(tmdbId, isSeries: true);

  Future<String?> getTrailerUrl(int tmdbId, {bool isSeries = false}) async {
    final endpoint = isSeries ? '/tv/$tmdbId/videos' : '/movie/$tmdbId/videos';
    final data = await _get(endpoint);
    if (data == null || data['results'] is! List) return null;

    final results = data['results'] as List;
    // Look for Official YouTube Trailer
    for (final v in results) {
      if (v is Map && v['site'] == 'YouTube' && v['type'] == 'Trailer') {
        final key = v['key']?.toString();
        if (key != null && key.isNotEmpty) {
          return 'https://www.youtube.com/watch?v=$key';
        }
      }
    }
    // Fallback to any YouTube video (Teaser / Clip)
    for (final v in results) {
      if (v is Map && v['site'] == 'YouTube') {
        final key = v['key']?.toString();
        if (key != null && key.isNotEmpty) {
          return 'https://www.youtube.com/watch?v=$key';
        }
      }
    }
    return null;
  }

  // Parsing helpers
  List<MediaItem> _parseMovies(Map<String, dynamic>? data) {
    if (data == null || data['results'] is! List) return [];
    final list = <MediaItem>[];
    final now = DateTime.now();
    for (final item in data['results'] as List) {
      if (item is Map) {
        final id = item['id'] as int?;
        final title = (item['title'] ?? item['original_title'])?.toString();
        if (id == null || title == null || title.isEmpty) continue;

        final posterPath = item['poster_path']?.toString();
        final backdropPath = item['backdrop_path']?.toString();
        final posterUrl = posterPath != null ? ImageUrlFormatter.format(posterPath) : null;
        final backdropUrl = backdropPath != null ? ImageUrlFormatter.format(backdropPath) : null;

        final genreIds = (item['genre_ids'] as List?)?.map((g) => g as int).toList() ?? [];
        final genres = genreIds.map((id) => _movieGenres[id]).whereType<String>().toList();

        final releaseDate = item['release_date']?.toString() ?? '';
        final year = releaseDate.length >= 4 ? int.tryParse(releaseDate.substring(0, 4)) : null;
        final rating = (item['vote_average'] as num?)?.toDouble();

        list.add(
          MediaItem(
            id: 'tmdb-movie-$id',
            providerId: 'tmdb',
            providerType: MediaSourceType.custom,
            mediaType: MediaType.movie,
            title: title,
            description: item['overview']?.toString(),
            poster: posterUrl,
            thumbnail: posterUrl,
            backdrop: backdropUrl,
            genres: genres,
            rating: rating,
            createdAt: now,
            updatedAt: now,
            metadata: {
              'tmdbId': id,
              'year': year,
              'releaseDate': releaseDate,
              'originalLanguage': item['original_language']?.toString() ?? '',
              'popularity': item['popularity'],
              'voteCount': item['vote_count'],
              'isTmdbDiscovery': true,
            },
          ),
        );
      }
    }
    return list;
  }

  List<MediaItem> _parseSeries(Map<String, dynamic>? data) {
    if (data == null || data['results'] is! List) return [];
    final list = <MediaItem>[];
    final now = DateTime.now();
    for (final item in data['results'] as List) {
      if (item is Map) {
        final id = item['id'] as int?;
        final title = (item['name'] ?? item['original_name'])?.toString();
        if (id == null || title == null || title.isEmpty) continue;

        final posterPath = item['poster_path']?.toString();
        final backdropPath = item['backdrop_path']?.toString();
        final posterUrl = posterPath != null ? ImageUrlFormatter.format(posterPath) : null;
        final backdropUrl = backdropPath != null ? ImageUrlFormatter.format(backdropPath) : null;

        final genreIds = (item['genre_ids'] as List?)?.map((g) => g as int).toList() ?? [];
        final genres = genreIds.map((id) => _seriesGenres[id]).whereType<String>().toList();

        final firstAirDate = item['first_air_date']?.toString() ?? '';
        final year = firstAirDate.length >= 4 ? int.tryParse(firstAirDate.substring(0, 4)) : null;
        final rating = (item['vote_average'] as num?)?.toDouble();

        list.add(
          MediaItem(
            id: 'tmdb-series-$id',
            providerId: 'tmdb',
            providerType: MediaSourceType.custom,
            mediaType: MediaType.series,
            title: title,
            description: item['overview']?.toString(),
            poster: posterUrl,
            thumbnail: posterUrl,
            backdrop: backdropUrl,
            genres: genres,
            rating: rating,
            createdAt: now,
            updatedAt: now,
            metadata: {
              'tmdbId': id,
              'year': year,
              'releaseDate': firstAirDate,
              'originalLanguage': item['original_language']?.toString() ?? '',
              'popularity': item['popularity'],
              'voteCount': item['vote_count'],
              'isTmdbDiscovery': true,
            },
          ),
        );
      }
    }
    return list;
  }
}

class _CachedEntry {
  final Map<String, dynamic> data;
  final DateTime expiry;

  _CachedEntry(this.data, this.expiry);

  bool get isExpired => DateTime.now().isAfter(expiry);
}
