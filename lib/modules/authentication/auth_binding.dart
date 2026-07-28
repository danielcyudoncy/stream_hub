import 'package:get/get.dart';
import '../../../data/services/firebase_service.dart';
import './services/auth_local_storage_service.dart';
import './services/auth_service.dart';
import './repositories/auth_repository.dart';
import 'auth_controller.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<AuthLocalStorageService>()) {
      Get.put<AuthLocalStorageService>(AuthLocalStorageService(), permanent: true);
    }
    if (!Get.isRegistered<AuthRepository>()) {
      try {
        Get.put<AuthRepository>(AuthRepository(
              authService: Get.find<AuthService>(),
              localStorage: Get.find<AuthLocalStorageService>(),
              firebaseService: Get.find<FirebaseService>(),
            ), permanent: true);
      } catch (e) {
        Get.log('AuthRepository creation failed: $e');
      }
    }
    if (!Get.isRegistered<AuthController>()) {
      final repository = Get.isRegistered<AuthRepository>()
          ? Get.find<AuthRepository>()
          : null;
      Get.lazyPut<AuthController>(() => AuthController(
            repository: repository,
          ));
    }
  }
}
