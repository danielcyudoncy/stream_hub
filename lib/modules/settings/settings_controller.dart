import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/settings_model.dart';
import 'package:stream_hub/data/services/settings_service.dart';
import 'package:stream_hub/data/services/profile_service.dart';
import 'package:stream_hub/data/services/cache_service.dart';

class SettingsController extends GetxController {
  final SettingsService _settingsService;
  // ignore: unused_field
  final ProfileService _profileService;
  final CacheService _cacheService;
  // ignore: unused_field
  final LoggingService _logger = Get.find<LoggingService>();

  SettingsController({
    required SettingsService settingsService,
    required ProfileService profileService,
    required CacheService cacheService,
  }) : _settingsService = settingsService,
       _profileService = profileService,
       _cacheService = cacheService;

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final RxString language = 'en'.obs;
  final RxBool notificationsEnabled = true.obs;
  final RxBool parentalLockEnabled = false.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  SettingsModel? _settings;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      _settings = await _settingsService.loadSettings();

      final savedTheme = _settings?.themeMode ?? 'system';
      themeMode.value = _resolveThemeMode(savedTheme);

      language.value = _settings?.language ?? 'en';
      notificationsEnabled.value = _settings?.notificationsEnabled ?? true;
      parentalLockEnabled.value = _settings?.parentalLockEnabled ?? false;
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to load settings.';
    } finally {
      isLoading.value = false;
    }
  }

  ThemeMode _resolveThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }

  Future<void> changeThemeMode(ThemeMode mode) async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      errorMessage.value = '';
      themeMode.value = mode;
      Get.changeThemeMode(mode);
      await _settingsService.updateThemeMode(_themeModeToString(mode));
      await _persistSettings();
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to update theme mode.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> changeLanguage(String langCode) async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      errorMessage.value = '';
      language.value = langCode;
      await _settingsService.updateLanguage(langCode);
      await _persistSettings();
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to update language.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleNotifications(bool value) async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      notificationsEnabled.value = value;
      await _persistSettings();
    } catch (e) {
      errorMessage.value = 'Failed to update notification settings.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleParentalLock(bool value) async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      parentalLockEnabled.value = value;
      await _persistSettings();
    } catch (e) {
      errorMessage.value = 'Failed to update parental lock settings.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> clearCache() async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _cacheService.clearCache();
      Get.snackbar(
        'Cache Cleared',
        'Offline cache has been cleared successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.surfaceContainerHighest,
        colorText: Get.theme.colorScheme.onSurface,
      );
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to clear cache.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      errorMessage.value = '';
      Get.offAllNamed('/login');
    } catch (e) {
      errorMessage.value = 'Failed to log out.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> navigateToProfile() async {
    Get.toNamed('/profile');
  }

  void clearError() {
    errorMessage.value = '';
  }

  Future<void> _persistSettings() async {
    if (_settings == null) return;
    final updated = _settings!.copyWith(
      themeMode: _themeModeToString(themeMode.value),
      language: language.value,
      notificationsEnabled: notificationsEnabled.value,
      parentalLockEnabled: parentalLockEnabled.value,
      updatedAt: DateTime.now(),
    );
    await _settingsService.saveSettings(updated);
    _settings = updated;
  }
}
