import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/logging/logging_service.dart';
import '../../data/services/database_service.dart';

class SettingsController extends GetxController {
  final DatabaseService _dbService = Get.find<DatabaseService>();
  final LoggingService _logger = Get.find<LoggingService>();

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final RxString language = 'en'.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  void _loadSettings() {
    try {
      final savedTheme = _dbService.settingsBox.get(AppConstants.keyThemeMode);
      if (savedTheme != null) {
        themeMode.value = ThemeMode.values.firstWhere(
          (e) => e.name == savedTheme,
          orElse: () => ThemeMode.system,
        );
      }

      final savedLang = _dbService.settingsBox.get(AppConstants.keyLanguage);
      if (savedLang != null) {
        language.value = savedLang;
      }
    } catch (e) {
      _logger.error('Failed to load settings', tag: 'SettingsController', error: e);
    }
  }

  Future<void> changeThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    Get.changeThemeMode(mode);
    await _dbService.settingsBox.put(AppConstants.keyThemeMode, mode.name);
  }

  Future<void> changeLanguage(String langCode) async {
    language.value = langCode;
    // Get.updateLocale(Locale(langCode));
    await _dbService.settingsBox.put(AppConstants.keyLanguage, langCode);
  }
}
