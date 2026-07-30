import 'package:hive/hive.dart';

part 'playback_session_model.g.dart';

@HiveType(typeId: 10)
class PlaybackSessionModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String itemId;

  @HiveField(2)
  final String providerType;

  @HiveField(3)
  final Duration resumePosition;

  @HiveField(4)
  final double completionPercentage;

  @HiveField(5)
  final DateTime updatedAt;

  PlaybackSessionModel({
    required this.id,
    required this.itemId,
    required this.providerType,
    required this.resumePosition,
    required this.completionPercentage,
    required this.updatedAt,
  });

  PlaybackSessionModel copyWith({
    String? id,
    String? itemId,
    String? providerType,
    Duration? resumePosition,
    double? completionPercentage,
    DateTime? updatedAt,
  }) {
    return PlaybackSessionModel(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      providerType: providerType ?? this.providerType,
      resumePosition: resumePosition ?? this.resumePosition,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
