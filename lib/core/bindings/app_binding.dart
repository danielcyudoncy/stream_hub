import 'package:get/get.dart';
import 'package:stream_hub/data/repositories/settings_repository.dart';
import 'package:stream_hub/data/repositories/profile_repository.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/data/services/settings_service.dart';
import 'package:stream_hub/data/services/profile_service.dart';
import 'package:stream_hub/data/services/provider_storage_service.dart';
import 'package:stream_hub/data/services/cache_service.dart';
import 'package:stream_hub/data/services/database_service.dart';
import 'package:stream_hub/data/services/firebase_service.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.find<DatabaseService>();
    final settingsRepo = SettingsRepository();
    final profileRepo = ProfileRepository();
    final providerRepo = ProviderRepository();

    Get.put<SettingsRepository>(settingsRepo, permanent: true);
    Get.put<ProfileRepository>(profileRepo, permanent: true);
    Get.put<ProviderRepository>(providerRepo, permanent: true);

    Get.put<SettingsService>(SettingsService(settingsRepo), permanent: true);
    Get.put<ProfileService>(ProfileService(profileRepo), permanent: true);
    Get.put<ProviderStorageService>(ProviderStorageService(providerRepo), permanent: true);
    Get.put<CacheService>(CacheService(settingsRepo), permanent: true);

    if (!Get.isRegistered<FirebaseService>()) {
      Get.put<FirebaseService>(FirebaseService(), permanent: true);
    }
  }
}
