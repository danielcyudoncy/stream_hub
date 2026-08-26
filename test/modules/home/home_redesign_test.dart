import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_state.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/events/media_event_bus.dart';
import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/media_source.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';
import 'package:stream_hub/data/models/media_health.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_statistics.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/data/repositories/history_repository.dart';
import 'package:stream_hub/data/repositories/media_source_repository.dart';
import 'package:stream_hub/data/models/home_snapshot.dart';
import 'package:stream_hub/data/services/home_snapshot_service.dart';
import 'package:stream_hub/modules/home/home_controller.dart';
import 'package:stream_hub/modules/home/home_page.dart';
import 'package:stream_hub/modules/home/widgets/home_header.dart';
import 'package:stream_hub/modules/home/widgets/home_hero_carousel.dart';
import 'package:stream_hub/modules/home/widgets/home_quick_actions.dart';
import 'package:stream_hub/modules/home/widgets/home_skeleton_loader.dart';

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

class _FakeHistoryRepository implements HistoryRepository {
  final List<MediaItem> history;
  _FakeHistoryRepository(this.history);

  @override
  Future<void> add(MediaItem item) async => history.add(item);

  @override
  Future<void> clear() async => history.clear();

  @override
  Future<int> get count async => history.length;

  @override
  Future<Map<String, int>> getProviderUsage() async => {};

  @override
  Future<List<MediaItem>> getRecent({int limit = 50}) async =>
      List.of(history.take(limit));

  @override
  Future<List<String>> getRecentSearches({int limit = 10}) async => [];

  @override
  Future<void> recordSearch(String query) async {}

  @override
  Future<void> remove(String itemId) async =>
      history.removeWhere((i) => i.id == itemId);
}

class _FakeFavoriteRepository implements FavoriteRepository {
  final List<MediaItem> favs;
  _FakeFavoriteRepository(this.favs);

  @override
  Stream<void> watchUpdates() => const Stream.empty();

  @override
  Future<void> add(MediaItem item) async {
    if (!favs.any((i) => i.id == item.id)) {
      favs.add(item.copyWith(favorite: true));
    }
  }

  @override
  Future<void> clear() async => favs.clear();

  @override
  Future<int> get count async => favs.length;

  @override
  Future<List<MediaItem>> getAll() async => List.of(favs);

  @override
  Future<bool> isFavorite(String itemId) async =>
      favs.any((i) => i.id == itemId);

  @override
  Future<void> remove(String itemId) async =>
      favs.removeWhere((i) => i.id == itemId);
}

class _FakeMediaSource implements MediaSource {
  @override
  final String id;
  @override
  final MediaSourceType type;
  @override
  MediaSourceState state = MediaSourceState.ready;
  @override
  MediaEventBus? eventBus;

  _FakeMediaSource({
    required this.id,
    required this.type,
  });

  @override
  Stream<List<MediaItem>> get categoriesStream => const Stream.empty();

  @override
  Stream<List<MediaItem>> get channelsStream => const Stream.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<List<MediaItem>> getCategories() async => [];

  @override
  Future<List<MediaItem>> getChannels() async => [];

  @override
  Future<List<MediaItem>> getMovies() async => [];

  @override
  Future<List<MediaItem>> getPrograms() async => [];

  @override
  Future<List<MediaItem>> getSeries() async => [];

  @override
  Future<MediaHealth> health() async => const MediaHealth(isConnected: true, latencyMs: 20);

  @override
  Future<void> initialize() async {}

  @override
  Stream<List<MediaItem>> get moviesStream => const Stream.empty();

  @override
  Stream<List<MediaItem>> get programsStream => const Stream.empty();

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<MediaItem>> get seriesStream => const Stream.empty();

  @override
  Future<MediaStatistics> statistics() async => MediaStatistics(lastSync: DateTime.now());

  @override
  Future<MediaSyncResult> sync() async => MediaSyncResult(
        sourceId: id,
        success: true,
        completedAt: DateTime.now(),
      );

  @override
  Future<bool> validate() async => true;
}

class _FakeMediaSourceRepository implements MediaSourceRepository {
  final List<MediaSource> sources;
  _FakeMediaSourceRepository(this.sources);

  @override
  Future<void> register(MediaSource source) async => sources.add(source);

  @override
  Future<void> unregister(String sourceId) async =>
      sources.removeWhere((s) => s.id == sourceId);

  @override
  Future<void> clear() async => sources.clear();

  @override
  Future<void> delete(String sourceId) async =>
      sources.removeWhere((s) => s.id == sourceId);

  @override
  Future<MediaSource?> getById(String sourceId) async {
    final matches = sources.where((s) => s.id == sourceId);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<List<MediaSource>> getAll() async => List.of(sources);

  @override
  Future<List<MediaSource>> getEnabled() async => List.of(sources);

  @override
  Future<void> updateState(String sourceId, dynamic state) async {}
}

class _DelayedMediaSourceRepository implements MediaSourceRepository {
  final Completer<List<MediaSource>> _completer = Completer<List<MediaSource>>();

  @override
  Future<List<MediaSource>> getAll() => _completer.future;

  @override
  Future<List<MediaSource>> getEnabled() => _completer.future;

  @override
  Future<void> clear() async {}

  @override
  Future<void> delete(String sourceId) async {}

  @override
  Future<MediaSource?> getById(String sourceId) async => null;

  @override
  Future<void> register(MediaSource source) async {}

  @override
  Future<void> unregister(String sourceId) async {}

  @override
  Future<void> updateState(String sourceId, dynamic state) async {}
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
  Stream<List<MediaItem>> get collectionsStream => const Stream.empty();

  @override
  Stream<List<MediaItem>> get downloadsStream => const Stream.empty();

  @override
  Stream<List<MediaItem>> get favoritesStream => const Stream.empty();

  @override
  Stream<List<MediaItem>> get historyStream => const Stream.empty();

  @override
  Stream<List<MediaItem>> get liveTVStream => const Stream.empty();

  @override
  Stream<List<MediaItem>> get moviesStream => const Stream.empty();

  @override
  Stream<List<MediaItem>> get recentStream => const Stream.empty();

  @override
  Stream<List<MediaItem>> get recommendedStream => const Stream.empty();

  @override
  Stream<List<MediaItem>> get searchStream => const Stream.empty();

  @override
  Stream<List<MediaItem>> get seriesStream => const Stream.empty();

  @override
  void addToFavorites(MediaItem item) {}

  @override
  void addToHistory(MediaItem item) {}

  @override
  void clearHistory() {}

  @override
  List<MediaItem> getByType(MediaType type) => [];

  @override
  List<MediaItem> getCollections() => [];

  @override
  List<MediaItem> getDownloads() => [];

  @override
  List<MediaItem> getFavorites() => [];

  @override
  List<MediaItem> getHistory() => [];

  @override
  List<MediaItem> getLiveTV() => [];

  @override
  List<MediaItem> getMovies() => [];

  @override
  List<MediaItem> getRecent() => [];

  @override
  List<MediaItem> getRecommended() => [];

  @override
  List<MediaItem> getSeries() => [];

  @override
  void removeFromFavorites(String itemId) {}

  @override
  List<MediaItem> search(String query) => [];
}

class _FakeHomeSnapshotService implements HomeSnapshotService {
  @override
  Future<void> init() async {}

  @override
  Future<HomeSnapshot?> load() async => null;

  @override
  Future<void> save(HomeSnapshot snapshot) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleMovie = MediaItem(
    id: 'movie-1',
    providerId: 'p-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.movie,
    title: 'Inception',
    description: 'A thief who steals corporate secrets through dream-sharing technology.',
    rating: 8.8,
    backdrop: 'https://example.com/backdrop.jpg',
    poster: 'https://example.com/poster.jpg',
    genres: const ['Sci-Fi', 'Action'],
    metadata: const {'year': '2010', 'duration': '148'},
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    updatedAt: DateTime.now().subtract(const Duration(days: 1)),
  );

  final sampleSeries = MediaItem(
    id: 'series-1',
    providerId: 'p-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.series,
    title: 'Breaking Bad',
    description: 'A high school chemistry teacher turned meth kingpin.',
    rating: 9.5,
    backdrop: 'https://example.com/bb_backdrop.jpg',
    poster: 'https://example.com/bb_poster.jpg',
    genres: const ['Drama', 'Crime'],
    metadata: const {'year': '2008', 'seasons': '5'},
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
    updatedAt: DateTime.now().subtract(const Duration(days: 2)),
  );

  final sampleChannel = MediaItem(
    id: 'chan-1',
    providerId: 'p-1',
    providerType: MediaSourceType.m3u,
    mediaType: MediaType.channel,
    title: 'CNN International',
    subtitle: 'World News Live',
    poster: 'https://example.com/cnn.png',
    metadata: const {'currentProgram': 'World News Live', 'resolution': 'HD'},
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
    updatedAt: DateTime.now(),
  );

  final sampleHistoryItem = MediaItem(
    id: 'hist-1',
    providerId: 'p-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.movie,
    title: 'Interstellar',
    subtitle: '1h 12m remaining',
    poster: 'https://example.com/interstellar.jpg',
    metadata: const {'watchProgress': 0.65},
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
  );

  final sampleSource = _FakeMediaSource(
    id: 'src-1',
    type: MediaSourceType.xtream,
  );

  group('HomeController Unit Tests', () {
    late HomeController controller;
    late _FakeCatalogRepository catalogRepo;
    late _FakeHistoryRepository historyRepo;
    late _FakeFavoriteRepository favoriteRepo;
    late _FakeMediaSourceRepository sourceRepo;

    setUp(() {
      catalogRepo = _FakeCatalogRepository([sampleMovie, sampleSeries, sampleChannel]);
      historyRepo = _FakeHistoryRepository([sampleHistoryItem]);
      favoriteRepo = _FakeFavoriteRepository([sampleMovie]);
      sourceRepo = _FakeMediaSourceRepository([sampleSource]);

      controller = HomeController(
        mediaEngine: _FakeMediaEngine(),
        mediaLibrary: _FakeMediaLibrary(),
        catalogRepository: catalogRepo,
        historyRepository: historyRepo,
        favoriteRepository: favoriteRepo,
        mediaSourceRepository: sourceRepo,
        snapshotService: _FakeHomeSnapshotService(),
      );
    });

    tearDown(() {
      Get.reset();
    });

    test('Loads dashboard data properly', () async {
      await controller.refresh();

      expect(controller.hasProviders.value, isTrue);
      expect(controller.providerCount.value, equals(1));
      expect(controller.movies.length, equals(1));
      expect(controller.movies.first.title, equals('Inception'));
      expect(controller.series.length, equals(1));
      expect(controller.series.first.title, equals('Breaking Bad'));
      expect(controller.liveChannels.length, equals(1));
      expect(controller.liveChannels.first.title, equals('CNN International'));
      expect(controller.continueWatching.length, equals(1));
      expect(controller.continueWatching.first.title, equals('Interstellar'));
      expect(controller.favorites.length, equals(1));
      expect(controller.featuredHeroItems.length, equals(2));
      expect(controller.availableGenres.map((g) => g.title), containsAll(['Sci-Fi', 'Action', 'Drama', 'Sports']));
    });

    test('Calculates greeting correctly', () {
      final greeting = controller.getGreeting();
      expect(['Good morning', 'Good afternoon', 'Good evening'], contains(greeting));
    });

    test('Toggles favorites correctly', () async {
      await controller.refresh();
      expect(controller.isItemFavorite(sampleMovie.id), isTrue);
      expect(controller.isItemFavorite(sampleSeries.id), isFalse);

      await controller.toggleFavorite(sampleSeries);
      expect(controller.isItemFavorite(sampleSeries.id), isTrue);

      await controller.toggleFavorite(sampleSeries);
      expect(controller.isItemFavorite(sampleSeries.id), isFalse);
    });
  });

  group('HomePage Widget Tests', () {
    tearDown(() {
      Get.reset();
    });

    testWidgets('Displays Welcome Card when 0 providers are configured', (tester) async {
      final controller = HomeController(
        mediaEngine: _FakeMediaEngine(),
        mediaLibrary: _FakeMediaLibrary(),
        catalogRepository: _FakeCatalogRepository([]),
        historyRepository: _FakeHistoryRepository([]),
        favoriteRepository: _FakeFavoriteRepository([]),
        mediaSourceRepository: _FakeMediaSourceRepository([]),
        snapshotService: _FakeHomeSnapshotService(),
      );

      Get.put<HomeController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: HomePage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to StreamHub Pro'), findsOneWidget);
      expect(find.text('Add Media Source'), findsOneWidget);
    });

    testWidgets('Renders complete redesigned Home screen with content', (tester) async {
      final controller = HomeController(
        mediaEngine: _FakeMediaEngine(),
        mediaLibrary: _FakeMediaLibrary(),
        catalogRepository: _FakeCatalogRepository([sampleMovie, sampleSeries, sampleChannel]),
        historyRepository: _FakeHistoryRepository([sampleHistoryItem]),
        favoriteRepository: _FakeFavoriteRepository([sampleMovie]),
        mediaSourceRepository: _FakeMediaSourceRepository([sampleSource]),
        snapshotService: _FakeHomeSnapshotService(),
      );

      Get.put<HomeController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: HomePage(),
        ),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.byType(HomeHeader), findsOneWidget);
      expect(find.text('STREAMHUB PRO'), findsOneWidget);

      // Hero Carousel
      expect(find.byType(HomeHeroCarousel), findsOneWidget);
      expect(find.text('WATCH NOW'), findsOneWidget);

      // Quick Actions
      expect(find.byType(HomeQuickActions), findsOneWidget);
      expect(find.text('Live TV'), findsWidgets);
      expect(find.text('Movies'), findsWidgets);
      expect(find.text('Series'), findsWidgets);
      expect(find.text('My List'), findsWidgets);

      // Content Rails
      expect(find.text('Continue Watching'), findsOneWidget);
      expect(find.text('Live Now'), findsOneWidget);
      expect(find.text('Trending Movies'), findsOneWidget);
      expect(find.text('Popular Series'), findsOneWidget);
      expect(find.text('Recently Added'), findsOneWidget);
    });

    testWidgets('Renders Skeleton Loader while loading with providers', (tester) async {
      final delayedSourceRepo = _DelayedMediaSourceRepository();
      final controller = HomeController(
        mediaEngine: _FakeMediaEngine(),
        mediaLibrary: _FakeMediaLibrary(),
        catalogRepository: _FakeCatalogRepository([]),
        historyRepository: _FakeHistoryRepository([]),
        favoriteRepository: _FakeFavoriteRepository([]),
        mediaSourceRepository: delayedSourceRepo,
        snapshotService: _FakeHomeSnapshotService(),
      );

      controller.hasProviders.value = true;
      controller.isLoading.value = true;
      Get.put<HomeController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: HomePage(),
        ),
      );

      await tester.pump();

      expect(find.byType(HomeSkeletonLoader), findsOneWidget);
    });
  });
}
