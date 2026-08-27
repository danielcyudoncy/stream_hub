import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/playback_engine_preference.dart';
import 'package:stream_hub/core/media/player/player_settings.dart';
import 'package:stream_hub/core/media/repositories/playback_repository.dart';
import 'package:stream_hub/data/models/settings_model.dart';
import 'package:stream_hub/data/services/settings_service.dart';
import 'package:stream_hub/data/services/profile_service.dart';
import 'package:stream_hub/data/services/cache_service.dart';

class SettingsController extends GetxController {
  final SettingsService _settingsService;
  // ignore: unused_field
  final ProfileService _profileService;
  final CacheService _cacheService;
  final PlaybackRepository? _playbackRepository;
  // ignore: unused_field
  final LoggingService _logger = Get.find<LoggingService>();

  SettingsController({
    required SettingsService settingsService,
    required ProfileService profileService,
    required CacheService cacheService,
    PlaybackRepository? playbackRepository,
  }) : _settingsService = settingsService,
       _profileService = profileService,
       _cacheService = cacheService,
       _playbackRepository = playbackRepository;

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final RxString language = 'en'.obs;
  final RxBool notificationsEnabled = true.obs;
  final RxBool parentalLockEnabled = false.obs;
  final Rx<PlaybackEnginePreference> preferredPlayer =
      PlaybackEnginePreference.auto.obs;
  final RxInt bufferSizeSeconds = 30.obs;
  final RxBool autoplayNextEpisode = true.obs;
  final RxBool autoSkipIntro = false.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  SettingsModel? _settings;
  PlayerSettings? _playerSettings;

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

      await _loadPlayerSettings();
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

  Future<void> _loadPlayerSettings() async {
    final repository = _playbackRepository;
    if (repository == null) return;
    try {
      _playerSettings = await repository.getSettings();
      preferredPlayer.value =
          _playerSettings?.preferredPlayer ?? PlaybackEnginePreference.auto;
      bufferSizeSeconds.value =
          _playerSettings?.bufferSizeSeconds ?? 30;
      autoplayNextEpisode.value =
          _playerSettings?.autoplayNextEpisode ?? true;
      autoSkipIntro.value =
          _playerSettings?.autoSkipIntro ?? false;
    } catch (e) {
      _logger.warning(
        'Failed to load player settings',
        tag: 'SettingsController',
        error: e,
      );
    }
  }

  Future<void> changeBufferSize(int seconds) async {
    final repository = _playbackRepository;
    if (repository == null) return;
    try {
      bufferSizeSeconds.value = seconds;
      final base = _playerSettings ?? const PlayerSettings();
      final updated = base.copyWith(bufferSizeSeconds: seconds);
      await repository.updateSettings(updated);
      _playerSettings = updated;
    } catch (_) {}
  }

  Future<void> toggleAutoplayNextEpisode(bool value) async {
    final repository = _playbackRepository;
    if (repository == null) return;
    try {
      autoplayNextEpisode.value = value;
      final base = _playerSettings ?? const PlayerSettings();
      final updated = base.copyWith(autoplayNextEpisode: value);
      await repository.updateSettings(updated);
      _playerSettings = updated;
    } catch (_) {}
  }

  Future<void> toggleAutoSkipIntro(bool value) async {
    final repository = _playbackRepository;
    if (repository == null) return;
    try {
      autoSkipIntro.value = value;
      final base = _playerSettings ?? const PlayerSettings();
      final updated = base.copyWith(autoSkipIntro: value);
      await repository.updateSettings(updated);
      _playerSettings = updated;
    } catch (_) {}
  }

  Future<void> changePreferredPlayer(PlaybackEnginePreference preference) async {
    if (isLoading.value) return;
    final repository = _playbackRepository;
    if (repository == null) return;
    try {
      isLoading.value = true;
      errorMessage.value = '';
      preferredPlayer.value = preference;
      final base = _playerSettings ?? const PlayerSettings();
      final updated = base.copyWith(preferredPlayer: preference);
      await repository.updateSettings(updated);
      _playerSettings = updated;
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to update playback engine preference.';
    } finally {
      isLoading.value = false;
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
