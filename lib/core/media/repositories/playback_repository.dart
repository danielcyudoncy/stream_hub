import 'package:stream_hub/core/media/player/playback_analytics.dart';
import 'package:stream_hub/core/media/player/player_settings.dart';
import 'package:stream_hub/data/models/media_item.dart';

abstract class PlaybackRepository {
  Future<void> saveWatchProgress(MediaItem item, Duration position, Duration duration);
  Future<Duration?> getWatchProgress(String itemId);
  Future<void> saveAnalytics(PlaybackAnalytics analytics);
  Future<List<PlaybackAnalytics>> getAnalytics({int limit = 100});
  Future<void> updateSettings(PlayerSettings settings);
  Future<PlayerSettings> getSettings();
  Future<void> clearHistory();
}
