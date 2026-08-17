import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/modules/search/search_hub_controller.dart';
import 'package:stream_hub/modules/search/search_hub_page.dart';
import 'package:stream_hub/shared/widgets/media_poster_card.dart';

class _FakeCatalogRepository implements CatalogRepository {
  final List<MediaItem> items;

  _FakeCatalogRepository(this.items);

  @override
  Future<List<MediaItem>> getAllItems() async => items;

  @override
  Future<List<MediaItem>> getByType(MediaType type) async =>
      items.where((i) => i.mediaType == type).toList();

  @override
  Future<MediaItem?> getItem(String id) async {
    try {
      return items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsertItems(List<MediaItem> items) async {}
  @override
  Future<void> deleteItem(String id) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<List<MediaSyncResult>> syncAll() async => [];
  @override
  Future<MediaSyncResult> syncSource(String sourceId) async => MediaSyncResult(
        sourceId: sourceId,
        success: true,
        completedAt: DateTime.now(),
      );
  @override
  Future<void> refresh() async {}
  @override
  Stream<List<MediaItem>> watchUpdates() => const Stream.empty();
  @override
  Future<void> enrichWithXMLTV(XMLTVGuide guide) async {}
  @override
  Future<void> mergeXMLTVMetadata(XMLTVGuide guide) async {}
}

MediaItem _buildItem({
  required String id,
  required String title,
  required MediaType mediaType,
  List<String> genres = const [],
  String? description,
}) {
  return MediaItem(
    id: id,
    providerId: 'provider-1',
    providerType: MediaSourceType.xtream,
    mediaType: mediaType,
    title: title,
    description: description,
    genres: genres,
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

  final sampleItems = [
    _buildItem(
      id: 'movie-1',
      title: 'Inception',
      mediaType: MediaType.movie,
      genres: ['Sci-Fi', 'Action'],
      description: 'A thief who steals corporate secrets through dream-sharing tech.',
    ),
    _buildItem(
      id: 'movie-2',
      title: 'Interstellar',
      mediaType: MediaType.movie,
      genres: ['Sci-Fi', 'Drama'],
    ),
    _buildItem(
      id: 'series-1',
      title: 'Breaking Bad',
      mediaType: MediaType.series,
      genres: ['Crime', 'Drama'],
      description: 'A chemistry teacher turned manufacturer.',
    ),
    _buildItem(
      id: 'channel-1',
      title: 'Action News HD',
      mediaType: MediaType.channel,
      genres: ['News'],
    ),
  ];

  group('SearchHubController Unit Tests', () {
    test('initializes with default data and empty results', () {
      final fakeRepo = _FakeCatalogRepository(sampleItems);
      final controller = SearchHubController(catalogRepository: fakeRepo);
      controller.onInit();

      expect(controller.searchQuery.value, isEmpty);
      expect(controller.isLoading.value, isFalse);
      expect(controller.trendingSearches, isNotEmpty);
      expect(controller.suggestions, isNotEmpty);
      expect(controller.allResults, isEmpty);
    });

    test('performs search matching title and splits by media types', () async {
      final fakeRepo = _FakeCatalogRepository(sampleItems);
      final controller = SearchHubController(catalogRepository: fakeRepo);

      await controller.performSearch('Inception');

      expect(controller.allResults.length, 1);
      expect(controller.allResults.first.title, 'Inception');
      expect(controller.movieResults.length, 1);
      expect(controller.seriesResults, isEmpty);
      expect(controller.channelResults, isEmpty);
    });

    test('performs search matching genres and descriptions', () async {
      final fakeRepo = _FakeCatalogRepository(sampleItems);
      final controller = SearchHubController(catalogRepository: fakeRepo);

      await controller.performSearch('Sci-Fi');

      expect(controller.allResults.length, 2);
      expect(controller.movieResults.length, 2);

      await controller.performSearch('chemistry');
      expect(controller.seriesResults.length, 1);
      expect(controller.seriesResults.first.title, 'Breaking Bad');
    });

    test('filters results using selectedFilter', () async {
      final fakeRepo = _FakeCatalogRepository(sampleItems);
      final controller = SearchHubController(catalogRepository: fakeRepo);

      await controller.performSearch('a'); // Matches Inception, Breaking Bad, Action News HD

      controller.setFilter('All');
      expect(controller.displayedResults.length, controller.allResults.length);

      controller.setFilter('Movies');
      expect(controller.displayedResults.length, controller.movieResults.length);

      controller.setFilter('Series');
      expect(controller.displayedResults.length, controller.seriesResults.length);

      controller.setFilter('Live TV');
      expect(controller.displayedResults.length, controller.channelResults.length);
    });

    test('clears search properly', () async {
      final fakeRepo = _FakeCatalogRepository(sampleItems);
      final controller = SearchHubController(catalogRepository: fakeRepo);

      await controller.performSearch('Inception');
      expect(controller.allResults, isNotEmpty);

      controller.clearSearch();
      expect(controller.searchQuery.value, isEmpty);
      expect(controller.allResults, isEmpty);
    });
  });

  group('SearchHubPage Widget Tests', () {
    testWidgets('renders search input bar and trending chips', (tester) async {
      final fakeRepo = _FakeCatalogRepository(sampleItems);
      final controller = SearchHubController(catalogRepository: fakeRepo);
      Get.put<SearchHubController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.search,
          getPages: [
            GetPage(
              name: AppRoutes.search,
              page: () => const SearchHubPage(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search movies, series, channels...'), findsOneWidget);
      expect(find.text('Trending Categories'), findsOneWidget);
      expect(find.text('Suggestions'), findsOneWidget);
    });

    testWidgets('typing in search bar triggers live search and shows poster cards',
        (tester) async {
      final fakeRepo = _FakeCatalogRepository(sampleItems);
      final controller = SearchHubController(catalogRepository: fakeRepo);
      Get.put<SearchHubController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.search,
          getPages: [
            GetPage(
              name: AppRoutes.search,
              page: () => const SearchHubPage(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Inception');
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(find.byType(MediaPosterCard), findsOneWidget);
      expect(find.text('Inception'), findsWidgets);
    });

    testWidgets(
        'clearing search query restores initial suggestions and empty state',
        (tester) async {
      final fakeRepo = _FakeCatalogRepository(sampleItems);
      final controller = SearchHubController(catalogRepository: fakeRepo);
      Get.put<SearchHubController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.search,
          getPages: [
            GetPage(
              name: AppRoutes.search,
              page: () => const SearchHubPage(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      controller.selectQuery('Inception');
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(find.byType(MediaPosterCard), findsOneWidget);
      expect(find.text('Inception'), findsWidgets);

      controller.clearSearch();
      await tester.pumpAndSettle();

      expect(controller.searchQuery.value, isEmpty);
      expect(find.text('Suggestions'), findsOneWidget);
    });
  });
}
