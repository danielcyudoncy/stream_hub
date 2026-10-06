import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/services/database_service.dart';
import 'package:stream_hub/data/repositories/profile_repository.dart';

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

  /// The currently active profile display name.
  final RxString activeDisplayName = ''.obs;

  /// The currently active profile avatar/photo URL or preset index.
  final RxString activePhotoUrl = ''.obs;

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

      if (Get.isRegistered<ProfileRepository>()) {
        final repo = Get.find<ProfileRepository>();
        final allProfiles = await repo.getAllProfiles();
        if (allProfiles.isNotEmpty) {
          final matched = (profileId.value.isNotEmpty)
              ? allProfiles.firstWhereOrNull((p) => p.id == profileId.value) ??
                  allProfiles.first
              : allProfiles.first;
          profileId.value = matched.id;
          activeDisplayName.value = matched.displayName;
          activePhotoUrl.value = matched.photoUrl ?? '';
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

  /// Switch to [id] and optionally update in-memory display metadata.
  /// Passing an empty string reverts to the default scope.
  void setActiveProfile(String id, {String? displayName, String? photoUrl}) {
    final changed = profileId.value != id ||
        (displayName != null && activeDisplayName.value != displayName) ||
        (photoUrl != null && activePhotoUrl.value != photoUrl);

    if (!changed) return;

    profileId.value = id;
    if (displayName != null) activeDisplayName.value = displayName;
    if (photoUrl != null) activePhotoUrl.value = photoUrl;

    _logger.info(
      'ActiveProfileService: switched to profile "$id" (${activeDisplayName.value})',
      tag: 'ActiveProfileService',
    );
  }

  /// Update the active profile display metadata.
  void updateActiveProfileInfo({required String displayName, String? photoUrl}) {
    activeDisplayName.value = displayName;
    if (photoUrl != null) activePhotoUrl.value = photoUrl;
  }

  /// Clear the active profile selection.
  void clearActiveProfile() {
    setActiveProfile('');
    activeDisplayName.value = '';
    activePhotoUrl.value = '';
  }

  /// Syncs authenticated user profile metadata (e.g. from Google Sign-In)
  /// with the active profile in local storage and memory if using default values.
  Future<void> syncWithAuthenticatedUser({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final validName = displayName?.trim();
      final validPhoto = photoUrl?.trim();
      final hasName = validName != null && validName.isNotEmpty;
      final hasPhoto = validPhoto != null && validPhoto.isNotEmpty;

      if (!hasName && !hasPhoto) return;

      if (Get.isRegistered<ProfileRepository>()) {
        final repo = Get.find<ProfileRepository>();
        final allProfiles = await repo.getAllProfiles();
        if (allProfiles.isNotEmpty) {
          final current = (profileId.value.isNotEmpty)
              ? allProfiles.firstWhereOrNull((p) => p.id == profileId.value) ??
                  allProfiles.first
              : allProfiles.first;

          final isDefaultPhoto = current.photoUrl == null ||
              current.photoUrl == '0' ||
              current.photoUrl!.isEmpty;
          final isDefaultName = current.displayName == 'Primary' ||
              current.displayName.isEmpty;

          final newName =
              (isDefaultName && hasName) ? validName : current.displayName;
          final newPhoto =
              (isDefaultPhoto && hasPhoto) ? validPhoto : current.photoUrl;

          if (newName != current.displayName || newPhoto != current.photoUrl) {
            final updated = current.copyWith(
              displayName: newName,
              photoUrl: newPhoto,
              updatedAt: DateTime.now(),
            );
            await repo.updateProfile(updated);
            setActiveProfile(
              updated.id,
              displayName: updated.displayName,
              photoUrl: updated.photoUrl,
            );
            _logger.info(
              'ActiveProfileService: synced profile with authenticated user ($newName, $newPhoto)',
              tag: 'ActiveProfileService',
            );
          }
        }
      }
    } catch (e) {
      _logger.warning(
        'ActiveProfileService: failed to sync with authenticated user',
        tag: 'ActiveProfileService',
        error: e,
      );
    }
  }
}
