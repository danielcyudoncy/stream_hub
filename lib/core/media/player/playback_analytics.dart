class PlaybackAnalytics {
  final String sessionId;
  final String itemId;
  final String providerType;
  final DateTime startedAt;
  DateTime? endedAt;
  Duration totalWatchTime;
  Duration bufferedTime;
  int channelChanges;
  int seekCount;
  int pauseCount;
  int errorCount;
  double completionPercentage;
  String? lastError;
  final Duration startupTime;
  final Map<String, int> qualityChanges;
  final Map<String, int> speedChanges;

  PlaybackAnalytics({
    required this.sessionId,
    required this.itemId,
    required this.providerType,
    required this.startedAt,
    this.endedAt,
    this.totalWatchTime = Duration.zero,
    this.bufferedTime = Duration.zero,
    this.channelChanges = 0,
    this.seekCount = 0,
    this.pauseCount = 0,
    this.errorCount = 0,
    this.completionPercentage = 0.0,
    this.lastError,
    this.startupTime = Duration.zero,
    this.qualityChanges = const {},
    this.speedChanges = const {},
  });

  PlaybackAnalytics copyWith({
    String? sessionId,
    String? itemId,
    String? providerType,
    DateTime? startedAt,
    DateTime? endedAt,
    Duration? totalWatchTime,
    Duration? bufferedTime,
    int? channelChanges,
    int? seekCount,
    int? pauseCount,
    int? errorCount,
    double? completionPercentage,
    String? lastError,
    Duration? startupTime,
    Map<String, int>? qualityChanges,
    Map<String, int>? speedChanges,
  }) {
    return PlaybackAnalytics(
      sessionId: sessionId ?? this.sessionId,
      itemId: itemId ?? this.itemId,
      providerType: providerType ?? this.providerType,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      totalWatchTime: totalWatchTime ?? this.totalWatchTime,
      bufferedTime: bufferedTime ?? this.bufferedTime,
      channelChanges: channelChanges ?? this.channelChanges,
      seekCount: seekCount ?? this.seekCount,
      pauseCount: pauseCount ?? this.pauseCount,
      errorCount: errorCount ?? this.errorCount,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      lastError: lastError ?? this.lastError,
      startupTime: startupTime ?? this.startupTime,
      qualityChanges: qualityChanges ?? this.qualityChanges,
      speedChanges: speedChanges ?? this.speedChanges,
    );
  }

  Duration get watchDuration {
    if (endedAt != null) {
      return endedAt!.difference(startedAt);
    }
    return DateTime.now().difference(startedAt);
  }
}
