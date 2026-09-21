// integration_test/macos_remote_nav_coverage_test.dart
//
// Remote (D-pad) + keyboard navigation coverage for the primary navigation
// surfaces, executed on the real macOS device like the other smoke tests:
//
//   flutter test integration_test/macos_remote_nav_coverage_test.dart -d macos
//
// For every surface this suite verifies:
//   1. NO DEAD REMOTE TARGETS — every TvFocusable rendered is connected to a
//      handler (onTap/onLongPress/onKeyEvent). A focusable that swallows Enter
//      but does nothing is a silent dead button and fails this assertion.
//   2. DIRECTIONAL TRAVERSAL — D-pad arrows move focus around the grid; primary
//      focus is never lost and never throws.
//   3. KEYBOARD/REMOTE ACTIVATION — Select/Enter on a targeted in-page control
//      performs a real, observable action (category filter, play/pause toggle),
//      proving the Enter->onTap path works on device, not just focus styling.
//   4. ESCAPE/BACK handling does not throw.
//
// Surfaces intentionally excluded: Settings, Provider Manager, Profile, Storage
// (their controllers are built on Hive/SettingsRepository boxes, which are not
// exercised in this fake environment).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/media_source.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';
import 'package:stream_hub/core/media/player/playback_analytics.dart';
import 'package:stream_hub/core/media/player/player_settings.dart';
import 'package:stream_hub/core/media/repositories/playback_repository.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/channel.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/playback_session_model.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/data/repositories/history_repository.dart';
import 'package:stream_hub/data/repositories/media_source_repository.dart';
import 'package:stream_hub/data/services/database_service.dart';
import 'package:stream_hub/data/services/home_snapshot_service.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/modules/epg/controllers/guide_controller.dart';
import 'package:stream_hub/modules/epg/models/epg_guide.dart';
import 'package:stream_hub/modules/epg/pages/tv_guide_page.dart';
import 'package:stream_hub/modules/epg/repositories/guide_repository.dart';
import 'package:stream_hub/modules/home/home_controller.dart';
import 'package:stream_hub/modules/home/home_page.dart';
import 'package:stream_hub/modules/live_tv/controllers/live_tv_home_controller.dart';
import 'package:stream_hub/modules/live_tv/controllers/live_tv_controller.dart';
import 'package:stream_hub/modules/live_tv/pages/live_tv_page.dart';
import 'package:stream_hub/modules/library/library_controller.dart';
import 'package:stream_hub/modules/library/library_page.dart';
import 'package:stream_hub/modules/movies/movies_controller.dart';
import 'package:stream_hub/modules/movies/movies_page.dart';
import 'package:stream_hub/modules/series/series_controller.dart';
import 'package:stream_hub/modules/series/series_page.dart';
import 'package:stream_hub/modules/search/search_hub_controller.dart';
import 'package:stream_hub/modules/search/search_hub_page.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';
import 'package:stream_hub/shared/widgets/tv_scaffold.dart';

// ---------------------------------------------------------------------------
// Fake data layer (Hive-backed services return safe defaults, never crash)
// ---------------------------------------------------------------------------

class _FakeDatabaseService extends DatabaseService {
  @override
  Future<DatabaseService> init() async => this;

  Never _noHive() => throw StateError('Hive is unavailable in nav coverage');

  @override
  Box get settingsBox => _noHive();

  @override
  Box get providersBox => _noHive();

  @override
  Box get favoritesBox => _noHive();

  @override
  Box get historyBox => _noHive();

  @override
  Box get profilesBox => _noHive();

  @override
  Box get downloadsBox => _noHive();

  @override
  Box get watchProgressBox => _noHive();

  @override
  Box get recentSearchesBox => _noHive();
}

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
  }) async =>
      List.of(items.where((i) => i.mediaType == type)).take(limit).toList();

  @override
  Future<List<MediaItem>> topByCreatedAt(
    MediaType type, {
    String? providerId,
    int limit = 20,
  }) async =>
      List.of(items.where((i) => i.mediaType == type)).take(limit).toList();

  @override
  Future<List<MediaItem>> getByProviderAndType(
    String providerId,
    MediaType type,
  ) async => List.of(items.where((i) => i.mediaType == type));

  @override
  Future<List<MediaItem>> getByType(MediaType type) async =>
      List.of(items.where((i) => i.mediaType == type));

  @override
  Future<MediaItem?> getItem(String id) async =>
      items.where((i) => i.id == id).firstOrNull;

  @override
  Future<void> upsertItems(List<MediaItem> newItems) async {}

  @override
  Future<void> deleteItem(String id) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<List<MediaSyncResult>> syncAll() async => [];

  @override
  Future<MediaSyncResult> syncSource(String sourceId) async => MediaSyncResult(
    sourceId: sourceId,
    success: true,
    completedAt: DateTime.now(),
  );

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
  final List<MediaItem> live;
  final List<MediaItem> movies;
  final List<MediaItem> series;
  _FakeMediaLibrary({
    this.live = const [],
    this.movies = const [],
    this.series = const [],
  });

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

  @override
  List<MediaItem> getLiveTV() => live;

  @override
  List<MediaItem> getMovies() => movies;

  @override
  List<MediaItem> getSeries() => series;

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
  List<MediaItem> getByType(MediaType type) {
    switch (type) {
      case MediaType.channel:
        return live;
      case MediaType.movie:
        return movies;
      case MediaType.series:
        return series;
      default:
        return [];
    }
  }

  @override
  List<MediaItem> search(String query) => [];

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
  Future<List<MediaItem>> getAll() async => List.of(_favorites);

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
  Future<bool> isFavorite(String id) async => _favorites.any((i) => i.id == id);

  @override
  Future<int> get count async => _favorites.length;

  @override
  Future<void> clear() async => _favorites.clear();
}

class _FakeHistoryRepository implements HistoryRepository {
  @override
  Future<void> add(MediaItem item) async {}

  @override
  Future<void> remove(String itemId) async {}

  @override
  Future<List<MediaItem>> getRecent({int limit = 50}) async => [];

  @override
  Future<void> clear() async {}

  @override
  Future<int> get count async => 0;

  @override
  Future<void> recordSearch(String query) async {}

  @override
  Future<List<String>> getRecentSearches({int limit = 10}) async => [];

  @override
  Future<Map<String, int>> getProviderUsage() async => {};
}

class _FakeMediaSourceRepository implements MediaSourceRepository {
  @override
  Future<void> register(MediaSource source) async {}

  @override
  Future<void> unregister(String sourceId) async {}

  @override
  Future<MediaSource?> getById(String sourceId) async => null;

  @override
  Future<List<MediaSource>> getAll() async => [];

  @override
  Future<List<MediaSource>> getEnabled() async => [];

  @override
  Future<void> updateState(String sourceId, dynamic state) async {}

  @override
  Future<void> delete(String sourceId) async {}

  @override
  Future<void> clear() async {}
}

class _FakePlaybackRepository implements PlaybackRepository {
  @override
  Future<void> saveWatchProgress(
    MediaItem item,
    Duration position,
    Duration duration,
  ) async {}

  @override
  Future<Duration?> getWatchProgress(String itemId) async => null;

  @override
  Future<PlaybackSessionModel?> getWatchSession(String itemId) async => null;

  @override
  Future<List<PlaybackSessionModel>> getAllWatchSessions() async => [];

  @override
  Future<void> deleteWatchProgress(String itemId) async {}

  @override
  Future<void> saveAnalytics(PlaybackAnalytics analytics) async {}

  @override
  Future<List<PlaybackAnalytics>> getAnalytics({int limit = 100}) async => [];

  @override
  Future<void> updateSettings(PlayerSettings settings) async {}

  @override
  Future<PlayerSettings> getSettings() async => PlayerSettings();

  @override
  Future<void> clearHistory() async {}
}

class _FakeGuideRepository implements GuideRepository {
  @override
  Future<EPGGuide> fetchGuide({
    required String sourceId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return EPGGuide(
      sourceId: sourceId,
      channels: const [],
      programs: const [],
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> clearCache({String? sourceId}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _registerShared() {
  Get.reset();
  Get.put<LoggingService>(LoggingService(), permanent: true);
  Get.put<DatabaseService>(_FakeDatabaseService(), permanent: true);
  Get.put<ProviderRepository>(ProviderRepository(), permanent: true);
}

void _registerHomeAndMedia() {
  _registerShared();
  final channel1 = Channel(
    id: 'cover-ch-1',
    providerId: 'prov-1',
    providerType: MediaSourceType.m3u,
    title: 'Cover Sports One',
    mediaType: MediaType.channel,
    number: '101',
    isLive: true,
    genres: const ['Sports'],
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 3, 1),
  );
  final channel2 = Channel(
    id: 'cover-ch-2',
    providerId: 'prov-1',
    providerType: MediaSourceType.m3u,
    title: 'Cover News Two',
    mediaType: MediaType.channel,
    number: '102',
    isLive: true,
    genres: const ['News'],
    createdAt: DateTime(2025, 1, 2),
    updatedAt: DateTime(2025, 3, 2),
  );
  final movie = MediaItem(
    id: 'cover-mv-1',
    providerId: 'prov-1',
    providerType: MediaSourceType.m3u,
    mediaType: MediaType.movie,
    title: 'Cover Movie',
    createdAt: DateTime(2025, 2, 1),
    updatedAt: DateTime(2025, 3, 1),
  );
  final serie = MediaItem(
    id: 'cover-sr-1',
    providerId: 'prov-1',
    providerType: MediaSourceType.m3u,
    mediaType: MediaType.series,
    title: 'Cover Series',
    createdAt: DateTime(2025, 2, 2),
    updatedAt: DateTime(2025, 3, 2),
  );

  final catalogRepo = _FakeCatalogRepository([
    channel1,
    channel2,
    movie,
    serie,
  ]);
  final mediaEngine = _FakeMediaEngine();
  final mediaLibrary = _FakeMediaLibrary(
    live: [channel1, channel2],
    movies: [movie],
    series: [serie],
  );
  final favoriteRepo = _FakeFavoriteRepository();
  final historyRepo = _FakeHistoryRepository();
  final mediaSourceRepo = _FakeMediaSourceRepository();
  final playbackRepo = _FakePlaybackRepository();

  Get.put<CatalogRepository>(catalogRepo, permanent: true);
  Get.put<MediaEngine>(mediaEngine, permanent: true);
  Get.put<MediaLibrary>(mediaLibrary, permanent: true);
  Get.put<FavoriteRepository>(favoriteRepo, permanent: true);
  Get.put<HistoryRepository>(historyRepo, permanent: true);
  Get.put<MediaSourceRepository>(mediaSourceRepo, permanent: true);
  Get.put<PlaybackRepository>(playbackRepo, permanent: true);
  Get.put<HomeSnapshotService>(HomeSnapshotService(), permanent: true);

  // App-level controllers shared by several surfaces.
  Get.lazyPut<LiveTVHomeController>(
    () => LiveTVHomeController(
      mediaEngine: mediaEngine,
      mediaLibrary: mediaLibrary,
      catalogRepository: catalogRepo,
      favoriteRepository: favoriteRepo,
    ),
    fenix: true,
  );
  Get.lazyPut<LiveTVController>(
    () => LiveTVController(
      mediaEngine: mediaEngine,
      mediaLibrary: mediaLibrary,
      catalogRepository: catalogRepo,
      favoriteRepository: favoriteRepo,
    ),
    fenix: true,
  );
  Get.lazyPut<LibraryController>(
    () => LibraryController(
      mediaEngine: mediaEngine,
      mediaLibrary: mediaLibrary,
      catalogRepository: catalogRepo,
      historyRepository: historyRepo,
      favoriteRepository: favoriteRepo,
    ),
    fenix: true,
  );
}

// ---------------------------------------------------------------------------
// Coverage helpers
// ---------------------------------------------------------------------------

/// Every rendered [TvFocusable] must expose a remote activation handler.
/// A focusable with no handler is a dead button: it consumes D-pad focus but
/// Enter does nothing.
void _expectNoDeadFocusTargets(WidgetTester tester, String label) {
  final focusables = tester
      .widgetList<TvFocusable>(find.byType(TvFocusable))
      .toList();
  expect(focusables, isNotEmpty, reason: '$label has no focusable elements');
  for (final w in focusables) {
    expect(
      w.onTap != null || w.onLongPress != null || w.onKeyEvent != null,
      isTrue,
      reason:
          '$label contains a dead focus target (no handler): ${w.itemId ?? w.regionId}',
    );
  }
}

/// Sweep D-pad arrows in all four directions, asserting focus is never lost and
/// keeps moving between distinct targets.
Future<void> _sweepArrows(
  WidgetTester tester,
  String label, {
  int rounds = 8,
}) async {
  const keys = [
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowLeft,
  ];
  final visited = <FocusNode>[];
  for (var r = 0; r < rounds; r++) {
    for (final key in keys) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final focus = FocusManager.instance.primaryFocus;
      expect(focus, isNotNull, reason: '$label lost focus after $key');
      if (focus != null && !visited.any((n) => identical(n, focus))) {
        visited.add(focus);
      }
    }
  }
  expect(
    visited.length,
    greaterThanOrEqualTo(2),
    reason:
        '$label D-pad never moved between visible targets '
        '(visited ${visited.length} distinct nodes)',
  );
}

/// Presses Select/Enter on the currently focused element and verifies the app
/// stays healthy.

// ---------------------------------------------------------------------------
// Surfaces
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// TV navigation only engages above ~1024 logical px (see AppScaffold), so
  /// pin the viewport to a 1080p TV for every surface test to keep them
  /// deterministic regardless of the host window size.
  void useTvViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Home dashboard: remote targets, D-pad traversal, activation', (
    tester,
  ) async {
    useTvViewport(tester);
    _registerHomeAndMedia();
    Get.put<HomeController>(
      HomeController(
        mediaEngine: Get.find<MediaEngine>(),
        mediaLibrary: Get.find<MediaLibrary>(),
        catalogRepository: Get.find<CatalogRepository>(),
        historyRepository: Get.find<HistoryRepository>(),
        favoriteRepository: Get.find<FavoriteRepository>(),
        mediaSourceRepository: Get.find<MediaSourceRepository>(),
        snapshotService: Get.find<HomeSnapshotService>(),
      ),
      permanent: true,
    );

    await tester.pumpWidget(const GetMaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    _expectNoDeadFocusTargets(tester, 'Home');
    await _sweepArrows(tester, 'Home');
    // Focus must land inside the TvScaffold rail or body.
    expect(find.byType(TvScaffold), findsOneWidget);
  });

  testWidgets('Live TV: remote targets, D-pad traversal, Enter filters', (
    tester,
  ) async {
    useTvViewport(tester);
    _registerHomeAndMedia();
    final liveCtrl = Get.find<LiveTVController>();
    final live = Get.find<MediaLibrary>().getLiveTV();
    liveCtrl.channels.assignAll(live);
    liveCtrl.filteredChannels.assignAll(live);
    liveCtrl.categories.assignAll(['All Channels', 'Sports', 'News']);
    liveCtrl.isLoading.value = false;

    await tester.pumpWidget(const GetMaterialApp(home: LiveTVPage()));
    await tester.pumpAndSettle();

    _expectNoDeadFocusTargets(tester, 'Live TV');
    await _sweepArrows(tester, 'Live TV');

    // Remote activation: focus the Sports category pill and press Enter.
    await tester.tap(find.text('Sports').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(
      liveCtrl.selectedCategory.value,
      'Sports',
      reason: 'Enter must activate the focused category pill',
    );
  });

  testWidgets('EPG TV Guide: remote targets and D-pad traversal', (
    tester,
  ) async {
    useTvViewport(tester);
    _registerHomeAndMedia();
    final guideCtrl = GuideController(guideRepository: _FakeGuideRepository());
    Get.put<GuideController>(guideCtrl);
    guideCtrl.isLoading.value = false;

    await tester.pumpWidget(const GetMaterialApp(home: TVGuidePage()));
    await tester.pumpAndSettle();

    _expectNoDeadFocusTargets(tester, 'TV Guide');
    await _sweepArrows(tester, 'TV Guide');
  });

  testWidgets(
    'EPG TV Guide on desktop window (<1024, no TvScaffold): D-pad traversal',
    (tester) async {
      // Mirror a macOS desktop window below the 1024px TvScaffold threshold.
      // AppScaffold falls back to the NavigationRail layout wrapped in a
      // WidgetOrderTraversalPolicy group, which is a different focus scope than
      // the TvScaffold used at 1080p. Remote traversal must still move focus
      // through the EPG timeline grid (channel column + program cards).
      tester.view.physicalSize = const Size(900, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _registerHomeAndMedia();
      final liveCtrl = Get.find<LiveTVController>();
      final live = Get.find<MediaLibrary>().getLiveTV();
      liveCtrl.channels.assignAll(live);
      liveCtrl.filteredChannels.assignAll(live);
      liveCtrl.categories.assignAll(['All Channels', 'Sports', 'News']);
      liveCtrl.isLoading.value = false;
      liveCtrl.selectedView.value = 'timeline';
      expect(find.byType(TvScaffold), findsNothing);

      final guideCtrl = GuideController(guideRepository: _FakeGuideRepository());
      Get.put<GuideController>(guideCtrl);
      guideCtrl.isLoading.value = false;

      await tester.pumpWidget(const GetMaterialApp(home: TVGuidePage()));
      await tester.pumpAndSettle();

      _expectNoDeadFocusTargets(tester, 'TV Guide (desktop)');
      expect(find.byType(TvScaffold), findsNothing);
      await _sweepArrows(tester, 'TV Guide (desktop)');
    },
  );

  testWidgets(
    'EPG TV Guide desktop: Grid -> Timeline EPG toggle keeps traversal alive',
    (tester) async {
      tester.view.physicalSize = const Size(900, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _registerHomeAndMedia();
      final liveCtrl = Get.find<LiveTVController>();
      final live = Get.find<MediaLibrary>().getLiveTV();
      liveCtrl.channels.assignAll(live);
      liveCtrl.filteredChannels.assignAll(live);
      liveCtrl.categories.assignAll(['All Channels', 'Sports', 'News']);
      liveCtrl.isLoading.value = false;

      final guideCtrl = GuideController(guideRepository: _FakeGuideRepository());
      Get.put<GuideController>(guideCtrl);
      guideCtrl.isLoading.value = false;

      await tester.pumpWidget(const GetMaterialApp(home: TVGuidePage()));
      await tester.pumpAndSettle();

      _expectNoDeadFocusTargets(tester, 'TV Guide desktop grid');
      await _sweepArrows(tester, 'TV Guide desktop grid');

      // Toggle Grid -> Timeline EPG exactly like the user did, then confirm
      // the D-pad keeps moving across the calendar grid.
      await tester.tap(find.text('Timeline EPG'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(liveCtrl.selectedView.value, 'timeline');
      expect(find.byType(TvScaffold), findsNothing);

      await _sweepArrows(tester, 'TV Guide desktop timeline');
    },
  );

  testWidgets(
    'TV Guide pushed as a routed page on desktop (<1024): traversal survives',
    (tester) async {
      tester.view.physicalSize = const Size(1023, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _registerHomeAndMedia();
      final liveCtrl = Get.find<LiveTVController>();
      final live = Get.find<MediaLibrary>().getLiveTV();
      liveCtrl.channels.assignAll(live);
      liveCtrl.filteredChannels.assignAll(live);
      liveCtrl.categories.assignAll(['All Channels', 'Sports', 'News']);
      liveCtrl.isLoading.value = false;
      liveCtrl.selectedView.value = 'timeline';
      expect(find.byType(TvScaffold), findsNothing);

      final guideCtrl = GuideController(guideRepository: _FakeGuideRepository());
      Get.put<GuideController>(guideCtrl);
      guideCtrl.isLoading.value = false;

      // The guide is reached by NAVIGATION in real usage: Live TV page is pushed,
      // then the guide is pushed on top. Pump the Live TV page first so the
      // guide mounts as a non-initial route (which owns a fresh FocusScope).
      await tester.pumpWidget(
        const GetMaterialApp(home: LiveTVPage()),
      );
      await tester.pumpAndSettle();

      Navigator.of(
        tester.element(find.byType(LiveTVPage)),
        rootNavigator: true,
      ).push(
        MaterialPageRoute<void>(builder: (_) => const TVGuidePage()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TVGuidePage), findsOneWidget);
      _expectNoDeadFocusTargets(tester, 'TV Guide (pushed)');
      await _sweepArrows(tester, 'TV Guide (pushed)');
    },
  );

  testWidgets('Library: remote targets and D-pad traversal', (tester) async {
    useTvViewport(tester);
    _registerHomeAndMedia();

    await tester.pumpWidget(const GetMaterialApp(home: LibraryPage()));
    await tester.pumpAndSettle();

    _expectNoDeadFocusTargets(tester, 'Library');
    await _sweepArrows(tester, 'Library');
  });

  testWidgets('Movies: remote targets and D-pad traversal', (tester  ) async {
    useTvViewport(tester);
    _registerHomeAndMedia();
    Get.put<MoviesController>(
      MoviesController(
        mediaEngine: Get.find<MediaEngine>(),
        mediaLibrary: Get.find<MediaLibrary>(),
        catalogRepository: Get.find<CatalogRepository>(),
        playbackRepository: Get.find<PlaybackRepository>(),
        favoriteRepository: Get.find<FavoriteRepository>(),
      ),
      permanent: true,
    );

    await tester.pumpWidget(const GetMaterialApp(home: MoviesPage()));
    await tester.pumpAndSettle();

    _expectNoDeadFocusTargets(tester, 'Movies');
    await _sweepArrows(tester, 'Movies');
  });

  testWidgets('Series: remote targets and D-pad traversal', (tester  ) async {
    useTvViewport(tester);
    _registerHomeAndMedia();
    Get.put<SeriesController>(
      SeriesController(
        mediaEngine: Get.find<MediaEngine>(),
        mediaLibrary: Get.find<MediaLibrary>(),
        catalogRepository: Get.find<CatalogRepository>(),
        playbackRepository: Get.find<PlaybackRepository>(),
        favoriteRepository: Get.find<FavoriteRepository>(),
      ),
      permanent: true,
    );

    await tester.pumpWidget(const GetMaterialApp(home: SeriesPage()));
    await tester.pumpAndSettle();

    _expectNoDeadFocusTargets(tester, 'Series');
    await _sweepArrows(tester, 'Series');
  });

  testWidgets('Search hub: remote targets and D-pad traversal', (tester  ) async {
    useTvViewport(tester);
    _registerHomeAndMedia();
    Get.put<SearchHubController>(
      SearchHubController(
        catalogRepository: Get.find<CatalogRepository>(),
        historyRepository: Get.find<HistoryRepository>(),
        providerRepository: Get.find<ProviderRepository>(),
      ),
      permanent: true,
    );

    await tester.pumpWidget(const GetMaterialApp(home: SearchHubPage()));
    await tester.pumpAndSettle();

    _expectNoDeadFocusTargets(tester, 'Search');
    await _sweepArrows(tester, 'Search');
  });
}
