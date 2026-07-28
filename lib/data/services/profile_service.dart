import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/repositories/profile_repository.dart';
import 'package:stream_hub/data/models/profile_model.dart';

class ProfileService extends GetxService {
  final ProfileRepository _repository;
  final LoggingService _logger = Get.find<LoggingService>();

  ProfileService(this._repository);

  Future<List<ProfileModel>> getAllProfiles() async {
    try {
      return await _repository.getAllProfiles();
    } catch (e) {
      _logger.error('Failed to get all profiles', tag: 'ProfileService', error: e);
      throw DatabaseException(message: 'Failed to get profiles', originalError: e);
    }
  }

  Future<ProfileModel?> getProfileById(String id) async {
    try {
      return await _repository.getProfileById(id);
    } catch (e) {
      _logger.error('Failed to get profile', tag: 'ProfileService', error: e);
      throw DatabaseException(message: 'Failed to get profile', originalError: e);
    }
  }

  Future<ProfileModel> createProfile(ProfileModel profile) async {
    try {
      return await _repository.createProfile(profile);
    } catch (e) {
      _logger.error('Failed to create profile', tag: 'ProfileService', error: e);
      throw DatabaseException(message: 'Failed to create profile', originalError: e);
    }
  }

  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    try {
      return await _repository.updateProfile(profile);
    } catch (e) {
      _logger.error('Failed to update profile', tag: 'ProfileService', error: e);
      throw DatabaseException(message: 'Failed to update profile', originalError: e);
    }
  }

  Future<void> deleteProfile(String id) async {
    try {
      await _repository.deleteProfile(id);
    } catch (e) {
      _logger.error('Failed to delete profile', tag: 'ProfileService', error: e);
      throw DatabaseException(message: 'Failed to delete profile', originalError: e);
    }
  }

  Future<ProfileModel?> getActiveProfile() async {
    try {
      final profiles = await getAllProfiles();
      return profiles.isNotEmpty ? profiles.first : null;
    } catch (e) {
      _logger.error('Failed to get active profile', tag: 'ProfileService', error: e);
      return null;
    }
  }

  Future<void> setActiveProfile(String id) async {
    try {
      final profiles = await getAllProfiles();
      final index = profiles.indexWhere((p) => p.id == id);
      if (index > 0 && profiles.isNotEmpty) {
        final active = profiles.removeAt(index);
        profiles.insert(0, active);
        for (var i = 0; i < profiles.length; i++) {
          await _repository.updateProfile(profiles[i].copyWith(updatedAt: DateTime.now()));
        }
      }
    } catch (e) {
      _logger.error('Failed to set active profile', tag: 'ProfileService', error: e);
      throw DatabaseException(message: 'Failed to set active profile', originalError: e);
    }
  }
}
