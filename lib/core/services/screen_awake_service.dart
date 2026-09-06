import 'package:wakelock_plus/wakelock_plus.dart';

import '../logging/logging_service.dart';

/// Controls the OS screen-awake (wakelock) state.
///
/// Keeps the device screen on while a video is being watched so the system
/// screen timeout does not interrupt playback. Delegates to [WakelockPlus],
/// which handles Android, iOS, macOS, Windows, Linux and web.
///
/// The service is reference-counted so that several simultaneously active
/// players (movie + mini-player, picture-in-picture, etc.) can each request
/// the wake lock without one teardown releasing it while another is still
/// playing.
///
/// The service intentionally surfaces every platform failure through the
/// [LoggingService] so that the failing stage is identifiable in diagnostics
/// — silently swallowing errors was the root cause of the screen-turns-off
/// during movie playback bug. Callers should consult [isActive] after
/// [acquire] to confirm the lock actually engaged.
class ScreenAwakeService {
  ScreenAwakeService({LoggingService? logger}) : _logger = logger;

  final LoggingService? _logger;

  int _refCount = 0;
  bool _wakelockActive = false;
  bool _lastAcquireFailed = false;

  /// Whether the wake lock is currently held at the OS level. Independent of
  /// the reference count, which may temporarily drop to zero while another
  /// caller still owns a logical claim that is being released.
  bool get isActive => _wakelockActive;

  /// The most recent attempt to engage the wake lock failed. Resets on the
  /// next successful acquire or release.
  bool get lastAcquireFailed => _lastAcquireFailed;

  /// Increments the reference count and, on the first claim, enables the
  /// OS wake lock. Returns `true` when the wake lock is guaranteed active
  /// after this call; `false` when the platform rejected the request (and
  /// the caller should fall back to a widget-level keep-screen-on).
  Future<bool> acquire({String? owner}) async {
    _refCount++;
    if (_refCount == 1) {
      final ok = await _enablePlatformWakelock(owner: owner);
      _wakelockActive = ok;
      _lastAcquireFailed = !ok;
      return ok;
    }
    return _wakelockActive;
  }

  /// Decrements the reference count and, when it reaches zero, releases
  /// the OS wake lock. Safe to call more times than [acquire] — extra
  /// decrements are ignored and logged.
  Future<void> release({String? owner}) async {
    if (_refCount <= 0) {
      _logger?.warning(
        'release() called with no outstanding acquire() (owner=$owner)',
        tag: 'ScreenAwake',
      );
      _refCount = 0;
      return;
    }
    _refCount--;
    if (_refCount == 0) {
      await _disablePlatformWakelock(owner: owner);
      _wakelockActive = false;
    }
  }

  /// Convenience for callers that want to drive the lock from a single
  /// boolean (e.g. "should we be keeping the screen on right now?").
  /// Maintains an internal reference count so callers do not need to track
  /// their own paired acquire/release calls.
  Future<void> setEnabled(bool enabled, {String? owner}) async {
    final delta = enabled ? 1 : -1;
    if (delta == 1) {
      await acquire(owner: owner);
    } else if (delta == -1) {
      await release(owner: owner);
    }
  }

  /// Prevents the screen from timing out while the player is active.
  /// Kept for backwards compatibility with code paths that expected the
  /// original fire-and-forget API; new code should prefer [acquire].
  Future<bool> keepScreenOn({String? owner}) => acquire(owner: owner);

  /// Restores default screen timeout behavior. Kept for backwards
  /// compatibility — new code should prefer [release].
  Future<void> allowScreenOff({String? owner}) => release(owner: owner);

  Future<bool> _enablePlatformWakelock({String? owner}) async {
    try {
      await WakelockPlus.enable();
      _logger?.debug(
        'Screen wake lock enabled (owner=$owner)',
        tag: 'ScreenAwake',
      );
      return true;
    } catch (error, stack) {
      _logger?.error(
        'Failed to enable screen wake lock (owner=$owner)',
        tag: 'ScreenAwake',
        error: error,
        stackTrace: stack,
      );
      return false;
    }
  }

  Future<void> _disablePlatformWakelock({String? owner}) async {
    try {
      await WakelockPlus.disable();
      _logger?.debug(
        'Screen wake lock disabled (owner=$owner)',
        tag: 'ScreenAwake',
      );
    } catch (error, stack) {
      _logger?.error(
        'Failed to disable screen wake lock (owner=$owner)',
        tag: 'ScreenAwake',
        error: error,
        stackTrace: stack,
      );
    }
  }
}