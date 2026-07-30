import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../data/services/database_service.dart';
import '../../data/services/firebase_service.dart';
import '../authentication/repositories/auth_repository.dart';

class SplashController extends GetxController {
  final RxString statusMessage = 'Starting up...'.obs;

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      statusMessage.value = 'Initializing...';

      final databaseService = Get.find<DatabaseService>();
      await databaseService.init();

      final firebaseService = Get.find<FirebaseService>();
      await firebaseService.init();

      if (Get.isRegistered<AuthRepository>()) {
        try {
          final authRepository = Get.find<AuthRepository>();
          final user = await authRepository.tryAutoLogin();
          if (user != null) {
            statusMessage.value = 'Welcome back!';
            _navigateAway(AppRoutes.dashboard);
            return;
          }
        } catch (e) {
          statusMessage.value = 'Authentication check failed.';
        }
      }

      statusMessage.value = 'Ready!';
      _navigateAway(AppRoutes.authWrapper);
    } catch (e) {
      statusMessage.value = 'Initialization failed. Retrying...';
      _navigateAway(AppRoutes.authWrapper);
    }
  }

  void _navigateAway(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.offAllNamed(route);
    });
  }
}
