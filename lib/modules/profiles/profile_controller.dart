import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/profile_model.dart';
import 'package:stream_hub/data/services/profile_service.dart';
import 'package:stream_hub/data/services/settings_service.dart';
import 'package:stream_hub/modules/authentication/models/user_model.dart';
import 'package:stream_hub/modules/authentication/repositories/auth_repository.dart';

class ProfileController extends GetxController {
  final ProfileService _profileService;
  final SettingsService _settingsService;
  final AuthRepository? _authRepository;
  // ignore: unused_field
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
      if (allProfiles.isNotEmpty) {
        activeProfile.value = allProfiles.first;
      }
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to load profile.';
    } finally {
      isLoading.value = false;
    }
  }

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
        throw const ValidationException(message: 'Display name must be at least 2 characters.');
      }
      if (activeProfile.value != null) {
        final updated = activeProfile.value!.copyWith(
          displayName: trimmedName,
          photoUrl: photoUrl.value.trim().isEmpty ? null : photoUrl.value.trim(),
          updatedAt: DateTime.now(),
        );
        await _profileService.updateProfile(updated);
        activeProfile.value = updated;
      } else {
        final now = DateTime.now();
        final newProfile = ProfileModel(
          id: 'profile_${now.millisecondsSinceEpoch}',
          displayName: trimmedName,
          photoUrl: photoUrl.value.trim().isEmpty ? null : photoUrl.value.trim(),
          language: 'en',
          themeMode: 'system',
          createdAt: now,
          updatedAt: now,
        );
        final created = await _profileService.createProfile(newProfile);
        profiles.add(created);
        activeProfile.value = created;
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

  Future<void> selectProfile(ProfileModel profile) async {
    try {
      activeProfile.value = profile;
      displayName.value = profile.displayName;
      photoUrl.value = profile.photoUrl ?? '';
      await _settingsService.updateActiveProfileId(profile.id);
    } catch (e) {
      errorMessage.value = 'Failed to select profile.';
    }
  }

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

  void clearError() {
    errorMessage.value = '';
  }
}
