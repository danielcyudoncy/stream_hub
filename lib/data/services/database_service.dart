import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/logging/logging_service.dart';

class DatabaseService extends GetxService {
  final LoggingService _logger = Get.find<LoggingService>();

  late Box settingsBox;
  late Box providersBox;
  late Box favoritesBox;
  late Box historyBox;
  late Box profilesBox;
  late Box downloadsBox;
  late Box watchProgressBox;
  late Box recentSearchesBox;

  Future<DatabaseService> init() async {
    _logger.info('Initializing Hive Database...', tag: 'DatabaseService');
    try {
      await Hive.initFlutter();
      
      // Open all core boxes
      settingsBox = await _openBoxSafe(AppConstants.boxSettings);
      providersBox = await _openBoxSafe(AppConstants.boxProviders);
      favoritesBox = await _openBoxSafe(AppConstants.boxFavorites);
      historyBox = await _openBoxSafe(AppConstants.boxHistory);
      profilesBox = await _openBoxSafe(AppConstants.boxProfiles);
      downloadsBox = await _openBoxSafe(AppConstants.boxDownloads);
      watchProgressBox = await _openBoxSafe(AppConstants.boxWatchProgress);
      recentSearchesBox = await _openBoxSafe(AppConstants.boxRecentSearches);
      
      _logger.info('Hive Database successfully initialized.', tag: 'DatabaseService');
    } catch (e) {
      _logger.error('Hive Database initialization failed.', tag: 'DatabaseService', error: e);
      rethrow;
    }
    return this;
  }

  Future<Box> _openBoxSafe(String name) async {
    try {
      return await Hive.openBox(name);
    } catch (e) {
      _logger.warning('Failed to open box: $name. Attempting recovery...', tag: 'DatabaseService', error: e);
      // Delete old box and recreate in case of corruption
      await Hive.deleteBoxFromDisk(name);
      return await Hive.openBox(name);
    }
  }
}
