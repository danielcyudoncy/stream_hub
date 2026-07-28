import 'package:hive/hive.dart';

part 'settings_model.g.dart';

@HiveType(typeId: 3)
class SettingsModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String themeMode;

  @HiveField(2)
  String language;

  @HiveField(3)
  String? activeProfileId;

  @HiveField(4)
  bool notificationsEnabled;

  @HiveField(5)
  bool parentalLockEnabled;

  @HiveField(6)
  String? parentalPin;

  @HiveField(7)
  DateTime? lastCacheClear;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  DateTime updatedAt;

  SettingsModel({
    required this.id,
    this.themeMode = 'system',
    this.language = 'en',
    this.activeProfileId,
    this.notificationsEnabled = true,
    this.parentalLockEnabled = false,
    this.parentalPin,
    this.lastCacheClear,
    required this.createdAt,
    required this.updatedAt,
  });

  SettingsModel copyWith({
    String? themeMode,
    String? language,
    String? activeProfileId,
    bool? notificationsEnabled,
    bool? parentalLockEnabled,
    String? parentalPin,
    DateTime? lastCacheClear,
    DateTime? updatedAt,
  }) {
    return SettingsModel(
      id: id,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      parentalLockEnabled: parentalLockEnabled ?? this.parentalLockEnabled,
      parentalPin: parentalPin ?? this.parentalPin,
      lastCacheClear: lastCacheClear ?? this.lastCacheClear,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}