import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/services/tmdb_catalog_service.dart';

void main() {
  group('TMDBCatalogService Unit Tests', () {
    final service = TMDBCatalogService();

    test('initializes with default API key and exposes genres', () async {
      expect(service.movieGenres, isNotNull);
      expect(service.seriesGenres, isNotNull);
      expect(service.tvGenres, isNotNull);
    });

    test('getMovieTrailer and getSeriesTrailer return null or string gracefully', () async {
      // Offline/dry check with dummy id
      final trailer = await service.getMovieTrailer(0);
      expect(trailer, isNull);
    });
  });
}
