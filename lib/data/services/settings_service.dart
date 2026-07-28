import 'package:get/get.dart';
import '../../../core/logging/logging_service.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/repositories/settings_repository.dart';

class SettingsService extends GetxService {
  final SettingsRepository _repository;
  final LoggingService _logger = Get.find<LoggingService>();

  SettingsService(this._repository);

  Future<SettingsModel> loadSettings() async {
    try {
      final settings = await _repository.getSettings();
      if (settings != null) return settings;
      final now = DateTime.now();
      return SettingsModel(
        id: 'default',
        themeMode: 'system',
        language: 'en',
        notificationsEnabled: true,
        parentalLockEnabled: false,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e) {
      _logger.error('SettingsService: failed to load settings', tag: 'SettingsService', error: e);
      rethrow;
    }
  }

  Future<void> saveSettings(SettingsModel settings) async {
    try {
      await _repository.saveSettings(settings);
    } catch (e) {
      _logger.error('SettingsService: failed to save settings', tag: 'SettingsService', error: e);
      rethrow;
    }
  }

  Future<void> updateThemeMode(String themeMode) async {
    try {
      await _repository.updateThemeMode(themeMode);
    } catch (e) {
      _logger.error('SettingsService: failed to update theme mode', tag: 'SettingsService', error: e);
      rethrow;
    }
  }

  Future<void> updateLanguage(String language) async {
    try {
      await _repository.updateLanguage(language);
    } catch (e) {
      _logger.error('SettingsService: failed to update language', tag: 'SettingsService', error: e);
      rethrow;
    }
  }

  Future<void> updateActiveProfileId(String? profileId) async {
    try {
      await _repository.updateActiveProfileId(profileId);
    } catch (e) {
      _logger.error('SettingsService: failed to update active profile', tag: 'SettingsService', error: e);
      rethrow;
    }
  }

  Future<void> clearCacheTimestamp() async {
    try {
      await _repository.clearCacheTimestamp();
    } catch (e) {
      _logger.error('SettingsService: failed to clear cache timestamp', tag: 'SettingsService', error: e);
      rethrow;
    }
  }
}