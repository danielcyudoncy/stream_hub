import 'dart:async';

/// Abstract contract for cross-device cloud synchronization
/// (Favorites, Watch History / Continue Watching, Preferences).
abstract class SyncService {
  /// Whether a sync operation is currently executing.
  bool get isSyncing;

  /// Timestamp of the last successful synchronization.
  DateTime? get lastSyncTime;

  /// Manually triggers a full synchronization of all user data.
  Future<void> syncAll({bool force = false});

  /// Synchronizes favorite items between local Hive and cloud storage.
  Future<void> syncFavorites();

  /// Synchronizes watch progress and playback sessions.
  Future<void> syncWatchHistory();

  /// Synchronizes user preferences and configuration.
  Future<void> syncPreferences();

  /// Schedules a debounced background push of local changes to the cloud.
  void schedulePush();
}
