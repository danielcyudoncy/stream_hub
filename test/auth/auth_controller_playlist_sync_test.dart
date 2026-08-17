// test/auth/auth_controller_playlist_sync_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/media_source.dart';
import 'package:stream_hub/core/media/media_source_factory.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/media_source_repository.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/data/services/database_service.dart';
import 'package:stream_hub/data/services/provider_sync_service.dart';
import 'package:stream_hub/modules/authentication/auth_controller.dart';
import 'package:stream_hub/modules/authentication/sync_screen_page.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_enums.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_model.dart';

class _FakeDatabaseService extends DatabaseService {}

class _FakeProviderRepository extends ProviderRepository {
  final List<ProviderModel> _providers = [];

  @override
  Future<List<ProviderModel>> getAllProviders() async => List.of(_providers);

  @override
  Future<ProviderModel> createProvider(ProviderModel provider) async {
    _providers.add(provider);
    return provider;
  }
}

class _FakeSyncService extends ProviderSyncService {
  int callCount = 0;

  _FakeSyncService({required super.repository})
    : super(
        sourceFactory: _FakeSourceFactory(),
        sourceRepo: _FakeSourceRepository(),
        catalogRepo: _FakeCatalogRepository(),
        logger: LoggingService(),
      );

  @override
  Future<ProviderSyncResult> syncProvider(ProviderModel provider) async {
    callCount++;
    return ProviderSyncResult(provider: provider, success: true, message: 'ok');
  }
}

class _FakeSourceFactory implements MediaSourceFactory {
  @override
  MediaSource create(
    String id,
    MediaSourceType type,
    Map<String, dynamic> config,
  ) => throw UnimplementedError();
}

class _FakeSourceRepository implements MediaSourceRepository {
  @override
  Future<void> register(MediaSource source) async {}

  @override
  Future<void> unregister(String sourceId) async {}

  @override
  Future<MediaSource?> getById(String sourceId) async => null;

  @override
  Future<List<MediaSource>> getAll() async => const [];

  @override
  Future<List<MediaSource>> getEnabled() async => const [];

  @override
  Future<void> updateState(String sourceId, dynamic state) async {}

  @override
  Future<void> delete(String sourceId) async {}

  @override
  Future<void> clear() async {}
}

class _FakeCatalogRepository implements CatalogRepository {
  @override
  Future<List<MediaItem>> getAllItems() async => const [];

  @override
  Future<List<MediaItem>> getByType(MediaType type) async => const [];

  @override
  Future<MediaItem?> getItem(String id) async => null;

  @override
  Future<void> upsertItems(List<MediaItem> items) async {}

  @override
  Future<void> deleteItem(String id) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<List<MediaSyncResult>> syncAll() async => const [];

  @override
  Future<MediaSyncResult> syncSource(String sourceId) async => MediaSyncResult(
    sourceId: sourceId,
    success: true,
    completedAt: DateTime.now(),
  );

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<MediaItem>> watchUpdates() async* {}

  @override
  Future<void> enrichWithXMLTV(XMLTVGuide guide) async {}

  @override
  Future<void> mergeXMLTVMetadata(XMLTVGuide guide) async {}
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(LoggingService(), permanent: true);
    Get.put<DatabaseService>(_FakeDatabaseService(), permanent: true);
  });

  tearDown(() {
    Get.reset();
  });

  group('AuthController auto sync', () {
    test('uses the provider sync service for enabled providers', () async {
      final enabledProvider = ProviderModel(
        id: 'provider-1',
        name: 'Demo Playlist',
        providerType: ProviderType.m3u,
        serverUrl: 'https://example.com/test.m3u',
        enabled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ProviderStatus.inactive,
      );

      final repo = _FakeProviderRepository();
      await repo.createProvider(enabledProvider);
      Get.put<ProviderRepository>(repo);

      final fakeSyncService = _FakeSyncService(repository: repo);
      Get.put<ProviderSyncService>(fakeSyncService);

      final controller = AuthController(repository: null);
      await controller.triggerAutomaticPlaylistSync();

      expect(fakeSyncService.callCount, 1);
      expect(controller.syncedSources.value, 1);
      expect(controller.syncStatus.value, contains('Sync complete'));
    });

    testWidgets(
      'keeps sync screen visible long enough to show completion status',
      (tester) async {
        final enabledProvider = ProviderModel(
          id: 'provider-2',
          name: 'Demo Playlist',
          providerType: ProviderType.m3u,
          serverUrl: 'https://example.com/test.m3u',
          enabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ProviderStatus.inactive,
        );

        final repo = _FakeProviderRepository();
        await repo.createProvider(enabledProvider);
        Get.put<ProviderRepository>(repo);

        final fakeSyncService = _FakeSyncService(repository: repo);
        Get.put<ProviderSyncService>(fakeSyncService);

        Get.put<AuthController>(
          AuthController(repository: null),
        );

        await tester.pumpWidget(
          GetMaterialApp(
            initialRoute: AppRoutes.syncScreen,
            getPages: [
              GetPage(name: AppRoutes.syncScreen, page: () => const SyncScreenPage()),
              GetPage(
                name: AppRoutes.home,
                page: () => const Scaffold(body: Text('Home')),
              ),
            ],
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(Get.currentRoute, AppRoutes.syncScreen);
        expect(find.textContaining('Sync complete'), findsOneWidget);
        expect(find.text('1 of 1 sources synced'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pump();
        expect(Get.currentRoute, AppRoutes.home);
      },
    );
  });
}
