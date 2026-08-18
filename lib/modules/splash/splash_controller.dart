import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/media/enums/media_type.dart';
import '../../core/logging/logging_service.dart';
import '../../core/routes/app_routes.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/services/database_service.dart';
import '../../data/services/firebase_service.dart';
import '../../data/services/provider_sync_service.dart';
import '../authentication/auth_controller.dart';
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
          await authRepository.initialize();
          final user = await authRepository.tryAutoLogin();
          if (user != null) {
            statusMessage.value = 'Welcome back!';
            if (Get.isRegistered<AuthController>()) {
              final authController = Get.find<AuthController>();
              authController.currentUser.value = user;
              authController.isAuthenticated.value = true;
            }

            var hasCachedChannels = false;
            if (Get.isRegistered<CatalogRepository>()) {
              try {
                final catalogRepo = Get.find<CatalogRepository>();
                final channels = await catalogRepo.getByType(MediaType.channel);
                hasCachedChannels = channels.isNotEmpty;
              } catch (_) {}
            }

            if (hasCachedChannels) {
              // Channels are already cached: navigate directly & sync rest in background
              unawaited(_syncProvidersOnStartup());
              statusMessage.value = 'Ready!';
              _navigateAway(AppRoutes.home);
              return;
            } else {
              // Local database is empty: sync the primary provider first so Home is never empty
              statusMessage.value = 'Loading Live TV...';
              if (Get.isRegistered<ProviderSyncService>()) {
                final syncService = Get.find<ProviderSyncService>();
                await syncService.syncPrimaryProviderAndQueueRemainder();
              }
              statusMessage.value = 'Ready!';
              _navigateAway(AppRoutes.home);
              return;
            }
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

  /// Keeps playlists fresh: every time the app is opened, all enabled
  /// providers are re-synced in the background so users never have to
  /// manually trigger a sync after adding a link.
  Future<void> _syncProvidersOnStartup() async {
    try {
      final syncService = Get.find<ProviderSyncService>();
      await syncService.syncAll();
    } catch (e) {
      Get.find<LoggingService>().warning(
        'Startup provider sync failed',
        tag: 'SplashController',
        error: e,
      );
    }
  }

  void _navigateAway(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.offAllNamed(route);
    });
  }
}
