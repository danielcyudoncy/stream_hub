import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/settings_model.dart';
import 'package:stream_hub/data/services/settings_service.dart';
import 'package:stream_hub/shared/dialogs/parental_pin_dialog.dart';

/// Service responsible for managing Parental Control enforcement, PIN hashing,
/// verification, and temporary grace-period sessions across playback and settings.
class ParentalControlService extends GetxService {
  final SettingsService? _settingsService;
  final LoggingService? _logger;
  final Duration gracePeriod;

  DateTime? _unlockedUntil;
  SettingsModel? _cachedSettings;

  final RxBool isParentalLockEnabledRx = false.obs;

  ParentalControlService({
    SettingsService? settingsService,
    LoggingService? logger,
    Duration? gracePeriod,
    SettingsModel? initialSettings,
  })  : _settingsService = settingsService ??
            (Get.isRegistered<SettingsService>()
                ? Get.find<SettingsService>()
                : null),
        _logger = logger ??
            (Get.isRegistered<LoggingService>()
                ? Get.find<LoggingService>()
                : null),
        gracePeriod = gracePeriod ?? const Duration(minutes: 5),
        _cachedSettings = initialSettings {
    if (initialSettings != null) {
      isParentalLockEnabledRx.value = initialSettings.parentalLockEnabled;
    }
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(refreshSettings());
  }

  /// Hashes a plaintext PIN using SHA-256 into a hexadecimal digest.
  /// PINs are never stored or compared in plaintext.
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
    return sha256.convert(bytes).toString();
  }

  /// Whether a valid hashed PIN is configured in settings.
  bool get hasPin {
    final pin = _cachedSettings?.parentalPin;
    return pin != null && pin.isNotEmpty;
  }

  /// Whether parental lock is currently configured and enabled in user settings.
  /// A lock is only considered active if both enabled flag is true AND a PIN exists.
  bool get isParentalLockEnabled {
    final enabled =
        _cachedSettings?.parentalLockEnabled ?? isParentalLockEnabledRx.value;
    return enabled && hasPin;
  }

  /// Whether the user is currently considered unlocked (lock is disabled OR
  /// authenticated within active grace period).
  bool get isUnlocked {
    if (!isParentalLockEnabled) return true;
    if (_unlockedUntil != null && DateTime.now().isBefore(_unlockedUntil!)) {
      return true;
    }
    return false;
  }

  /// Whether access is currently locked and requires a PIN challenge.
  bool get isLocked => !isUnlocked;

  /// Remaining duration of the active grace period, or null if locked.
  Duration? get remainingGracePeriod {
    if (_unlockedUntil == null) return null;
    final remaining = _unlockedUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Reloads settings from the underlying SettingsService.
  Future<SettingsModel?> refreshSettings() async {
    if (_settingsService == null) return _cachedSettings;
    try {
      final settings = await _settingsService.loadSettings();
      _cachedSettings = settings;
      isParentalLockEnabledRx.value = settings.parentalLockEnabled;
      return settings;
    } catch (e) {
      _logger?.error(
        'Failed to refresh parental control settings',
        tag: 'ParentalControlService',
        error: e,
      );
      return _cachedSettings;
    }
  }

  /// Validates a candidate PIN against the stored SHA-256 hash.
  /// If the PIN is correct, unlocks the service for the [gracePeriod] and returns `true`.
  Future<bool> validatePin(String pin) async {
    final settings = await refreshSettings();
    if (settings == null) {
      _logger?.warning(
        'Cannot validate PIN: Settings not loaded',
        tag: 'ParentalControlService',
      );
      return false;
    }

    final storedHash = settings.parentalPin;
    if (storedHash == null || storedHash.isEmpty) {
      _logger?.warning(
        'No parental PIN is currently set',
        tag: 'ParentalControlService',
      );
      return false;
    }

    final candidateHash = hashPin(pin);
    if (candidateHash == storedHash) {
      unlock();
      _logger?.info(
        'PIN successfully validated. Unlocked for $gracePeriod.',
        tag: 'ParentalControlService',
      );
      return true;
    }

    _logger?.warning(
      'Invalid PIN attempt.',
      tag: 'ParentalControlService',
    );
    return false;
  }

  /// Sets a new parental PIN (hashed with SHA-256) and enables parental lock.
  Future<bool> setPin(String newPin) async {
    if (newPin.trim().length != 4) {
      throw ArgumentError('Parental PIN must be exactly 4 digits');
    }
    final hashed = hashPin(newPin);
    try {
      await _settingsService?.updateParentalLock(
        enabled: true,
        hashedPin: hashed,
      );
      await refreshSettings();
      unlock();
      return true;
    } catch (e) {
      _logger?.error(
        'Failed to set parental PIN',
        tag: 'ParentalControlService',
        error: e,
      );
      return false;
    }
  }

  /// Changes the parental PIN. Requires the correct current PIN first.
  /// If no PIN is currently configured, allows setting the new PIN directly.
  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    if (!hasPin) {
      return setPin(newPin);
    }
    final isValid = await validatePin(currentPin);
    if (!isValid) return false;
    return setPin(newPin);
  }

  /// Enables parental lock using an existing or newly provided PIN.
  Future<bool> enableParentalLock(String pin) async {
    return setPin(pin);
  }

  /// Disables parental lock. Requires validating the current PIN first.
  /// If no PIN is configured, disables parental lock directly.
  Future<bool> disableParentalLock(String currentPin) async {
    if (!hasPin) {
      try {
        await _settingsService?.updateParentalLock(enabled: false);
        await refreshSettings();
        lock();
        return true;
      } catch (e) {
        return false;
      }
    }

    final isValid = await validatePin(currentPin);
    if (!isValid) return false;

    try {
      await _settingsService?.updateParentalLock(
        enabled: false,
      );
      await refreshSettings();
      lock();
      return true;
    } catch (e) {
      _logger?.error(
        'Failed to disable parental lock',
        tag: 'ParentalControlService',
        error: e,
      );
      return false;
    }
  }

  /// Relocks parental control immediately, clearing the active grace period.
  void lock() {
    _unlockedUntil = null;
    _logger?.info(
      'Parental control locked (grace period cleared).',
      tag: 'ParentalControlService',
    );
  }

  /// Unlocks parental control for the specified [duration] (defaults to [gracePeriod]).
  void unlock({Duration? duration}) {
    _unlockedUntil = DateTime.now().add(duration ?? gracePeriod);
  }

  /// Checks if a [MediaItem] has mature / adult content markers or ratings.
  /// When parental lock is enabled, this identifies content that must be gated.
  bool isContentRestricted(MediaItem? item) {
    if (item == null) return false;
    if (!isParentalLockEnabled) return false;

    final metadata = item.metadata;
    if (metadata['adult'] == true ||
        metadata['is_adult'] == true ||
        metadata['censored'] == true) {
      return true;
    }

    final ratingStr = (metadata['rating_mpaa'] ??
            metadata['mpaa'] ??
            metadata['age_rating'] ??
            metadata['censor_rating'] ??
            metadata['certification'])
        ?.toString()
        .toUpperCase()
        .trim();

    if (ratingStr != null && ratingStr.isNotEmpty) {
      const restrictedRatings = {
        'NC-17',
        'R',
        'TV-MA',
        '18+',
        'X',
        'XXX',
        'ADULT'
      };
      for (final r in restrictedRatings) {
        if (ratingStr.contains(r)) return true;
      }
    }

    const adultKeywords = [
      'adult',
      'xxx',
      'erotic',
      'erotica',
      'porn',
      '18+',
      'for adults',
    ];

    final genreText = item.genres.join(' ').toLowerCase();
    final categoryText =
        (metadata['category_name'] ?? metadata['category'] ?? '')
            .toString()
            .toLowerCase();
    final titleText = item.title.toLowerCase();

    for (final kw in adultKeywords) {
      if (genreText.contains(kw) ||
          categoryText.contains(kw) ||
          titleText.contains(kw)) {
        return true;
      }
    }

    return false;
  }

  /// Prompts the user with a PIN challenge dialog if parental lock is currently locked.
  /// Blocks until the user enters the correct PIN or cancels.
  /// Returns `true` if unlocked, or `false` if cancelled or denied.
  Future<bool> promptPinUnlock({
    BuildContext? context,
    String title = 'Parental Lock',
    String message = 'Enter your 4-digit PIN to proceed.',
  }) async {
    await refreshSettings();
    if (isUnlocked) return true;

    if (!hasPin) {
      _logger?.warning(
        'Parental lock was enabled without a PIN. Self-healing by disabling lock to prevent lockout.',
        tag: 'ParentalControlService',
      );
      await _settingsService?.updateParentalLock(enabled: false);
      await refreshSettings();
      return true;
    }

    if (context != null && !context.mounted) {
      return false;
    }

    final result = await ParentalPinDialog.showUnlockDialog(
      context: context,
      title: title,
      message: message,
      onValidate: (pin) async {
        return await validatePin(pin);
      },
    );

    return result == true;
  }
}
