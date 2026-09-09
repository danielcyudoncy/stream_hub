import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/services/database_service.dart';

/// Singleton GetxService that holds the currently active profile ID and
/// broadcasts changes to any service that depends on it.
///
/// This is the single source of truth for "which profile is active right now".
/// [FavoriteService], [PlaybackLocalService], and [HistoryService] observe
/// [profileId] to reload their in-memory caches whenever the user switches
/// profiles.
///
/// On first startup [profileId] is restored from the settings Hive box.
/// When no profile has been selected [profileId] is an empty string, which
/// causes [ProfileKeyHelper] to use bare (unscoped) keys — preserving
/// backward-compatibility with existing data.
class ActiveProfileService extends GetxService {
  final LoggingService _logger = Get.find<LoggingService>();

  /// The currently active profile ID.  Empty string = no profile / default.
  final RxString profileId = ''.obs;

  /// Convenience getter.
  String get currentProfileId => profileId.value;

  /// Returns `true` when a named profile is selected.
  bool get hasActiveProfile => profileId.value.isNotEmpty;

  /// Initialise by reading the persisted profile from the settings box.
  Future<ActiveProfileService> init() async {
    try {
      final db = Get.find<DatabaseService>();
      final raw = db.settingsBox.get('settings');
      if (raw is Map) {
        final persisted = raw['activeProfileId'] as String?;
        if (persisted != null && persisted.isNotEmpty) {
          profileId.value = persisted;
          _logger.info(
            'ActiveProfileService: restored profile "$persisted"',
            tag: 'ActiveProfileService',
          );
        }
      }
    } catch (e) {
      _logger.warning(
        'ActiveProfileService: could not restore active profile',
        tag: 'ActiveProfileService',
        error: e,
      );
    }
    return this;
  }

  /// Switch to [id].  Passing an empty string reverts to the default scope.
  void setActiveProfile(String id) {
    if (profileId.value == id) return;
    profileId.value = id;
    _logger.info(
      'ActiveProfileService: switched to profile "$id"',
      tag: 'ActiveProfileService',
    );
  }

  /// Clear the active profile selection.
  void clearActiveProfile() => setActiveProfile('');
}
