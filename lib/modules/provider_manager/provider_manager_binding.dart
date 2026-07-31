import 'package:get/get.dart';
import 'package:stream_hub/core/media/media_source_factory.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/media_source_repository.dart';
import 'package:stream_hub/modules/provider_manager/provider_manager_controller.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/data/services/provider_storage_service.dart';
import 'package:stream_hub/data/services/cache_service.dart';
import 'package:stream_hub/data/services/settings_service.dart';

class ProviderManagerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProviderManagerController>(() => ProviderManagerController(
      repository: Get.find<ProviderRepository>(),
      storageService: Get.find<ProviderStorageService>(),
      cacheService: Get.find<CacheService>(),
      settingsService: Get.find<SettingsService>(),
      sourceFactory: Get.find<MediaSourceFactory>(),
      sourceRepo: Get.find<MediaSourceRepository>(),
      catalogRepo: Get.find<CatalogRepository>(),
    ));
  }
}