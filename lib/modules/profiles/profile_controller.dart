import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/profile_model.dart';
import 'package:stream_hub/data/services/active_profile_service.dart';
import 'package:stream_hub/data/services/profile_service.dart';
import 'package:stream_hub/data/services/settings_service.dart';
import 'package:stream_hub/modules/authentication/models/user_model.dart';
import 'package:stream_hub/modules/authentication/repositories/auth_repository.dart';

/// Maximum number of profiles a user can create.
const int kMaxProfiles = 5;

class ProfileController extends GetxController {
  final ProfileService _profileService;
  final SettingsService _settingsService;
  final AuthRepository? _authRepository;
  final LoggingService _logger = Get.find<LoggingService>();

  ProfileController({
    required ProfileService profileService,
    required SettingsService settingsService,
    AuthRepository? authRepository,
  }) : _profileService = profileService,
       _settingsService = settingsService,
       _authRepository = authRepository;

  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxList<ProfileModel> profiles = <ProfileModel>[].obs;
  final Rx<ProfileModel?> activeProfile = Rx<ProfileModel?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  final RxString displayName = ''.obs;
  final RxString photoUrl = ''.obs;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final authUser = await _authRepository?.getCurrentUser();
      if (authUser != null) {
        currentUser.value = authUser;
        displayName.value = authUser.displayName ?? '';
        photoUrl.value = authUser.photoUrl ?? '';
      }
      final allProfiles = await _profileService.getAllProfiles();
      profiles.value = allProfiles;

      // Restore last-selected profile from ActiveProfileService.
      final savedId = Get.isRegistered<ActiveProfileService>()
          ? Get.find<ActiveProfileService>().currentProfileId
          : '';

      ProfileModel? toSelect;
      if (savedId.isNotEmpty) {
        toSelect = allProfiles.firstWhereOrNull((p) => p.id == savedId);
      }
      toSelect ??= allProfiles.isNotEmpty ? allProfiles.first : null;

      if (toSelect != null) {
        await _applyProfileLocally(toSelect);
      }
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to load profile.';
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Save / Edit ──────────────────────────────────────────────────────────

  Future<void> saveProfileChanges() async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final trimmedName = displayName.value.trim();
      if (trimmedName.isEmpty) {
        throw const ValidationException(message: 'Display name cannot be empty.');
      }
      if (trimmedName.length < 2) {
        throw const ValidationException(
          message: 'Display name must be at least 2 characters.',
        );
      }
      if (activeProfile.value != null) {
        final updated = activeProfile.value!.copyWith(
          displayName: trimmedName,
          photoUrl: photoUrl.value.trim().isEmpty ? null : photoUrl.value.trim(),
          updatedAt: DateTime.now(),
        );
        await _profileService.updateProfile(updated);
        activeProfile.value = updated;
        // Update the list too.
        final idx = profiles.indexWhere((p) => p.id == updated.id);
        if (idx >= 0) profiles[idx] = updated;
      } else {
        await _createNewProfile(trimmedName, photoUrl.value.trim());
      }
      Get.snackbar(
        'Profile Saved',
        'Your profile has been updated.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.surfaceContainerHighest,
        colorText: Get.theme.colorScheme.onSurface,
      );
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to save profile.';
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Profile Selection ────────────────────────────────────────────────────

  Future<void> selectProfile(ProfileModel profile) async {
    try {
      await _applyProfileLocally(profile);
      await _settingsService.updateActiveProfileId(profile.id);
    } catch (e) {
      _logger.error('Failed to select profile', tag: 'ProfileController', error: e);
      errorMessage.value = 'Failed to select profile.';
    }
  }

  /// Update in-memory state AND broadcast to ActiveProfileService.
  Future<void> _applyProfileLocally(ProfileModel profile) async {
    activeProfile.value = profile;
    displayName.value = profile.displayName;
    photoUrl.value = profile.photoUrl ?? '';
    // Broadcast to data-layer services so they reload their caches.
    if (Get.isRegistered<ActiveProfileService>()) {
      Get.find<ActiveProfileService>().setActiveProfile(profile.id);
    }
  }

  // ─── Create Profile ───────────────────────────────────────────────────────

  /// Creates a new profile with [name] and optional [avatarUrl], selects it,
  /// and persists the change.  Capped at [kMaxProfiles].
  Future<void> createProfile(String name, {String? avatarUrl}) async {
    if (profiles.length >= kMaxProfiles) {
      Get.snackbar(
        'Limit Reached',
        'You can have at most $kMaxProfiles profiles.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    try {
      isLoading.value = true;
      await _createNewProfile(name, avatarUrl ?? '');
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to create profile.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _createNewProfile(String name, String avatarUrl) async {
    final now = DateTime.now();
    final newProfile = ProfileModel(
      id: 'profile_${now.millisecondsSinceEpoch}',
      displayName: name.trim(),
      photoUrl: avatarUrl.isEmpty ? null : avatarUrl,
      language: 'en',
      themeMode: 'system',
      createdAt: now,
      updatedAt: now,
    );
    final created = await _profileService.createProfile(newProfile);
    profiles.add(created);
    await selectProfile(created);
  }

  // ─── Delete Profile ───────────────────────────────────────────────────────

  /// Deletes [profile].  Cannot delete the only remaining profile.
  Future<void> deleteProfile(ProfileModel profile) async {
    if (profiles.length <= 1) {
      Get.snackbar(
        'Cannot Delete',
        'You must have at least one profile.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    try {
      isLoading.value = true;
      await _profileService.deleteProfile(profile.id);
      profiles.remove(profile);
      // If we deleted the active profile, switch to the first remaining one.
      if (activeProfile.value?.id == profile.id) {
        await selectProfile(profiles.first);
      }
      Get.snackbar(
        'Profile Deleted',
        '"${profile.displayName}" has been removed.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to delete profile.';
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Preferences ──────────────────────────────────────────────────────────

  Future<void> changeLanguage(String langCode) async {
    try {
      await _settingsService.updateLanguage(langCode);
      if (activeProfile.value != null) {
        final updated = activeProfile.value!.copyWith(language: langCode);
        await _profileService.updateProfile(updated);
        activeProfile.value = updated;
      }
    } catch (e) {
      errorMessage.value = 'Failed to update language.';
    }
  }

  Future<void> changeThemeMode(String themeMode) async {
    try {
      await _settingsService.updateThemeMode(themeMode);
      if (activeProfile.value != null) {
        final updated = activeProfile.value!.copyWith(themeMode: themeMode);
        await _profileService.updateProfile(updated);
        activeProfile.value = updated;
      }
    } catch (e) {
      errorMessage.value = 'Failed to update theme.';
    }
  }

  void clearError() => errorMessage.value = '';
}
