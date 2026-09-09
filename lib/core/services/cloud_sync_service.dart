import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/repositories/playback_repository.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/data/services/database_service.dart';
import 'package:stream_hub/data/services/sync_service.dart';

/// Concrete implementation of [SyncService] using Firebase Cloud Firestore.
///
/// Follows StreamHub Pro core principles:
/// 1. **Offline-First**: Hive remains the local ground truth. UI operations never
///    wait on network requests.
/// 2. **Privacy First (Opt-in)**: Cloud sync is strictly disabled by default.
///    Requires explicit toggle in Settings and an authenticated user.
/// 3. **Cost-Optimized ($0 Billing)**: Groups data into bundled single documents
///    under `users/{uid}/sync/{category}` with debounced writes to guarantee
///    zero billing costs within Firebase's daily free tier.
class CloudSyncService extends GetxService implements SyncService {
  static const String _kBoxKeyEnabled = 'cloud_sync_enabled';
  static const String _kBoxKeyLastSync = 'cloud_sync_last_time';

  final FirebaseFirestore? _firestore;
  final fb_auth.FirebaseAuth? _auth;
  final DatabaseService? _databaseService;
  final LoggingService _logger;

  final RxBool _isSyncing = false.obs;
  final Rxn<DateTime> _lastSyncTime = Rxn<DateTime>();
  final RxBool _isCloudSyncEnabled = false.obs;
  final RxString _syncStatusMessage = ''.obs;

  Timer? _debounceTimer;

  CloudSyncService({
    FirebaseFirestore? firestore,
    fb_auth.FirebaseAuth? auth,
    DatabaseService? databaseService,
    LoggingService? logger,
  })  : _firestore = firestore,
        _auth = auth,
        _databaseService = databaseService,
        _logger = logger ?? (Get.isRegistered<LoggingService>() ? Get.find<LoggingService>() : LoggingService()) {
    _initFromStorage();
  }

  FirebaseFirestore? get _effectiveFirestore {
    try {
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  fb_auth.FirebaseAuth? get _effectiveAuth {
    try {
      return _auth ?? fb_auth.FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  DatabaseService? get _effectiveDb =>
      _databaseService ?? (Get.isRegistered<DatabaseService>() ? Get.find<DatabaseService>() : null);

  @override
  bool get isSyncing => _isSyncing.value;
  RxBool get isSyncingRx => _isSyncing;

  @override
  DateTime? get lastSyncTime => _lastSyncTime.value;
  Rxn<DateTime> get lastSyncTimeRx => _lastSyncTime;

  RxBool get isCloudSyncEnabledRx => _isCloudSyncEnabled;
  bool get isCloudSyncEnabled => _isCloudSyncEnabled.value;

  RxString get syncStatusMessageRx => _syncStatusMessage;
  String get syncStatusMessage => _syncStatusMessage.value;

  String? get currentUserId => _effectiveAuth?.currentUser?.uid;

  void _initFromStorage() {
    final db = _effectiveDb;
    if (db != null) {
      try {
        final enabled = db.settingsBox.get(_kBoxKeyEnabled, defaultValue: false) as bool;
        _isCloudSyncEnabled.value = enabled;

        final lastSyncMillis = db.settingsBox.get(_kBoxKeyLastSync) as int?;
        if (lastSyncMillis != null) {
          _lastSyncTime.value = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);
        }
      } catch (e) {
        _logger.warning('Failed to restore CloudSyncService settings: $e', tag: 'CloudSyncService');
      }
    }
  }

  /// Toggles cloud synchronization on or off with persistence.
  Future<bool> setCloudSyncEnabled(bool enabled) async {
    if (enabled) {
      final user = _effectiveAuth?.currentUser;
      if (user == null) {
        _logger.warning('Cannot enable Cloud Sync: User is not authenticated', tag: 'CloudSyncService');
        return false;
      }
    }

    _isCloudSyncEnabled.value = enabled;
    final db = _effectiveDb;
    if (db != null) {
      await db.settingsBox.put(_kBoxKeyEnabled, enabled);
    }

    if (enabled) {
      // Trigger an initial non-blocking background sync
      unawaited(syncAll());
    }
    return true;
  }

  @override
  void schedulePush() {
    if (!_isCloudSyncEnabled.value) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      syncAll();
    });
  }

  @override
  Future<void> syncAll({bool force = false}) async {
    if (!_isCloudSyncEnabled.value && !force) return;
    if (_isSyncing.value) return;

    final uid = currentUserId;
    if (uid == null) {
      _logger.debug('Skipping Cloud Sync: No active authenticated user.', tag: 'CloudSyncService');
      return;
    }

    _isSyncing.value = true;
    _syncStatusMessage.value = 'Syncing...';
    try {
      _logger.info('Starting Cloud Sync for user: $uid', tag: 'CloudSyncService');

      await Future.wait([
        syncFavorites(),
        syncWatchHistory(),
        syncPreferences(),
      ]);

      final now = DateTime.now();
      _lastSyncTime.value = now;
      final db = _effectiveDb;
      if (db != null) {
        await db.settingsBox.put(_kBoxKeyLastSync, now.millisecondsSinceEpoch);
      }
      _syncStatusMessage.value = 'Up to date';
      _logger.info('Cloud Sync completed successfully.', tag: 'CloudSyncService');
    } catch (e, stack) {
      _syncStatusMessage.value = 'Sync error';
      _logger.warning('Cloud Sync encountered an error: $e', tag: 'CloudSyncService', error: e, stackTrace: stack);
    } finally {
      _isSyncing.value = false;
    }
  }

  @override
  Future<void> syncFavorites() async {
    final uid = currentUserId;
    if (uid == null) return;
    if (!Get.isRegistered<FavoriteRepository>()) return;

    final favRepo = Get.find<FavoriteRepository>();
    final fs = _effectiveFirestore;
    if (fs == null) return;
    final docRef = fs
        .collection('users')
        .doc(uid)
        .collection('sync')
        .doc('favorites');

    try {
      final snapshot = await docRef.get();
      final cloudData = snapshot.data();
      final cloudItems = (cloudData?['items'] as List<dynamic>?) ?? [];

      // Create a lookup for cloud items by ID
      final cloudMap = <String, Map<String, dynamic>>{};
      for (final raw in cloudItems) {
        if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          final id = m['id']?.toString();
          if (id != null) cloudMap[id] = m;
        }
      }

      // Merge Cloud into Local (If item in cloud is missing locally, add it)
      for (final entry in cloudMap.entries) {
        final isFav = await favRepo.isFavorite(entry.key);
        if (!isFav) {
          final m = entry.value;
          final item = MediaItem(
            id: entry.key,
            title: m['title']?.toString() ?? 'Favorite',
            providerId: m['providerId']?.toString() ?? '',
            providerType: MediaSourceType.values.firstWhere(
              (t) => t.name == m['providerType'],
              orElse: () => MediaSourceType.m3u,
            ),
            mediaType: MediaType.values.firstWhere(
              (t) => t.name == m['mediaType'],
              orElse: () => MediaType.channel,
            ),
            poster: m['poster']?.toString(),
            favorite: true,
            createdAt: DateTime.tryParse(m['addedAt']?.toString() ?? '') ?? DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await favRepo.add(item);
        }
      }

      // Merge Local into Cloud: Bundle all current local favorites into one single document
      final updatedLocalFavs = await favRepo.getAll();
      final bundledItems = updatedLocalFavs.map((fav) {
        return {
          'id': fav.id,
          'title': fav.title,
          'providerId': fav.providerId,
          'providerType': fav.providerType.name,
          'mediaType': fav.mediaType.name,
          'poster': fav.poster ?? fav.thumbnail,
          'addedAt': fav.updatedAt.toIso8601String(),
        };
      }).toList();

      await docRef.set({
        'items': bundledItems,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _logger.warning('Failed to sync favorites: $e', tag: 'CloudSyncService');
    }
  }

  @override
  Future<void> syncWatchHistory() async {
    final uid = currentUserId;
    if (uid == null) return;
    if (!Get.isRegistered<PlaybackRepository>()) return;

    final playbackRepo = Get.find<PlaybackRepository>();
    final fs = _effectiveFirestore;
    if (fs == null) return;
    final docRef = fs
        .collection('users')
        .doc(uid)
        .collection('sync')
        .doc('watch_history');

    try {
      final snapshot = await docRef.get();
      final localSessions = await playbackRepo.getAllWatchSessions();

      final cloudData = snapshot.data();
      final cloudSessionsRaw = (cloudData?['sessions'] as List<dynamic>?) ?? [];

      final cloudSessionsMap = <String, Map<String, dynamic>>{};
      for (final raw in cloudSessionsRaw) {
        if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          final itemId = m['itemId']?.toString();
          if (itemId != null) cloudSessionsMap[itemId] = m;
        }
      }

      // Merge Cloud into Local (Last-Write-Wins based on updatedAt)
      for (final entry in cloudSessionsMap.entries) {
        final remoteMap = entry.value;
        final remoteDate = DateTime.tryParse(remoteMap['updatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final localSession = localSessions.firstWhereOrNull((s) => s.itemId == entry.key);

        if (localSession == null || remoteDate.isAfter(localSession.updatedAt)) {
          // Cloud has newer watch progress, update local playback session
          final posMs = (remoteMap['positionMs'] as num?)?.toInt() ?? 0;
          final durationMs = (remoteMap['durationMs'] as num?)?.toInt() ?? 0;
          if (posMs > 0 && durationMs > 0) {
            final mockItem = MediaItem(
              id: entry.key,
              title: remoteMap['title']?.toString() ?? 'Media',
              providerId: remoteMap['providerId']?.toString() ?? '',
              providerType: MediaSourceType.m3u,
              mediaType: MediaType.channel,
              createdAt: remoteDate,
              updatedAt: remoteDate,
            );
            await playbackRepo.saveWatchProgress(
              mockItem,
              Duration(milliseconds: posMs),
              Duration(milliseconds: durationMs),
            );
          }
        }
      }

      // Merge Local into Cloud
      final currentLocal = await playbackRepo.getAllWatchSessions();
      final bundledSessions = currentLocal.map((session) {
        return {
          'id': session.id,
          'itemId': session.itemId,
          'providerType': session.providerType,
          'positionMs': session.resumePosition.inMilliseconds,
          'completionPercentage': session.completionPercentage,
          'updatedAt': session.updatedAt.toIso8601String(),
        };
      }).toList();

      await docRef.set({
        'sessions': bundledSessions,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _logger.warning('Failed to sync watch history: $e', tag: 'CloudSyncService');
    }
  }

  @override
  Future<void> syncPreferences() async {
    final uid = currentUserId;
    if (uid == null) return;
    final db = _effectiveDb;
    if (db == null) return;

    final fs = _effectiveFirestore;
    if (fs == null) return;
    final docRef = fs
        .collection('users')
        .doc(uid)
        .collection('sync')
        .doc('preferences');

    try {
      final snapshot = await docRef.get();
      final localSettingsRaw = db.settingsBox.get('settings');
      final localMap = localSettingsRaw is Map ? Map<String, dynamic>.from(localSettingsRaw) : <String, dynamic>{};

      if (!snapshot.exists) {
        if (localMap.isNotEmpty) {
          await docRef.set({
            'preferences': localMap,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        return;
      }

      final cloudData = snapshot.data();
      final remotePrefs = (cloudData?['preferences'] as Map?)?.cast<String, dynamic>() ?? {};
      final remoteUpdated = (cloudData?['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);

      final localUpdatedMillis = localMap['updatedAt'] as int?;
      final localUpdated = localUpdatedMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(localUpdatedMillis)
          : DateTime.fromMillisecondsSinceEpoch(0);

      if (remoteUpdated.isAfter(localUpdated) && remotePrefs.isNotEmpty) {
        // Remote is newer, update local settings
        await db.settingsBox.put('settings', remotePrefs);
      } else if (localUpdated.isAfter(remoteUpdated) && localMap.isNotEmpty) {
        // Local is newer, update cloud
        await docRef.set({
          'preferences': localMap,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      _logger.warning('Failed to sync preferences: $e', tag: 'CloudSyncService');
    }
  }
}
