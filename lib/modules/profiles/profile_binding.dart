import 'package:get/get.dart';
import 'package:stream_hub/modules/profiles/profile_controller.dart';
import 'package:stream_hub/data/services/profile_service.dart';
import 'package:stream_hub/data/services/settings_service.dart';
import 'package:stream_hub/modules/authentication/repositories/auth_repository.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileController>(() => ProfileController(
      profileService: Get.find<ProfileService>(),
      settingsService: Get.find<SettingsService>(),
      authRepository: Get.find<AuthRepository>(),
    ));
  }
}