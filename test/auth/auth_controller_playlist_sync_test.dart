// test/auth/auth_controller_playlist_sync_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthController auto sync', () {
    late Directory tempDir;

    setUp(() async {
      Get.reset();
      tempDir = await Directory.systemTemp.createTemp('auth_sync_test');
      Hive.init(tempDir.path);
      Get.put(LoggingService(), permanent: true);
      final db = DatabaseService();
      Get.put(db, permanent: true);
      await db.init();
    });

    tearDown(() async {
      Get.reset();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

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

      final repo = ProviderRepository();
      await repo.createProvider(enabledProvider);
      Get.put<ProviderRepository>(repo, permanent: true);

      final fakeSyncService = _FakeSyncService(repository: repo);
      Get.put<ProviderSyncService>(fakeSyncService, permanent: true);

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

        final repo = ProviderRepository();
        await repo.createProvider(enabledProvider);
        Get.put<ProviderRepository>(repo, permanent: true);

        final fakeSyncService = _FakeSyncService(repository: repo);
        Get.put<ProviderSyncService>(fakeSyncService, permanent: true);

        Get.put<AuthController>(
          AuthController(repository: null),
          permanent: true,
        );

        await tester.pumpWidget(
          GetMaterialApp(
            initialRoute: AppRoutes.syncScreen,
            getPages: [
              GetPage(name: AppRoutes.syncScreen, page: () => SyncScreenPage()),
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
        expect(find.textContaining('sources synced'), findsOneWidget);
      },
    );
  });
}
