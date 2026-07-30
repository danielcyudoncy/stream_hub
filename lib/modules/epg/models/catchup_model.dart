class CatchUpModel {
  final String id;
  final String programId;
  final String channelId;
  final String channelName;
  final String programTitle;
  final DateTime startTime;
  final DateTime endTime;
  final String? posterUrl;
  final String? description;
  final int availableDays;
  final String? catchupSource;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CatchUpModel({
    required this.id,
    required this.programId,
    required this.channelId,
    required this.channelName,
    required this.programTitle,
    required this.startTime,
    required this.endTime,
    this.posterUrl,
    this.description,
    this.availableDays = 0,
    this.catchupSource,
    this.isAvailable = false,
    required this.createdAt,
    required this.updatedAt,
  });

  CatchUpModel copyWith({
    String? id,
    String? programId,
    String? channelId,
    String? channelName,
    String? programTitle,
    DateTime? startTime,
    DateTime? endTime,
    String? posterUrl,
    String? description,
    int? availableDays,
    String? catchupSource,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CatchUpModel(
      id: id ?? this.id,
      programId: programId ?? this.programId,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      programTitle: programTitle ?? this.programTitle,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      posterUrl: posterUrl ?? this.posterUrl,
      description: description ?? this.description,
      availableDays: availableDays ?? this.availableDays,
      catchupSource: catchupSource ?? this.catchupSource,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}