import 'package:stream_hub/core/media/player/playback_analytics.dart';
import 'package:stream_hub/core/media/player/player_settings.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playback_session_model.dart';

abstract class PlaybackRepository {
  Future<void> saveWatchProgress(MediaItem item, Duration position, Duration duration);
  Future<Duration?> getWatchProgress(String itemId);
  Future<PlaybackSessionModel?> getWatchSession(String itemId);
  Future<List<PlaybackSessionModel>> getAllWatchSessions();
  Future<void> deleteWatchProgress(String itemId);
  Future<void> saveAnalytics(PlaybackAnalytics analytics);
  Future<List<PlaybackAnalytics>> getAnalytics({int limit = 100});
  Future<void> updateSettings(PlayerSettings settings);
  Future<PlayerSettings> getSettings();
  Future<void> clearHistory();
}

