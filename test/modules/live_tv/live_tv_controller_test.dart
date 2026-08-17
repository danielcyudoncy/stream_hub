import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';
import 'package:stream_hub/data/models/channel.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/modules/live_tv/controllers/live_tv_controller.dart';

class _FakeCatalogRepository implements CatalogRepository {
  final List<MediaItem> items = [];

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
  Stream<List<MediaItem>> get liveTVStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get moviesStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get seriesStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get favoritesStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get downloadsStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get historyStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get recentStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get recommendedStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get searchStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get collectionsStream => const Stream<List<MediaItem>>.empty();

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

class _FakeFavoriteRepository implements FavoriteRepository {
  final List<MediaItem> _favorites = [];

  @override
  Future<void> add(MediaItem item) async {
    _favorites.removeWhere((i) => i.id == item.id);
    _favorites.add(item);
  }

  @override
  Future<void> remove(String id) async {
    _favorites.removeWhere((i) => i.id == id);
  }

  @override
  Future<List<MediaItem>> getAll() async => List.of(_favorites);

  @override
  Future<bool> isFavorite(String id) async =>
      _favorites.any((i) => i.id == id);

  @override
  Future<int> get count async => _favorites.length;

  @override
  Future<void> clear() async => _favorites.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCatalogRepository catalogRepo;
  late _FakeMediaEngine mediaEngine;
  late _FakeMediaLibrary mediaLibrary;
  late _FakeFavoriteRepository favoriteRepo;
  late LiveTVController controller;

  final testChannel1 = Channel(
    id: 'ch-1',
    providerId: 'prov-1',
    providerType: MediaSourceType.m3u,
    title: 'Sky Sports Premier League',
    mediaType: MediaType.channel,
    number: '101',
    isLive: true,
    genres: const ['Sports', 'Football'],
    metadata: const {'resolution': 'HD'},
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );

  final testChannel2 = Channel(
    id: 'ch-2',
    providerId: 'prov-1',
    providerType: MediaSourceType.m3u,
    title: 'BBC News HD',
    mediaType: MediaType.channel,
    number: '102',
    isLive: true,
    genres: const ['News'],
    metadata: const {'resolution': 'FHD'},
    createdAt: DateTime(2025, 1, 2),
    updatedAt: DateTime(2025, 1, 2),
  );

  setUp(() {
    Get.reset();
    catalogRepo = _FakeCatalogRepository();
    mediaEngine = _FakeMediaEngine();
    mediaLibrary = _FakeMediaLibrary();
    favoriteRepo = _FakeFavoriteRepository();

    catalogRepo.items.addAll([testChannel1, testChannel2]);

    controller = LiveTVController(
      mediaEngine: mediaEngine,
      mediaLibrary: mediaLibrary,
      catalogRepository: catalogRepo,
      favoriteRepository: favoriteRepo,
    );
  });

  tearDown(() {
    Get.reset();
  });

  test('loads channels and sets featured channel on initialization', () async {
    controller.onInit();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(controller.channels.length, 2);
    expect(controller.filteredChannels.length, 2);
    expect(controller.featuredChannel.value, isNotNull);
    expect(controller.featuredChannel.value?.id, 'ch-1');
  });

  test('filters channels by category', () async {
    controller.onInit();
    await Future.delayed(const Duration(milliseconds: 50));

    controller.setCategory('News');
    expect(controller.filteredChannels.length, 1);
    expect(controller.filteredChannels.first.title, 'BBC News HD');

    controller.setCategory('All Channels');
    expect(controller.filteredChannels.length, 2);
  });

  test('filters channels by search query matching title or number', () async {
    controller.onInit();
    await Future.delayed(const Duration(milliseconds: 50));

    controller.setSearchQuery('BBC');
    expect(controller.filteredChannels.length, 1);
    expect(controller.filteredChannels.first.title, 'BBC News HD');

    controller.setSearchQuery('101');
    expect(controller.filteredChannels.length, 1);
    expect(controller.filteredChannels.first.title, 'Sky Sports Premier League');

    controller.setSearchQuery('Sports');
    expect(controller.filteredChannels.length, 1);

    controller.setSearchQuery('');
    expect(controller.filteredChannels.length, 2);
  });

  test('toggles favorite and filters favorites only', () async {
    controller.onInit();
    await Future.delayed(const Duration(milliseconds: 50));

    await controller.toggleFavorite(testChannel1);
    expect(controller.favorites.any((f) => f.id == 'ch-1'), isTrue);

    controller.setFavoritesOnly(true);
    expect(controller.filteredChannels.length, 1);
    expect(controller.filteredChannels.first.id, 'ch-1');

    controller.setFavoritesOnly(false);
    expect(controller.filteredChannels.length, 2);
  });

  test('switches view mode between grid and list', () {
    expect(controller.selectedView.value, 'grid');
    controller.setView('list');
    expect(controller.selectedView.value, 'list');
    controller.setView('grid');
    expect(controller.selectedView.value, 'grid');
  });
}
