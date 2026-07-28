import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/services/database_service.dart';
import 'package:stream_hub/data/models/settings_model.dart';

class SettingsRepository extends GetxService {
  final DatabaseService _dbService = Get.find<DatabaseService>();
  final LoggingService _logger = Get.find<LoggingService>();

  Future<SettingsModel?> getSettings() async {
    try {
      final box = _dbService.settingsBox;
      final raw = box.get('settings');
      if (raw == null) return null;
      return SettingsModel(
        id: raw['id'] as String? ?? 'default',
        themeMode: raw['themeMode'] as String? ?? 'system',
        language: raw['language'] as String? ?? 'en',
        activeProfileId: raw['activeProfileId'] as String?,
        notificationsEnabled: raw['notificationsEnabled'] as bool? ?? true,
        parentalLockEnabled: raw['parentalLockEnabled'] as bool? ?? false,
        parentalPin: raw['parentalPin'] as String?,
        lastCacheClear: raw['lastCacheClear'] != null ? DateTime.fromMillisecondsSinceEpoch(raw['lastCacheClear'] as int) : null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(raw['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(raw['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      );
    } catch (e) {
      _logger.error('Failed to load settings', tag: 'SettingsRepository', error: e);
      throw DatabaseException(message: 'Failed to load settings', originalError: e);
    }
  }

  Future<SettingsModel> saveSettings(SettingsModel settings) async {
    try {
      final box = _dbService.settingsBox;
      await box.put('settings', {
        'id': settings.id,
        'themeMode': settings.themeMode,
        'language': settings.language,
        'activeProfileId': settings.activeProfileId,
        'notificationsEnabled': settings.notificationsEnabled,
        'parentalLockEnabled': settings.parentalLockEnabled,
        'parentalPin': settings.parentalPin,
        'lastCacheClear': settings.lastCacheClear?.millisecondsSinceEpoch,
        'createdAt': settings.createdAt.millisecondsSinceEpoch,
        'updatedAt': settings.updatedAt.millisecondsSinceEpoch,
      });
      return settings;
    } catch (e) {
      _logger.error('Failed to save settings', tag: 'SettingsRepository', error: e);
      throw DatabaseException(message: 'Failed to save settings', originalError: e);
    }
  }

  Future<void> updateThemeMode(String themeMode) async {
    try {
      final settings = await getSettings();
      if (settings == null) return;
      final updated = settings.copyWith(themeMode: themeMode, updatedAt: DateTime.now());
      await saveSettings(updated);
    } catch (e) {
      _logger.error('Failed to update theme mode', tag: 'SettingsRepository', error: e);
      rethrow;
    }
  }

  Future<void> updateLanguage(String language) async {
    try {
      final settings = await getSettings();
      if (settings == null) return;
      final updated = settings.copyWith(language: language, updatedAt: DateTime.now());
      await saveSettings(updated);
    } catch (e) {
      _logger.error('Failed to update language', tag: 'SettingsRepository', error: e);
      rethrow;
    }
  }

  Future<void> updateActiveProfileId(String? profileId) async {
    try {
      final settings = await getSettings();
      if (settings == null) return;
      final updated = settings.copyWith(activeProfileId: profileId, updatedAt: DateTime.now());
      await saveSettings(updated);
    } catch (e) {
      _logger.error('Failed to update active profile', tag: 'SettingsRepository', error: e);
      rethrow;
    }
  }

  Future<void> clearCacheTimestamp() async {
    try {
      final settings = await getSettings();
      if (settings == null) return;
      final updated = settings.copyWith(lastCacheClear: DateTime.now(), updatedAt: DateTime.now());
      await saveSettings(updated);
    } catch (e) {
      _logger.error('Failed to clear cache timestamp', tag: 'SettingsRepository', error: e);
      rethrow;
    }
  }

  Future<void> clearSettings() async {
    try {
      await _dbService.settingsBox.delete('settings');
    } catch (e) {
      _logger.error('Failed to clear settings', tag: 'SettingsRepository', error: e);
      throw DatabaseException(message: 'Failed to clear settings', originalError: e);
    }
  }
}
