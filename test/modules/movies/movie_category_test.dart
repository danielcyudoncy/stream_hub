import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/movie_category.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/modules/movies/movies_controller.dart';
import 'package:stream_hub/modules/movies/widgets/movie_category_sheet.dart';

class _FakeCatalogRepository implements CatalogRepository {
  final List<MediaItem> items = [];

  @override
  Future<List<MediaItem>> getAllItems() async => List.of(items);

  @override
  Future<List<MediaItem>> topByUpdatedAt(
    MediaType type, {
    String? providerId,
    int limit = 20,
  }) async {
    final filtered = List.of(items.where((item) => item.mediaType == type))
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return filtered.take(limit).toList();
  }

  @override
  Future<List<MediaItem>> topByCreatedAt(
    MediaType type, {
    String? providerId,
    int limit = 20,
  }) async {
    final filtered = List.of(items.where((item) => item.mediaType == type))
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered.take(limit).toList();
  }

  @override
  Future<List<MediaItem>> getByProviderAndType(
    String providerId,
    MediaType type,
  ) async =>
      List.of(items.where(
          (item) => item.mediaType == type && item.providerId == providerId));

  @override
  Future<List<MediaItem>> getByType(MediaType type) async =>
      List.of(items.where((item) => item.mediaType == type));

  @override
  Future<void> upsertItems(List<MediaItem> newItems) async {
    for (final item in newItems) {
      items.removeWhere((i) => i.id == item.id);
      items.add(item);
    }
  }

  @override
  Future<MediaItem?> getItem(String id) async {
    try {
      return items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteItem(String id) async {
    items.removeWhere((i) => i.id == id);
  }

  @override
  Future<void> clear() async => items.clear();

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MovieCategory Model Tests', () {
    test('instantiates with expected properties', () {
      const cat = MovieCategory(
        id: 'action-1',
        name: 'Action & Adventure',
        count: 42,
        icon: Icons.bolt,
      );

      expect(cat.id, 'action-1');
      expect(cat.name, 'Action & Adventure');
      expect(cat.count, 42);
      expect(cat.icon, Icons.bolt);
    });

    test('supports copyWith', () {
      const cat = MovieCategory(id: '1', name: 'Comedy', count: 10);
      final copy = cat.copyWith(count: 15);

      expect(copy.id, '1');
      expect(copy.name, 'Comedy');
      expect(copy.count, 15);
    });

    test('supports equality and hashcode', () {
      const cat1 = MovieCategory(id: '1', name: 'Horror', count: 5);
      const cat2 = MovieCategory(id: '1', name: 'Horror', count: 5);
      const cat3 = MovieCategory(id: '2', name: 'Horror', count: 5);

      expect(cat1, equals(cat2));
      expect(cat1.hashCode, equals(cat2.hashCode));
      expect(cat1, isNot(equals(cat3)));
    });

    test('defaultIconForName maps common genres appropriately', () {
      expect(MovieCategory.defaultIconForName('Action Movies'),
          equals(Icons.bolt_outlined));
      expect(MovieCategory.defaultIconForName('Classic Comedy'),
          equals(Icons.sentiment_very_satisfied_outlined));
      expect(MovieCategory.defaultIconForName('Horror / Suspense'),
          equals(Icons.nightlight_round_outlined));
      expect(MovieCategory.defaultIconForName('Sci-Fi Movies'),
          equals(Icons.rocket_launch_outlined));
      expect(MovieCategory.defaultIconForName('Fantasy Worlds'),
          equals(Icons.auto_awesome_outlined));
      expect(MovieCategory.defaultIconForName('Romance / Love'),
          equals(Icons.favorite_border_outlined));
      expect(MovieCategory.defaultIconForName('Kids & Family'),
          equals(Icons.child_care_outlined));
      expect(MovieCategory.defaultIconForName('Unknown Genre'),
          equals(AppIcons.movies));
    });
  });

  group('MoviesController Categories Computation', () {
    late _FakeCatalogRepository fakeCatalogRepo;
    late _FakeMediaLibrary fakeMediaLibrary;
    late _FakeMediaEngine fakeMediaEngine;
    late MoviesController controller;

    setUp(() {
      Get.testMode = true;
      fakeCatalogRepo = _FakeCatalogRepository();
      fakeMediaLibrary = _FakeMediaLibrary();
      fakeMediaEngine = _FakeMediaEngine();

      controller = MoviesController(
        mediaEngine: fakeMediaEngine,
        mediaLibrary: fakeMediaLibrary,
        catalogRepository: fakeCatalogRepo,
      );
    });

    tearDown(() {
      Get.reset();
    });

    test('computes movie categories from movies and provider collections',
        () async {
      final now = DateTime.now();

      // Add VOD collections
      fakeCatalogRepo.items.addAll([
        MediaItem(
          id: 'xtream-vod-cat-101',
          title: 'Action Movies',
          providerId: 'provider-1',
          providerType: MediaSourceType.xtream,
          mediaType: MediaType.collection,
          metadata: {'categoryId': '101', 'type': 'vod'},
          createdAt: now,
          updatedAt: now,
        ),
        MediaItem(
          id: 'xtream-vod-cat-102',
          title: 'Comedy Movies',
          providerId: 'provider-1',
          providerType: MediaSourceType.xtream,
          mediaType: MediaType.collection,
          metadata: {'categoryId': '102', 'type': 'vod'},
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      // Add movies belonging to these categories
      fakeCatalogRepo.items.addAll([
        MediaItem(
          id: 'movie-1',
          title: 'Die Hard',
          providerId: 'provider-1',
          providerType: MediaSourceType.xtream,
          mediaType: MediaType.movie,
          genres: ['Action'],
          metadata: {
            'categoryId': '101',
            'category_name': 'Action Movies',
            'streamUrl': 'http://example.com/1.mp4',
          },
          createdAt: now,
          updatedAt: now,
        ),
        MediaItem(
          id: 'movie-2',
          title: 'The Hangover',
          providerId: 'provider-1',
          providerType: MediaSourceType.xtream,
          mediaType: MediaType.movie,
          genres: ['Comedy'],
          metadata: {
            'categoryId': '102',
            'category_name': 'Comedy Movies',
            'streamUrl': 'http://example.com/2.mp4',
          },
          createdAt: now,
          updatedAt: now,
        ),
        MediaItem(
          id: 'movie-3',
          title: 'Superbad',
          providerId: 'provider-1',
          providerType: MediaSourceType.xtream,
          mediaType: MediaType.movie,
          genres: ['Comedy'],
          metadata: {
            'categoryId': '102',
            'category_name': 'Comedy Movies',
            'streamUrl': 'http://example.com/3.mp4',
          },
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await controller.reloadMovies();

      expect(controller.movieCategories.isNotEmpty, isTrue);

      // First category should be 'All Movies'
      final allCategory = controller.movieCategories.first;
      expect(allCategory.id, 'all');
      expect(allCategory.name, 'All Movies');
      expect(allCategory.count, 3);

      // Verify category items
      final actionCat = controller.movieCategories
          .firstWhere((c) => c.name.contains('Action'));
      expect(actionCat.count, 1);

      final comedyCat = controller.movieCategories
          .firstWhere((c) => c.name.contains('Comedy'));
      expect(comedyCat.count, 2);
    });
  });

  group('MovieCategorySheet Widget Tests', () {
    testWidgets('renders category list and filters with search',
        (tester) async {
      final categories = [
        const MovieCategory(
            id: 'all', name: 'All Movies', count: 50, icon: Icons.movie),
        const MovieCategory(
            id: '1', name: 'Action', count: 20, icon: Icons.bolt),
        const MovieCategory(
            id: '2', name: 'Comedy', count: 18, icon: Icons.sentiment_very_satisfied),
        const MovieCategory(
            id: '3', name: 'Sci-Fi', count: 12, icon: Icons.rocket_launch),
      ];

      MovieCategory? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MovieCategorySheet(
              categories: categories,
              onSelectCategory: (cat) => selected = cat,
            ),
          ),
        ),
      );

      // Verify all items are displayed
      expect(find.text('All Movies'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
      expect(find.text('Comedy'), findsOneWidget);
      expect(find.text('Sci-Fi'), findsOneWidget);

      // Search for "Action"
      await tester.enterText(find.byType(TextField), 'act');
      await tester.pumpAndSettle();

      expect(find.text('Action'), findsOneWidget);
      expect(find.text('Comedy'), findsNothing);
      expect(find.text('Sci-Fi'), findsNothing);

      // Tap on Action category
      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.name, 'Action');
    });
  });
}
