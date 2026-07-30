import 'package:hive/hive.dart';
import 'package:stream_hub/core/media/player/playback_analytics.dart';

part 'playback_analytics_model.g.dart';

@HiveType(typeId: 11)
class PlaybackAnalyticsModel extends HiveObject {
  @HiveField(0)
  final String sessionId;

  @HiveField(1)
  final String itemId;

  @HiveField(2)
  final String providerType;

  @HiveField(3)
  final DateTime startedAt;

  @HiveField(4)
  final DateTime? endedAt;

  @HiveField(5)
  final int totalWatchTimeSeconds;

  @HiveField(6)
  final int bufferedTimeSeconds;

  @HiveField(7)
  final int channelChanges;

  @HiveField(8)
  final int seekCount;

  @HiveField(9)
  final int pauseCount;

  @HiveField(10)
  final int errorCount;

  @HiveField(11)
  final double completionPercentage;

  @HiveField(12)
  final String? lastError;

  @HiveField(13)
  final int startupTimeMs;

  PlaybackAnalyticsModel({
    required this.sessionId,
    required this.itemId,
    required this.providerType,
    required this.startedAt,
    this.endedAt,
    this.totalWatchTimeSeconds = 0,
    this.bufferedTimeSeconds = 0,
    this.channelChanges = 0,
    this.seekCount = 0,
    this.pauseCount = 0,
    this.errorCount = 0,
    this.completionPercentage = 0.0,
    this.lastError,
    this.startupTimeMs = 0,
  });

  PlaybackAnalytics toDomain() {
    return PlaybackAnalytics(
      sessionId: sessionId,
      itemId: itemId,
      providerType: providerType,
      startedAt: startedAt,
      endedAt: endedAt,
      totalWatchTime: Duration(seconds: totalWatchTimeSeconds),
      bufferedTime: Duration(seconds: bufferedTimeSeconds),
      channelChanges: channelChanges,
      seekCount: seekCount,
      pauseCount: pauseCount,
      errorCount: errorCount,
      completionPercentage: completionPercentage,
      lastError: lastError,
      startupTime: Duration(milliseconds: startupTimeMs),
    );
  }

  factory PlaybackAnalyticsModel.fromDomain(PlaybackAnalytics analytics) {
    return PlaybackAnalyticsModel(
      sessionId: analytics.sessionId,
      itemId: analytics.itemId,
      providerType: analytics.providerType,
      startedAt: analytics.startedAt,
      endedAt: analytics.endedAt,
      totalWatchTimeSeconds: analytics.totalWatchTime.inSeconds,
      bufferedTimeSeconds: analytics.bufferedTime.inSeconds,
      channelChanges: analytics.channelChanges,
      seekCount: analytics.seekCount,
      pauseCount: analytics.pauseCount,
      errorCount: analytics.errorCount,
      completionPercentage: analytics.completionPercentage,
      lastError: analytics.lastError,
      startupTimeMs: analytics.startupTime.inMilliseconds,
    );
  }
}
