import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/modules/live_tv/controllers/category_controller.dart';

class _FakeCatalogRepository implements CatalogRepository {
  final List<MediaItem> items = [];

  @override
  Future<List<MediaItem>> getAllItems() async => List.of(items);

  @override
  Future<List<MediaItem>> topByUpdatedAt(
    MediaType type, {
    String? providerId,
    int limit = 20,
  }) async => [];

  @override
  Future<List<MediaItem>> topByCreatedAt(
    MediaType type, {
    String? providerId,
    int limit = 20,
  }) async => [];

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
  Future<MediaItem?> getItem(String id) async =>
      items.where((i) => i.id == id).firstOrNull;

  @override
  Future<void> upsertItems(List<MediaItem> newItems) async =>
      items.addAll(newItems);

  @override
  Future<void> deleteItem(String id) async =>
      items.removeWhere((i) => i.id == id);

  @override
  Future<void> clear() async => items.clear();

  @override
  Stream<void> watchUpdates() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeMediaLibrary implements MediaLibrary {
  @override
  List<MediaItem> getLiveTV() => [];
  @override
  List<MediaItem> getMovies() => [];
  @override
  List<MediaItem> getSeries() => [];
  @override
  List<MediaItem> getCollections() => [];
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

  @override
  Stream<List<MediaItem>> get liveTVStream => const Stream.empty();
  @override
  Stream<List<MediaItem>> get moviesStream => const Stream.empty();
  @override
  Stream<List<MediaItem>> get seriesStream => const Stream.empty();
  @override
  Stream<List<MediaItem>> get favoritesStream => const Stream.empty();
  @override
  Stream<List<MediaItem>> get downloadsStream => const Stream.empty();
  @override
  Stream<List<MediaItem>> get historyStream => const Stream.empty();
  @override
  Stream<List<MediaItem>> get recentStream => const Stream.empty();
  @override
  Stream<List<MediaItem>> get recommendedStream => const Stream.empty();
  @override
  Stream<List<MediaItem>> get searchStream => const Stream.empty();
  @override
  Stream<List<MediaItem>> get collectionsStream => const Stream.empty();
}

class _FakeMediaEngine implements MediaEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCatalogRepository catalogRepo;
  late _FakeMediaLibrary mediaLibrary;
  late _FakeMediaEngine mediaEngine;
  late CategoryController controller;

  setUp(() {
    Get.testMode = true;
    catalogRepo = _FakeCatalogRepository();
    mediaLibrary = _FakeMediaLibrary();
    mediaEngine = _FakeMediaEngine();

    controller = CategoryController(
      mediaEngine: mediaEngine,
      mediaLibrary: mediaLibrary,
      catalogRepository: catalogRepo,
    );
  });

  tearDown(() {
    Get.reset();
  });

  test('loads categories extracted from metadata and genres correctly', () async {
    // Add channels with category_name in metadata (like Xtream or M3U)
    catalogRepo.items.addAll([
      MediaItem(
        id: 'ch-1',
        providerId: 'prov-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'Sky Sports Premier League',
        metadata: {'category_name': 'Sports'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      MediaItem(
        id: 'ch-2',
        providerId: 'prov-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'BBC News',
        metadata: {'groupTitle': 'News'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      MediaItem(
        id: 'ch-3',
        providerId: 'prov-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'Discovery Science',
        genres: ['Documentary'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);

    await controller.ensureCategoriesLoaded(force: true);

    expect(controller.categories.length, 3);
    final names = controller.categories.map((c) => c.name).toSet();
    expect(names, containsAll(['Sports', 'News', 'Documentary']));
  });

  test('supports switching media types and populates movie categories', () async {
    catalogRepo.items.addAll([
      MediaItem(
        id: 'ch-1',
        providerId: 'prov-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'Channel 1',
        metadata: {'category_name': 'Live Category'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      MediaItem(
        id: 'mov-1',
        providerId: 'prov-1',
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.movie,
        title: 'Action Movie 1',
        metadata: {'category_name': 'Action'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);

    await controller.ensureCategoriesLoaded(force: true);
    expect(controller.categories.length, 1);
    expect(controller.categories.first.name, 'Live Category');

    // Switch to Movies
    controller.setMediaType(MediaType.movie);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(controller.categories.length, 1);
    expect(controller.categories.first.name, 'Action');
  });

  test('toggles category visibility and bulk actions', () async {
    catalogRepo.items.addAll([
      MediaItem(
        id: 'ch-1',
        providerId: 'p1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'Channel 1',
        metadata: {'category_name': 'Entertainment'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      MediaItem(
        id: 'ch-2',
        providerId: 'p1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'Channel 2',
        metadata: {'category_name': 'Kids'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);

    await controller.ensureCategoriesLoaded(force: true);
    final catId = controller.categories.first.id;

    expect(controller.isCategoryHidden(catId), false);
    expect(controller.visibleCategoriesCount, 2);
    expect(controller.hiddenCategoriesCount, 0);

    // Toggle hide
    controller.toggleCategoryVisibility(catId);
    expect(controller.isCategoryHidden(catId), true);
    expect(controller.visibleCategoriesCount, 1);
    expect(controller.hiddenCategoriesCount, 1);

    // Hide all
    controller.hideAll();
    expect(controller.visibleCategoriesCount, 0);
    expect(controller.hiddenCategoriesCount, 2);

    // Show all
    controller.showAll();
    expect(controller.visibleCategoriesCount, 2);
    expect(controller.hiddenCategoriesCount, 0);
  });

  test('sorts categories by name and item count', () async {
    catalogRepo.items.addAll([
      MediaItem(
        id: 'ch-1',
        providerId: 'p1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'Channel 1',
        metadata: {'category_name': 'Z Category'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      MediaItem(
        id: 'ch-2',
        providerId: 'p1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'Channel 2',
        metadata: {'category_name': 'A Category'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      MediaItem(
        id: 'ch-3',
        providerId: 'p1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'Channel 3',
        metadata: {'category_name': 'A Category'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);

    await controller.ensureCategoriesLoaded(force: true);

    // Default nameAsc
    controller.setSortOption(CategorySortOption.nameAsc);
    expect(controller.filteredCategories.first.name, 'A Category');
    expect(controller.filteredCategories.last.name, 'Z Category');

    // nameDesc
    controller.setSortOption(CategorySortOption.nameDesc);
    expect(controller.filteredCategories.first.name, 'Z Category');
    expect(controller.filteredCategories.last.name, 'A Category');

    // countDesc (A Category has 2 channels, Z has 1)
    controller.setSortOption(CategorySortOption.countDesc);
    expect(controller.filteredCategories.first.name, 'A Category');
    expect(controller.filteredCategories.first.channelCount, 2);
  });
}
