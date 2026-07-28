import 'package:get/get.dart';
import 'package:stream_hub/data/services/settings_service.dart';
import 'package:stream_hub/data/services/profile_service.dart';
import 'package:stream_hub/data/services/cache_service.dart';
import 'settings_controller.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SettingsController>(() => SettingsController(
      settingsService: Get.find<SettingsService>(),
      profileService: Get.find<ProfileService>(),
      cacheService: Get.find<CacheService>(),
    ));
  }
}
