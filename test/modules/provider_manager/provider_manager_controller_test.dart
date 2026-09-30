import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/cache_info.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/data/services/cache_service.dart';
import 'package:stream_hub/data/services/provider_storage_service.dart';
import 'package:stream_hub/data/services/provider_sync_service.dart';
import 'package:stream_hub/data/services/settings_service.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_enums.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_model.dart';
import 'package:stream_hub/modules/provider_manager/provider_manager_controller.dart';

class _FakeProviderRepository extends Fake implements ProviderRepository {
  List<ProviderModel> list = [];

  @override
  Future<List<ProviderModel>> getAllProviders() async => List.from(list);

  @override
  Future<ProviderModel?> getProviderById(String id) async {
    return list.cast<ProviderModel?>().firstWhere(
          (p) => p?.id == id,
          orElse: () => null,
        );
  }
}

class _FakeCacheService extends Fake implements CacheService {
  @override
  Future<CacheInfo> calculateCacheSize() async => CacheInfo(
        id: 'default',
        totalSize: 0,
        imageCacheSize: 0,
        temporaryFilesSize: 0,
        metadataCacheSize: 0,
        lastCalculated: DateTime.now(),
      );
}

class _FakeStorageService extends Fake implements ProviderStorageService {}

class _FakeSettingsService extends Fake implements SettingsService {}

class _FakeSyncService extends Fake implements ProviderSyncService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeProviderRepository repository;
  late _FakeCacheService cacheService;
  late _FakeStorageService storageService;
  late _FakeSettingsService settingsService;
  late _FakeSyncService syncService;
  late ProviderManagerController controller;

  final p1 = ProviderModel(
    id: 'p1',
    name: 'Sports Stream M3U',
    providerType: ProviderType.m3u,
    enabled: true,
    favorite: false,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    status: ProviderStatus.active,
  );

  final p2 = ProviderModel(
    id: 'p2',
    name: 'Cinema Xtream',
    providerType: ProviderType.xtream,
    enabled: false,
    favorite: true,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    status: ProviderStatus.inactive,
  );

  final p3 = ProviderModel(
    id: 'p3',
    name: 'News Stalker',
    providerType: ProviderType.stalker,
    enabled: true,
    favorite: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    status: ProviderStatus.active,
  );

  setUp(() {
    Get.reset();
    Get.put(LoggingService());

    repository = _FakeProviderRepository();
    repository.list = [p1, p2, p3];

    cacheService = _FakeCacheService();
    storageService = _FakeStorageService();
    settingsService = _FakeSettingsService();
    syncService = _FakeSyncService();

    controller = ProviderManagerController(
      repository: repository,
      storageService: storageService,
      cacheService: cacheService,
      settingsService: settingsService,
      syncService: syncService,
    );
  });

  tearDown(() {
    Get.reset();
  });

  test('loadProviders populates master list and providers observable', () async {
    await controller.loadProviders();

    expect(controller.hasAnyProviders, isTrue);
    expect(controller.totalProviderCount, equals(3));
    expect(controller.providers.length, equals(3));
  });

  test('searching filters providers without losing master list', () async {
    await controller.loadProviders();

    controller.updateSearchQuery('Cinema');
    expect(controller.providers.length, equals(1));
    expect(controller.providers.first.name, equals('Cinema Xtream'));
    expect(controller.totalProviderCount, equals(3));

    // Clearing search restores full list
    controller.updateSearchQuery('');
    expect(controller.providers.length, equals(3));
  });

  test('filtering by type/status does not permanently discard items', () async {
    await controller.loadProviders();

    controller.updateFilterType(ProviderFilterType.favorites);
    expect(controller.providers.length, equals(2));
    expect(controller.providers.any((p) => p.id == 'p1'), isFalse);
    expect(controller.totalProviderCount, equals(3));

    controller.updateFilterType(ProviderFilterType.disabled);
    expect(controller.providers.length, equals(1));
    expect(controller.providers.first.id, equals('p2'));

    // Reset back to all
    controller.updateFilterType(ProviderFilterType.all);
    expect(controller.providers.length, equals(3));
  });

  test('getProviderById resolves provider even when excluded by active filter', () async {
    await controller.loadProviders();

    // Filter to only disabled (only p2 is visible in controller.providers)
    controller.updateFilterType(ProviderFilterType.disabled);
    expect(controller.providers.length, equals(1));

    // getProviderById must still find p1 from master list
    final p1Result = controller.getProviderById('p1');
    expect(p1Result, isNotNull);
    expect(p1Result?.name, equals('Sports Stream M3U'));

    // Non-existent id returns null
    expect(controller.getProviderById('nonexistent'), isNull);
  });
}
