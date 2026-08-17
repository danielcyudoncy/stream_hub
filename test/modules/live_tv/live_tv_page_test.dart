import 'package:flutter/material.dart';
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
import 'package:stream_hub/modules/live_tv/pages/live_tv_page.dart';
import 'package:stream_hub/modules/live_tv/widgets/live_tv_category_bar.dart';
import 'package:stream_hub/modules/live_tv/widgets/live_tv_channel_card.dart';
import 'package:stream_hub/modules/live_tv/widgets/live_tv_hero_card.dart';
import 'package:stream_hub/modules/live_tv/widgets/live_tv_search_bar.dart';

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
  Stream<void> watchUpdates() => const Stream.empty();

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

  final testChannel1 = Channel(
    id: 'ch-1',
    providerId: 'prov-1',
    providerType: MediaSourceType.m3u,
    title: 'Sky Sports Premier League',
    mediaType: MediaType.channel,
    number: '101',
    isLive: true,
    genres: const ['Sports'],
    metadata: const {'resolution': 'HD'},
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );

  final testChannel2 = Channel(
    id: 'ch-2',
    providerId: 'prov-1',
    providerType: MediaSourceType.m3u,
    title: 'BBC One News',
    mediaType: MediaType.channel,
    number: '102',
    isLive: true,
    genres: const ['News'],
    metadata: const {'resolution': 'FHD'},
    createdAt: DateTime(2025, 1, 2),
    updatedAt: DateTime(2025, 1, 2),
  );

  Widget createSubject({List<MediaItem>? items}) {
    Get.reset();
    final catalogRepo = _FakeCatalogRepository(items ?? [testChannel1, testChannel2]);
    final mediaEngine = _FakeMediaEngine();
    final mediaLibrary = _FakeMediaLibrary();
    final favoriteRepo = _FakeFavoriteRepository();

    final controller = LiveTVController(
      mediaEngine: mediaEngine,
      mediaLibrary: mediaLibrary,
      catalogRepository: catalogRepo,
      favoriteRepository: favoriteRepo,
    );
    Get.put<LiveTVController>(controller);

    return GetMaterialApp(
      theme: ThemeData.dark(),
      home: const LiveTVPage(),
    );
  }

  tearDown(() {
    Get.reset();
  });

  testWidgets('renders redesigned LiveTVPage with hero card, search, categories, and channels', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('Live TV'), findsWidgets);
    expect(find.byType(LiveTvHeroCard), findsOneWidget);
    expect(find.byType(LiveTvSearchBar), findsOneWidget);
    expect(find.byType(LiveTvCategoryBar), findsOneWidget);
    expect(find.byType(LiveTvChannelCard), findsWidgets);
    expect(find.text('Sky Sports Premier League'), findsWidgets);
    expect(find.text('BBC One News'), findsWidgets);
  });

  testWidgets('searches and filters channels via LiveTvSearchBar', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Enter search query
    await tester.enterText(find.byType(TextField), 'BBC');
    await tester.pumpAndSettle();

    expect(find.text('BBC One News'), findsWidgets);
    expect(find.text('1 channels'), findsOneWidget);
  });

  testWidgets('toggles between grid and list views', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Toggle view to list
    final viewToggleFinder = find.byTooltip('Switch to List View');
    expect(viewToggleFinder, findsOneWidget);
    await tester.tap(viewToggleFinder);
    await tester.pumpAndSettle();

    // Now it should show tooltip to switch to grid
    expect(find.byTooltip('Switch to Grid View'), findsOneWidget);
  });

  testWidgets('displays empty state when no channels match filter', (tester) async {
    await tester.pumpWidget(createSubject(items: []));
    await tester.pumpAndSettle();

    expect(find.text('No Channels in This Category'), findsOneWidget);
  });

  testWidgets('renders list tile with long genre text without RenderFlex overflow', (tester) async {
    final longGenreChannel = Channel(
      id: 'ch-long',
      providerId: 'prov-1',
      providerType: MediaSourceType.m3u,
      title: 'Very Long Channel Title That Should Be Ellipsized In Mobile Views',
      mediaType: MediaType.channel,
      number: '999',
      isLive: true,
      genres: const ['UK - Documentaries and Entertainment Live Stream', 'HD Cinema Plus Ultra'],
      metadata: const {'resolution': '4K UHD'},
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    // Set narrow surface size
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createSubject(items: [longGenreChannel]));
    await tester.pumpAndSettle();

    // Switch to List View
    final viewToggleFinder = find.byTooltip('Switch to List View');
    await tester.tap(viewToggleFinder);
    await tester.pumpAndSettle();

    expect(find.byType(LiveTvChannelCard), findsWidgets);
  });
}
