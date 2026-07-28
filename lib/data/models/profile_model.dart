import 'package:hive/hive.dart';

@HiveType(typeId: 1)
class ProfileModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String displayName;

  @HiveField(2)
  String? photoUrl;

  @HiveField(3)
  String language;

  @HiveField(4)
  String themeMode;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  ProfileModel({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.language = 'en',
    this.themeMode = 'system',
    required this.createdAt,
    required this.updatedAt,
  });

  ProfileModel copyWith({
    String? displayName,
    String? photoUrl,
    String? language,
    String? themeMode,
    DateTime? updatedAt,
  }) {
    return ProfileModel(
      id: id,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
