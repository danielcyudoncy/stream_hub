import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_config.dart';
import '../config/environment.dart';
import '../constants/app_constants.dart';
import '../logging/logging_service.dart';
import '../../data/services/database_service.dart';
import '../../data/services/firebase_service.dart';

class AppInitializer {
  static Future<void> initialize() async {
    // 1. Initialize Flutter bindings
    WidgetsFlutterBinding.ensureInitialized();

    // 2. Register LoggingService first so other services can log
    final logger = Get.put(LoggingService(), permanent: true);
    logger.info('Starting StreamHub Pro bootstrap...', tag: 'AppInitializer');

    // 3. Initialize AppConfig (using Development environment for default startup configuration)
    AppConfig.initialize(
      environmentConfig: EnvironmentConfig.development(),
      appName: AppConstants.appName,
      appVersion: AppConstants.appVersion,
      buildNumber: AppConstants.buildNumber,
    );

    // 4. Initialize DatabaseService (Hive)
    final dbService = DatabaseService();
    Get.put(dbService, permanent: true);
    await dbService.init();

    // 5. Initialize Firebase Service safely
    final firebaseService = FirebaseService();
    Get.put(firebaseService, permanent: true);
    await firebaseService.init();

    logger.info('Bootstrap initialization complete.', tag: 'AppInitializer');
  }
}
