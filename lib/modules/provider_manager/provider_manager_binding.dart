import 'package:get/get.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/data/services/cache_service.dart';
import 'package:stream_hub/data/services/provider_storage_service.dart';
import 'package:stream_hub/data/services/provider_sync_service.dart';
import 'package:stream_hub/data/services/settings_service.dart';
import 'package:stream_hub/modules/provider_manager/provider_manager_controller.dart';

class ProviderManagerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProviderManagerController>(() => ProviderManagerController(
      repository: Get.find<ProviderRepository>(),
      storageService: Get.find<ProviderStorageService>(),
      cacheService: Get.find<CacheService>(),
      settingsService: Get.find<SettingsService>(),
      syncService: Get.find<ProviderSyncService>(),
    ));
  }
}