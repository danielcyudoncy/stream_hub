class ReminderModel {
  final String id;
  final String programId;
  final String channelId;
  final String channelName;
  final String programTitle;
  final DateTime startTime;
  final DateTime endTime;
  final String? posterUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReminderModel({
    required this.id,
    required this.programId,
    required this.channelId,
    required this.channelName,
    required this.programTitle,
    required this.startTime,
    required this.endTime,
    this.posterUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  ReminderModel copyWith({
    String? id,
    String? programId,
    String? channelId,
    String? channelName,
    String? programTitle,
    DateTime? startTime,
    DateTime? endTime,
    String? posterUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      programId: programId ?? this.programId,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      programTitle: programTitle ?? this.programTitle,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      posterUrl: posterUrl ?? this.posterUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}