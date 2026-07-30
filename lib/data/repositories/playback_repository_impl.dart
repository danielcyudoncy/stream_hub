import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/player/playback_analytics.dart';
import 'package:stream_hub/core/media/player/player_settings.dart';
import 'package:stream_hub/core/media/repositories/playback_repository.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playback_analytics_model.dart';
import 'package:stream_hub/data/models/playback_session_model.dart';
import 'package:stream_hub/data/models/player_settings_model.dart';
import 'package:stream_hub/data/services/playback_local_service.dart';

class PlaybackRepositoryImpl implements PlaybackRepository {
  final PlaybackLocalService localService;
  final LoggingService logger;

  PlaybackRepositoryImpl(this.localService, {LoggingService? logger})
      : logger = logger ?? LoggingService();

  @override
  Future<void> saveWatchProgress(
    MediaItem item,
    Duration position,
    Duration duration,
  ) async {
    final model = PlaybackSessionModel(
      id: item.id,
      itemId: item.id,
      providerType: item.providerType.name,
      resumePosition: position,
      completionPercentage:
          duration > Duration.zero
              ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
              : 0.0,
      updatedAt: DateTime.now(),
    );
    await localService.saveSession(model);
  }

  @override
  Future<Duration?> getWatchProgress(String itemId) async {
    final model = await localService.getSession(itemId);
    return model?.resumePosition;
  }

  @override
  Future<void> saveAnalytics(PlaybackAnalytics analytics) async {
    final model = PlaybackAnalyticsModel.fromDomain(analytics);
    await localService.saveAnalytics(model);
  }

  @override
  Future<List<PlaybackAnalytics>> getAnalytics({int limit = 100}) async {
    final models = await localService.getAnalytics(limit: limit);
    return models.map((m) => m.toDomain()).toList();
  }

  @override
  Future<void> updateSettings(PlayerSettings settings) async {
    final model = PlayerSettingsModel.fromDomain(settings);
    await localService.saveSettings(model);
  }

  @override
  Future<PlayerSettings> getSettings() async {
    final model = await localService.getSettings();
    return model?.toDomain() ?? const PlayerSettings();
  }

  @override
  Future<void> clearHistory() async {
    await localService.clearAll();
  }
}
