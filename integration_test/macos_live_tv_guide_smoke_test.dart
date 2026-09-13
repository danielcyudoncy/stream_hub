import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' as mk;
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
import 'package:stream_hub/modules/live_tv/widgets/live_tv_embedded_player.dart';

class _FakeCatalogRepository implements CatalogRepository {
  final List<MediaItem> items;
  _FakeCatalogRepository(this.items);

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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('macOS renders responsive desktop Live TV and channel cards on device', (tester) async {
    mk.MediaKit.ensureInitialized();

    final channel1 = Channel(
      id: 'macos-ch-1',
      providerId: 'prov-macos',
      providerType: MediaSourceType.m3u,
      title: 'macOS Premier Channel',
      mediaType: MediaType.channel,
      number: '101',
      isLive: true,
      genres: const ['Sports'],
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    final channel2 = Channel(
      id: 'macos-ch-2',
      providerId: 'prov-macos',
      providerType: MediaSourceType.m3u,
      title: 'macOS Global News',
      mediaType: MediaType.channel,
      number: '102',
      isLive: true,
      genres: const ['News'],
      createdAt: DateTime(2025, 1, 2),
      updatedAt: DateTime(2025, 1, 2),
    );

    Get.reset();
    final catalogRepo = _FakeCatalogRepository([channel1, channel2]);
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

    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData.dark(),
        home: const LiveTVPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify on real macOS target:
    // 1. Embedded player renders
    expect(find.byType(LiveTvEmbeddedPlayer), findsOneWidget);
    // 2. Category bar renders
    expect(find.byType(LiveTvCategoryBar), findsOneWidget);
    // 3. Channel cards render
    expect(find.byType(LiveTvChannelCard), findsWidgets);
    // 4. EPG TV Guide toggle is present in desktop app bar
    expect(find.byTooltip('EPG TV Guide'), findsOneWidget);
  });
}
