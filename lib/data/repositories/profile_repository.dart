import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/services/database_service.dart';
import 'package:stream_hub/data/models/profile_model.dart';

class ProfileRepository extends GetxService {
  final DatabaseService _dbService = Get.find<DatabaseService>();
  final LoggingService _logger = Get.find<LoggingService>();

  Future<List<ProfileModel>> getAllProfiles() async {
    try {
      final box = _dbService.profilesBox;
      final List<dynamic> raw = box.values.toList();
      return raw
          .map((e) => _mapFromHive(e as Map))
          .whereType<ProfileModel>()
          .toList();
    } catch (e) {
      _logger.error('Failed to load profiles', tag: 'ProfileRepository', error: e);
      throw DatabaseException(message: 'Failed to load profiles', originalError: e);
    }
  }

  Future<ProfileModel?> getProfileById(String id) async {
    try {
      final box = _dbService.profilesBox;
      final raw = box.get(id);
      if (raw == null) return null;
      return _mapFromHive(raw as Map);
    } catch (e) {
      _logger.error('Failed to get profile by id', tag: 'ProfileRepository', error: e);
      throw DatabaseException(message: 'Failed to get profile', originalError: e);
    }
  }

  Future<ProfileModel> createProfile(ProfileModel profile) async {
    try {
      final box = _dbService.profilesBox;
      await box.put(profile.id, _mapToHive(profile));
      return profile;
    } catch (e) {
      _logger.error('Failed to create profile', tag: 'ProfileRepository', error: e);
      throw DatabaseException(message: 'Failed to create profile', originalError: e);
    }
  }

  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    try {
      final box = _dbService.profilesBox;
      final updated = profile.copyWith(updatedAt: DateTime.now());
      await box.put(updated.id, _mapToHive(updated));
      return updated;
    } catch (e) {
      _logger.error('Failed to update profile', tag: 'ProfileRepository', error: e);
      throw DatabaseException(message: 'Failed to update profile', originalError: e);
    }
  }

  Future<void> deleteProfile(String id) async {
    try {
      await _dbService.profilesBox.delete(id);
    } catch (e) {
      _logger.error('Failed to delete profile', tag: 'ProfileRepository', error: e);
      throw DatabaseException(message: 'Failed to delete profile', originalError: e);
    }
  }

  Map<String, dynamic> _mapToHive(ProfileModel model) {
    return {
      'id': model.id,
      'displayName': model.displayName,
      'photoUrl': model.photoUrl,
      'language': model.language,
      'themeMode': model.themeMode,
      'createdAt': model.createdAt.millisecondsSinceEpoch,
      'updatedAt': model.updatedAt.millisecondsSinceEpoch,
    };
  }

  ProfileModel? _mapFromHive(Map<dynamic, dynamic> map) {
    try {
      final id = map['id'] as String?;
      final displayName = map['displayName'] as String?;
      final photoUrl = map['photoUrl'] as String?;
      final language = map['language'] as String?;
      final themeMode = map['themeMode'] as String?;
      final createdAtRaw = map['createdAt'] as int?;
      final updatedAtRaw = map['updatedAt'] as int?;

      if (id == null || displayName == null) return null;

      return ProfileModel(
        id: id,
        displayName: displayName,
        photoUrl: photoUrl,
        language: language ?? 'en',
        themeMode: themeMode ?? 'system',
        createdAt: createdAtRaw != null
            ? DateTime.fromMillisecondsSinceEpoch(createdAtRaw)
            : DateTime.now(),
        updatedAt: updatedAtRaw != null
            ? DateTime.fromMillisecondsSinceEpoch(updatedAtRaw)
            : DateTime.now(),
      );
    } catch (e) {
      _logger.warning('Failed to map profile from hive', tag: 'ProfileRepository', error: e);
      return null;
    }
  }
}
