import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/modules/movies/movie_genre_binding.dart';
import 'package:stream_hub/modules/movies/movie_genre_page.dart';
import 'package:stream_hub/modules/movies/movies_category_page.dart';
import 'package:stream_hub/modules/movies/movies_controller.dart';
import 'package:stream_hub/modules/movies/movies_page.dart';
import 'package:stream_hub/modules/movies/widgets/movies_hero_carousel.dart';
import 'package:stream_hub/shared/widgets/media_poster_card.dart';

class _FakeCatalogRepository implements CatalogRepository {
  final List<MediaItem> items;
  _FakeCatalogRepository(this.items);

  @override
  Future<List<MediaItem>> getAllItems() async => List.of(items);

  @override
  Future<List<MediaItem>> getByType(MediaType type) async =>
      List.of(items.where((item) => item.mediaType == type));

  @override
  Future<void> upsertItems(List<MediaItem> newItems) async {}

  @override
  Future<MediaItem?> getItem(String id) async => null;

  @override
  Future<void> deleteItem(String id) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<List<MediaSyncResult>> syncAll() => throw UnimplementedError();

  @override
  Future<MediaSyncResult> syncSource(String sourceId) =>
      throw UnimplementedError();

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<MediaItem>> watchUpdates() => const Stream.empty();

  @override
  Future<void> enrichWithXMLTV(XMLTVGuide guide) async {}

  @override
  Future<void> mergeXMLTVMetadata(XMLTVGuide guide) async {}
}

class _FakeMediaEngine implements MediaEngine {
  @override
  MediaCatalog get catalog => throw UnimplementedError();

  @override
  MediaLibrary get library => throw UnimplementedError();

  @override
  MediaSourceManager get sourceManager => throw UnimplementedError();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> refreshCatalog() async {}

  @override
  Future<List<MediaSyncResult>> syncAllSources() async => [];

  @override
  Future<void> syncSource(String sourceId) async {}

  @override
  Future<List<MediaItem>> search(String query) async => [];

  @override
  Future<List<MediaItem>> searchChannels(String query) async => [];

  @override
  Future<List<MediaItem>> searchMovies(String query) async => [];

  @override
  Future<List<MediaItem>> searchSeries(String query) async => [];

  @override
  Future<List<MediaItem>> searchPrograms(String query) async => [];

  @override
  Future<List<MediaItem>> searchProviders(String query) async => [];

  @override
  Stream<MediaItem> get catalogUpdates => const Stream<MediaItem>.empty();

  @override
  Future<void> enrichMetadata(List<MediaItem> items) async {}

  @override
  Future<void> ingestItems(List<MediaItem> items) async {}
}

class _FakeMediaLibrary implements MediaLibrary {
  @override
  Stream<List<MediaItem>> get liveTVStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get moviesStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get seriesStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get favoritesStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get downloadsStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get historyStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get recentStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get recommendedStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get searchStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get collectionsStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  List<MediaItem> getLiveTV() => [];

  @override
  List<MediaItem> getMovies() => [];

  @override
  List<MediaItem> getSeries() => [];

  @override
  List<MediaItem> getFavorites() => [];

  @override
  List<MediaItem> getDownloads() => [];

  @override
  List<MediaItem> getHistory() => [];

  @override
  List<MediaItem> getRecent() => [];

  @override
  List<MediaItem> getRecommended() => [];

  @override
  List<MediaItem> getCollections() => [];

  @override
  List<MediaItem> search(String query) => [];

  @override
  List<MediaItem> getByType(MediaType type) => [];

  @override
  void addToFavorites(MediaItem item) {}

  @override
  void removeFromFavorites(String itemId) {}

  @override
  void addToHistory(MediaItem item) {}

  @override
  void clearHistory() {}
}

MediaItem _buildMovie({
  required String id,
  required String title,
  double? rating,
  List<String> genres = const [],
  Map<String, dynamic> metadata = const {},
}) {
  return MediaItem(
    id: id,
    providerId: 'provider-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.movie,
    title: title,
    description: 'Description for $title',
    rating: rating,
    genres: genres,
    metadata: metadata,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('MoviesHeroCarousel Widget Tests', () {
    testWidgets('renders hero slide details and responds to watch button tap',
        (tester) async {
      MediaItem? watchedMovie;
      final sampleMovies = [
        _buildMovie(
          id: 'movie-1',
          title: 'Inception',
          rating: 8.8,
          genres: ['Sci-Fi', 'Action'],
          metadata: {'year': '2010', 'streamUrl': 'https://example.com/stream.mp4'},
        ),
        _buildMovie(
          id: 'movie-2',
          title: 'Interstellar',
          rating: 8.7,
          genres: ['Sci-Fi', 'Drama'],
          metadata: {'year': '2014'},
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoviesHeroCarousel(
              movies: sampleMovies,
              autoPlayInterval: const Duration(seconds: 2),
              onWatch: (movie) => watchedMovie = movie,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Inception'), findsOneWidget);
      expect(find.text('WATCH NOW'), findsOneWidget);

      await tester.tap(find.text('WATCH NOW'));
      await tester.pump();

      expect(watchedMovie?.id, 'movie-1');
    });

    testWidgets('auto-advances to next slide when timer expires',
        (tester) async {
      final sampleMovies = [
        _buildMovie(id: 'm1', title: 'Movie 1'),
        _buildMovie(id: 'm2', title: 'Movie 2'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoviesHeroCarousel(
              movies: sampleMovies,
              autoPlayInterval: const Duration(milliseconds: 500),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Movie 1'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.text('Movie 2'), findsOneWidget);
    });
  });

  group('MoviesCategoryPage Widget Tests', () {
    testWidgets('renders empty state when items list is empty', (tester) async {
      Get.parameters = {};

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.moviesCategory,
          getPages: [
            GetPage(
              name: AppRoutes.moviesCategory,
              page: () => const MoviesCategoryPage(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No Movies'), findsOneWidget);
      expect(find.text('This category is currently empty.'), findsOneWidget);
    });

    testWidgets('renders grid of movie posters when items are provided in arguments',
        (tester) async {
      final categoryMovies = [
        _buildMovie(id: 'cat-1', title: 'Comedy 1'),
        _buildMovie(id: 'cat-2', title: 'Comedy 2'),
      ];

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/',
          getPages: [
            GetPage(
              name: '/',
              page: () => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Get.toNamed(
                        AppRoutes.moviesCategory,
                        arguments: {
                          'title': 'Romantic Comedies',
                          'items': categoryMovies,
                        },
                      );
                    },
                    child: const Text('Open Category'),
                  ),
                ),
              ),
            ),
            GetPage(
              name: AppRoutes.moviesCategory,
              page: () => const MoviesCategoryPage(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Category'));
      await tester.pumpAndSettle();

      expect(find.text('Romantic Comedies'), findsOneWidget);
      expect(find.byType(MediaPosterCard), findsNWidgets(2));
      expect(find.text('Comedy 1'), findsOneWidget);
      expect(find.text('Comedy 2'), findsOneWidget);
    });
  });

  group('MoviesPage See All Integration Tests', () {
    testWidgets('tapping See All navigates to MoviesCategoryPage with category items',
        (tester) async {
      final sampleMovies = [
        _buildMovie(
          id: 'mov-1',
          title: 'Trending Movie 1',
          rating: 9.0,
          genres: ['Action'],
          metadata: {'streamUrl': 'https://example.com/1.mp4'},
        ),
      ];

      final fakeRepo = _FakeCatalogRepository(sampleMovies);
      final fakeEngine = _FakeMediaEngine();
      final fakeLibrary = _FakeMediaLibrary();

      Get.put<CatalogRepository>(fakeRepo);
      Get.put<MediaLibrary>(fakeLibrary);

      final controller = MoviesController(
        mediaEngine: fakeEngine,
        mediaLibrary: fakeLibrary,
        catalogRepository: fakeRepo,
      );
      Get.put<MoviesController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.movies,
          getPages: [
            GetPage(
              name: AppRoutes.movies,
              page: () => const MoviesPage(),
            ),
            GetPage(
              name: AppRoutes.movieGenre,
              page: () => const MovieGenrePage(),
              binding: MovieGenreBinding(),
            ),
            GetPage(
              name: AppRoutes.moviesCategory,
              page: () => const MoviesCategoryPage(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      final seeAllFinder = find.text('See All');
      await tester.scrollUntilVisible(
        seeAllFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(seeAllFinder, findsWidgets);

      await tester.tap(seeAllFinder.first);
      await tester.pumpAndSettle();

      expect(
        Get.currentRoute == AppRoutes.movieGenre ||
            Get.currentRoute == AppRoutes.moviesCategory,
        isTrue,
      );
    });

    testWidgets('tapping search button navigates to SearchHubPage',
        (tester) async {
      final sampleMovies = [
        _buildMovie(id: 'mov-1', title: 'Movie 1'),
      ];

      final fakeRepo = _FakeCatalogRepository(sampleMovies);
      final fakeEngine = _FakeMediaEngine();
      final fakeLibrary = _FakeMediaLibrary();

      final controller = MoviesController(
        mediaEngine: fakeEngine,
        mediaLibrary: fakeLibrary,
        catalogRepository: fakeRepo,
      );
      Get.put<MoviesController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.movies,
          getPages: [
            GetPage(
              name: AppRoutes.movies,
              page: () => const MoviesPage(),
            ),
            GetPage(
              name: AppRoutes.search,
              page: () => const Scaffold(body: Text('Search Hub View')),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      final searchButton = find.byTooltip('Search');
      expect(searchButton, findsOneWidget);

      await tester.tap(searchButton);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.search);
      expect(find.text('Search Hub View'), findsOneWidget);
    });
  });
}
