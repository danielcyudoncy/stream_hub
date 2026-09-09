import 'dart:async';
import 'package:flutter/services.dart';
import '../helpers/platform_helper.dart';
import '../logging/logging_service.dart';

/// Cross-platform service to interact directly with hardware device controls
/// (Window screen backlight brightness and Master Media Volume).
///
/// Designed to connect with [PlayerTouchGestureOverlay] across all player types.
class DeviceEnvironmentService {
  static const MethodChannel _channel =
      MethodChannel('stream_hub/device_controls');

  static final DeviceEnvironmentService _instance =
      DeviceEnvironmentService._internal();

  factory DeviceEnvironmentService() => _instance;

  DeviceEnvironmentService._internal();

  final LoggingService _logger = LoggingService();

  int _brightnessClaimCount = 0;
  double? _cachedVolume;
  double? _cachedBrightness;

  /// Retrieves the current system media volume ratio (0.0 to 1.0), or null if unsupported.
  Future<double?> getVolume() async {
    if (PlatformHelper.isAndroid) {
      try {
        final vol = await _channel.invokeMethod<double>('getVolume');
        if (vol != null) {
          _cachedVolume = vol.clamp(0.0, 1.0);
          return _cachedVolume;
        }
      } catch (e) {
        _logger.debug('Failed to get device volume: $e', tag: 'DeviceEnvironment');
      }
    }
    return _cachedVolume;
  }

  /// Sets the hardware master media volume ratio (0.0 to 1.0).
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    _cachedVolume = clamped;
    if (PlatformHelper.isAndroid) {
      try {
        await _channel.invokeMethod<bool>('setVolume', {'volume': clamped});
      } catch (e) {
        _logger.debug('Failed to set device volume: $e', tag: 'DeviceEnvironment');
      }
    }
  }

  /// Retrieves the current window/screen brightness (0.01 to 1.0), or null if unsupported.
  Future<double?> getBrightness() async {
    if (PlatformHelper.isAndroid) {
      try {
        final brightness = await _channel.invokeMethod<double>('getBrightness');
        if (brightness != null) {
          _cachedBrightness = brightness.clamp(0.01, 1.0);
          return _cachedBrightness;
        }
      } catch (e) {
        _logger.debug('Failed to get screen brightness: $e', tag: 'DeviceEnvironment');
      }
    }
    return _cachedBrightness;
  }

  /// Resets cached state and claims for test isolation.
  void resetForTesting() {
    _brightnessClaimCount = 0;
    _cachedVolume = null;
    _cachedBrightness = null;
  }

  /// Sets the window screen backlight brightness (0.01 to 1.0).
  ///
  /// Increments an active claim counter so multiple players (e.g. inline transitioning
  /// to fullscreen) maintain brightness until all have exited.
  Future<void> setBrightness(double brightness) async {
    final clamped = brightness.clamp(0.01, 1.0);
    _cachedBrightness = clamped;
    if (PlatformHelper.isAndroid) {
      try {
        await _channel.invokeMethod<bool>('setBrightness', {'brightness': clamped});
      } catch (e) {
        _logger.debug('Failed to set screen brightness: $e', tag: 'DeviceEnvironment');
      }
    }
  }

  /// Registers an active player using brightness gestures.
  void acquireBrightnessClaim() {
    _brightnessClaimCount++;
  }

  /// Releases a player claim. When count reaches zero, restores system default screen brightness.
  Future<void> releaseBrightnessClaim() async {
    if (_brightnessClaimCount > 0) {
      _brightnessClaimCount--;
    }
    if (_brightnessClaimCount == 0) {
      await restoreBrightness();
    }
  }

  /// Restores system default brightness behavior.
  Future<void> restoreBrightness() async {
    if (PlatformHelper.isAndroid) {
      try {
        await _channel.invokeMethod<bool>('restoreBrightness');
      } catch (e) {
        _logger.debug('Failed to restore screen brightness: $e', tag: 'DeviceEnvironment');
      }
    }
  }
}
