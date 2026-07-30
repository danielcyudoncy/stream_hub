class RecordingModel {
  final String id;
  final String programId;
  final String channelId;
  final String channelName;
  final String programTitle;
  final DateTime startTime;
  final DateTime endTime;
  final String? posterUrl;
  final String? description;
  final RecordingStatus status;
  final String? storagePath;
  final String? providerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecordingModel({
    required this.id,
    required this.programId,
    required this.channelId,
    required this.channelName,
    required this.programTitle,
    required this.startTime,
    required this.endTime,
    this.posterUrl,
    this.description,
    this.status = RecordingStatus.pending,
    this.storagePath,
    this.providerId,
    required this.createdAt,
    required this.updatedAt,
  });

  RecordingModel copyWith({
    String? id,
    String? programId,
    String? channelId,
    String? channelName,
    String? programTitle,
    DateTime? startTime,
    DateTime? endTime,
    String? posterUrl,
    String? description,
    RecordingStatus? status,
    String? storagePath,
    String? providerId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecordingModel(
      id: id ?? this.id,
      programId: programId ?? this.programId,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      programTitle: programTitle ?? this.programTitle,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      posterUrl: posterUrl ?? this.posterUrl,
      description: description ?? this.description,
      status: status ?? this.status,
      storagePath: storagePath ?? this.storagePath,
      providerId: providerId ?? this.providerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum RecordingStatus {
  pending,
  recording,
  completed,
  failed,
  cancelled,
}