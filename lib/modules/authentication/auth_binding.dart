// modules/authentication/auth_binding.dart
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
      Get.put<AuthLocalStorageService>(
        AuthLocalStorageService(),
        permanent: true,
      );
    }
    if (!Get.isRegistered<AuthRepository>()) {
      try {
        final firebaseService = Get.isRegistered<FirebaseService>()
            ? Get.find<FirebaseService>()
            : null;
        Get.put<AuthRepository>(
          AuthRepository(
            authService: Get.find<AuthService>(),
            localStorage: Get.find<AuthLocalStorageService>(),
            firebaseService: firebaseService,
          ),
          permanent: true,
        );
      } catch (e) {
        Get.log('AuthRepository creation failed: $e');
      }
    }
    if (!Get.isRegistered<AuthController>()) {
      final repository = Get.isRegistered<AuthRepository>()
          ? Get.find<AuthRepository>()
          : null;
      Get.lazyPut<AuthController>(
        () => AuthController(repository: repository),
        fenix: true,
      );
    }
  }
}
