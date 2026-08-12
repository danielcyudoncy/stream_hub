import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/streaming/auth/authentication_engine.dart';
import 'package:stream_hub/core/streaming/cache/session_cache.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';
import 'package:stream_hub/core/streaming/series/xtream_series_info_service.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory_registry.dart';
import 'package:stream_hub/core/streaming/session/session_manager.dart';
import 'package:stream_hub/core/streaming/session/factories/xtream_provider_session_factory.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/data/services/database_service.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_enums.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_model.dart';
import 'package:stream_hub/modules/series/series_details_controller.dart';

import '../../stream_engine/fakes/fake_local_service.dart';

class _FakeSeriesInfoService extends XtreamSeriesInfoService {
  XtreamSeriesInfo? info;
  Object? error;
  final List<String> requestedIds = [];

  @override
  Future<XtreamSeriesInfo> fetch({
    required ProviderSession session,
    required String seriesId,
    List<String> alternativeIds = const [],
  }) async {
    requestedIds.addAll([seriesId, ...alternativeIds]);
    final err = error;
    if (err != null) throw err;
    return info ??
        const XtreamSeriesInfo(seriesId: '', name: '', seasons: []);
  }
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
  Future<void> deleteItem(String id) async => items.removeWhere((i) => i.id == id);

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

void main() {
  late _FakeSeriesInfoService seriesInfoService;
  late _FakeCatalogRepository catalogRepository;
  late _FakeProviderRepository providerRepository;
  late SessionManager sessionManager;
  late MediaItem series;

  setUp(() {
    Get.reset();
    Get.put(LoggingService());
    Get.put<DatabaseService>(DatabaseService());

    seriesInfoService = _FakeSeriesInfoService();
    catalogRepository = _FakeCatalogRepository();
    providerRepository = _FakeProviderRepository();

    final sessionCache = SessionCache(FakeLocalService());
    final registry = ProviderSessionFactoryRegistry()
      ..register(XtreamProviderSessionFactory());
    sessionManager = SessionManager(
      sessionCache: sessionCache,
      authenticationEngine: AuthenticationEngine(),
      cookieManager: CookieManager(),
      registry: registry,
    );

    providerRepository.providers['p1'] = ProviderModel(
      id: 'p1',
      name: 'Demo',
      providerType: ProviderType.xtream,
      serverUrl: 'http://panel.example.com',
      username: 'demo',
      password: 'secret',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ProviderStatus.active,
    );

    final now = DateTime.now();
    series = MediaItem(
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
  });

  SeriesDetailsController buildController() {
    return SeriesDetailsController(
      sessionManager: sessionManager,
      providerRepository: providerRepository,
      catalogRepository: catalogRepository,
      seriesInfoService: seriesInfoService,
      logger: LoggingService(),
      initialSeries: series,
    );
  }

  Future<void> pumpLoad(SeriesDetailsController controller) async {
    controller.onInit();
    while (controller.isLoading.value) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  XtreamSeriesInfo sampleInfo() {
    return const XtreamSeriesInfo(
      seriesId: '601',
      name: 'Breaking Bad',
      seasons: [
        XtreamSeriesSeason(
          number: 1,
          name: 'Season One',
          episodes: [
            XtreamSeriesEpisode(
              id: '7001',
              title: 'Pilot',
              extension: 'mp4',
              seasonNum: 1,
              episodeNum: 1,
            ),
          ],
        ),
        XtreamSeriesSeason(
          number: 2,
          name: 'Season Two',
          episodes: [
            XtreamSeriesEpisode(
              id: '7101',
              title: 'Seven Thirty-Seven',
              extension: 'mkv',
              seasonNum: 2,
              episodeNum: 1,
            ),
          ],
        ),
      ],
    );
  }

  MediaItem catalogEpisode({
    required String id,
    required String seasonId,
    required String seasonName,
    required String episodeNumber,
    required String streamId,
  }) {
    final now = DateTime.now();
    return MediaItem(
      id: id,
      providerId: 'p1',
      providerType: MediaSourceType.xtream,
      mediaType: MediaType.episode,
      title: 'Episode $episodeNumber',
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

  group('SeriesDetailsController', () {
    test('loads seasons from get_series_info and caches episodes', () async {
      seriesInfoService.info = sampleInfo();

      final controller = buildController();
      await pumpLoad(controller);

      expect(controller.isLoading.value, isFalse);
      expect(controller.errorMessage.value, isEmpty);
      expect(controller.seasonCount, 2);
      expect(controller.totalEpisodes, 2);

      final first = controller.seasons[0];
      expect(first.number, 1);
      expect(first.name, 'Season One');
      expect(first.episodes.single.title, 'Pilot');

      final episode = first.episodes.single;
      expect(episode.metadata['seasonId'], '1');
      expect(episode.metadata['seasonNumber'], 1);
      expect(episode.metadata['seasonName'], 'Season One');
      expect(episode.metadata['episodeNumber'], 1);
      expect(episode.metadata['streamUrl'],
          'http://panel.example.com/series/demo/secret/7001.mp4');

      expect(catalogRepository.upserted.length, 2);
      expect(catalogRepository.upserted.first.id, episode.id);
    });

    test('asks for the stream id as an alternative when series info 404s',
        () async {
      seriesInfoService.info = sampleInfo();

      final controller = buildController();
      await pumpLoad(controller);

      expect(seriesInfoService.requestedIds, ['601', '900']);
      expect(controller.seasonCount, 2);
    });

    test('falls back to the catalog when get_series_info is unavailable',
        () async {
      seriesInfoService.error = const StreamSeriesInfoUnavailableException(
        message: 'No episode list.',
      );
      catalogRepository.items.addAll([
        catalogEpisode(
          id: 'ep-2-1',
          seasonId: '2',
          seasonName: 'Season Two',
          episodeNumber: '1',
          streamId: '7101',
        ),
        catalogEpisode(
          id: 'ep-1-2',
          seasonId: '1',
          seasonName: 'Season One',
          episodeNumber: '2',
          streamId: '7002',
        ),
        catalogEpisode(
          id: 'ep-1-1',
          seasonId: '1',
          seasonName: 'Season One',
          episodeNumber: '1',
          streamId: '7001',
        ),
      ]);

      final controller = buildController();
      await pumpLoad(controller);

      expect(controller.errorMessage.value, isEmpty);
      expect(controller.seasonCount, 2);

      final first = controller.seasons[0];
      expect(first.number, 1);
      expect(first.name, 'Season One');
      expect(first.episodes.length, 2);
      expect(first.episodes.first.metadata['streamId'], '7001');
      expect(first.episodes.last.metadata['streamId'], '7002');
      expect(controller.seasons[1].name, 'Season Two');
    });

    test('shows a friendly message when no episode source is available',
        () async {
      seriesInfoService.error = const StreamSeriesInfoUnavailableException(
        message: 'No episode list.',
      );

      final controller = buildController();
      await pumpLoad(controller);

      expect(controller.errorMessage.value, isEmpty);
      expect(controller.infoMessage.value, isNotEmpty);
      expect(controller.seasons, isEmpty);
    });

    test('selecting a season updates the selected season group', () async {
      seriesInfoService.info = sampleInfo();

      final controller = buildController();
      await pumpLoad(controller);

      controller.selectSeason(1);
      expect(controller.selectedSeason?.number, 2);
      expect(controller.selectedSeason?.name, 'Season Two');

      controller.selectSeason(99);
      expect(controller.selectedSeason?.number, 2);
    });
  });
}
