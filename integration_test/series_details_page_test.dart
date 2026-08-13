import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/streaming/auth/authentication_engine.dart';
import 'package:stream_hub/core/streaming/cache/session_cache.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';
import 'package:stream_hub/core/streaming/series/xtream_series_info_service.dart';
import 'package:stream_hub/core/streaming/session/factories/xtream_provider_session_factory.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory_registry.dart';
import 'package:stream_hub/core/streaming/session/session_manager.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/data/services/database_service.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_enums.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_model.dart';
import 'package:stream_hub/modules/series/series_details_controller.dart';
import 'package:stream_hub/modules/series/series_details_page.dart';

import '../test/stream_engine/fakes/fake_local_service.dart';
import '../test/xtream/xtream_test_server.dart';

/// Drives the real [SeriesDetailsPage] on a device against an in-process mock
/// Xtream Codes panel.
///
/// The page mounts the production controller + the real
/// [XtreamSeriesInfoService] (network over loopback), so the full path —
/// session creation, `get_series_info` fetch, layout parsing, episode caching
/// into the catalog, and season UI — is exercised exactly as in production.
///
///   flutter test integration_test/series_details_page_test.dart \
///     -d 140494554P002987
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'SeriesDetailsPage renders seasons and episodes from get_series_info',
    (tester) async {
      final server = await XtreamTestServer.start();
      addTearDown(server.close);
      addTearDown(Get.reset);

      final catalog = _FakeCatalogRepository();
      final provider = _registerDependencies(server, catalog);

      final series = _seriesItem();
      Get.put<SeriesDetailsController>(
        SeriesDetailsController(
          sessionManager: Get.find<SessionManager>(),
          providerRepository: provider,
          catalogRepository: catalog,
          seriesInfoService: Get.find<XtreamSeriesInfoService>(),
          favoriteRepository: Get.find<FavoriteRepository>(),
          logger: Get.find<LoggingService>(),
          initialSeries: series,
        ),
      );

      await tester.pumpWidget(GetMaterialApp(home: const SeriesDetailsPage()));

      await _waitFor(tester, find.text('2 Seasons · 3 Episodes'));

      expect(find.text('Breaking Bad'), findsWidgets);
      expect(find.text('Season 1'), findsWidgets);
      expect(find.text('Season 2'), findsWidgets);
      expect(find.text('Play Season 1'), findsOneWidget);
      expect(find.text('Pilot'), findsOneWidget);
      expect(find.text('Cat\'s in the Bag...'), findsOneWidget);

      await tester.tap(find.text('Season 2'));
      await tester.pump(const Duration(milliseconds: 300));
      await _waitFor(tester, find.text('Seven Thirty-Seven'));

      expect(find.text('Play Season 2'), findsOneWidget);
      expect(find.text('Pilot'), findsNothing);

      // The controller must have cached the discovered episodes into the
      // catalog so later opens work offline / from a flaky panel.
      expect(catalog.upserted.length, 3);
      final cached = catalog.upserted.first;
      expect(cached.metadata['seasonId'], '1');
      expect(cached.metadata['seasonName'], 'Season 1');
      expect(cached.metadata['episodeNumber'], 1);
      expect(cached.metadata['streamUrl'], contains('/series/demo/secret/7001.mp4'));
    },
  );

  testWidgets(
    'SeriesDetailsPage falls back to the catalog when the panel 404s',
    (tester) async {
      final server = await XtreamTestServer.start(
        handler: (action, params) {
          if (action == 'get_series_info') return {'__status__': 404};
          return defaultHandler(action, params);
        },
      );
      addTearDown(server.close);
      addTearDown(Get.reset);

      final catalog = _FakeCatalogRepository()
        ..items.addAll([
          _catalogEpisode(
            id: 'ep-1-1',
            seasonId: '1',
            seasonName: 'Season One',
            episodeNumber: '1',
            streamId: '7001',
            title: 'Pilot',
          ),
          _catalogEpisode(
            id: 'ep-1-2',
            seasonId: '1',
            seasonName: 'Season One',
            episodeNumber: '2',
            streamId: '7002',
            title: 'Cat\'s in the Bag...',
          ),
          _catalogEpisode(
            id: 'ep-2-1',
            seasonId: '2',
            seasonName: 'Season Two',
            episodeNumber: '1',
            streamId: '7101',
            title: 'Seven Thirty-Seven',
          ),
        ]);
      final provider = _registerDependencies(server, catalog);

      Get.put<SeriesDetailsController>(
        SeriesDetailsController(
          sessionManager: Get.find<SessionManager>(),
          providerRepository: provider,
          catalogRepository: catalog,
          seriesInfoService: Get.find<XtreamSeriesInfoService>(),
          favoriteRepository: Get.find<FavoriteRepository>(),
          logger: Get.find<LoggingService>(),
          initialSeries: _seriesItem(),
        ),
      );

      await tester.pumpWidget(GetMaterialApp(home: const SeriesDetailsPage()));

      await _waitFor(tester, find.text('2 Seasons · 3 Episodes'));

      expect(find.text('Season One'), findsWidgets);
      expect(find.text('Season Two'), findsWidgets);
      expect(find.text('Play Season One'), findsOneWidget);
      expect(find.text('Pilot'), findsOneWidget);

      await tester.tap(find.text('Season Two'));
      await tester.pump(const Duration(milliseconds: 300));
      await _waitFor(tester, find.text('Seven Thirty-Seven'));
      expect(find.text('Play Season Two'), findsOneWidget);
    },
  );
}

_FakeProviderRepository _registerDependencies(
  XtreamTestServer server,
  CatalogRepository catalog,
) {
  Get.put(LoggingService(), permanent: true);
  Get.put<DatabaseService>(DatabaseService(), permanent: true);

  final sessionCache = SessionCache(FakeLocalService());
  final registry = ProviderSessionFactoryRegistry()
    ..register(XtreamProviderSessionFactory(logger: Get.find<LoggingService>()));
  Get.put<SessionManager>(
    SessionManager(
      sessionCache: sessionCache,
      authenticationEngine: AuthenticationEngine(),
      cookieManager: CookieManager(),
      registry: registry,
      logger: Get.find<LoggingService>(),
    ),
    permanent: true,
  );
  Get.put<XtreamSeriesInfoService>(
    XtreamSeriesInfoService(logger: Get.find<LoggingService>()),
    permanent: true,
  );
  final provider = _FakeProviderRepository()
    ..providers['p1'] = _providerFor(server.baseUrl);
  Get.put<ProviderRepository>(provider, permanent: true);
  Get.put<CatalogRepository>(catalog, permanent: true);
  Get.put<FavoriteRepository>(_FakeFavoriteRepository(), permanent: true);
  return provider;
}

ProviderModel _providerFor(String baseUrl) {
  return ProviderModel(
    id: 'p1',
    name: 'Demo',
    providerType: ProviderType.xtream,
    serverUrl: baseUrl,
    username: 'demo',
    password: 'secret',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    status: ProviderStatus.active,
  );
}

MediaItem _seriesItem() {
  final now = DateTime.now();
  return MediaItem(
    id: 'xtream-series-601',
    providerId: 'p1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.series,
    title: 'Breaking Bad',
    metadata: {
      'seriesId': '601',
      'streamId': '900',
    },
    createdAt: now,
    updatedAt: now,
  );
}

MediaItem _catalogEpisode({
  required String id,
  required String seasonId,
  required String seasonName,
  required String episodeNumber,
  required String streamId,
  required String title,
}) {
  final now = DateTime.now();
  return MediaItem(
    id: id,
    providerId: 'p1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.episode,
    title: title,
    metadata: {
      'seriesId': '601',
      'seasonId': seasonId,
      'seasonName': seasonName,
      'episodeNumber': episodeNumber,
      'streamId': streamId,
    },
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

class _FakeCatalogRepository implements CatalogRepository {
  final List<MediaItem> items = [];
  final List<MediaItem> upserted = [];

  @override
  Future<List<MediaItem>> getAllItems() async => List.of(items);

  @override
  Future<void> upsertItems(List<MediaItem> newItems) async {
    upserted.addAll(newItems);
    items.addAll(newItems);
  }

  @override
  Future<MediaItem?> getItem(String id) async {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<void> deleteItem(String id) async =>
      items.removeWhere((i) => i.id == id);

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

class _FakeProviderRepository extends ProviderRepository {
  final Map<String, ProviderModel> providers = {};

  @override
  Future<ProviderModel?> getProviderById(String id) async => providers[id];
}

class _FakeFavoriteRepository implements FavoriteRepository {
  final List<String> favorites = [];

  @override
  Future<void> add(MediaItem item) async => favorites.add(item.id);

  @override
  Future<void> remove(String itemId) async => favorites.remove(itemId);

  @override
  Future<List<MediaItem>> getAll() async => [];

  @override
  Future<bool> isFavorite(String itemId) async => favorites.contains(itemId);

  @override
  Future<void> clear() async => favorites.clear();

  @override
  Future<int> get count async => favorites.length;
}
