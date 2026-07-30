import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/player/playback_engine.dart';

class SubtitleService {
  final PlaybackEngine engine;
  final LoggingService logger;

  SubtitleService(this.engine, {LoggingService? logger})
      : logger = logger ?? LoggingService();

  Future<void> enable() async {
    if (engine.currentSession != null &&
        engine.currentSession!.capabilities.canChangeSubtitle) {
      final tracks = await engine.adapter.getAvailableSubtitleTracks();
      if (tracks.isNotEmpty) {
        await engine.setSubtitleTrack(tracks.first.toString());
      }
    }
  }

  Future<void> disable() async {
    await engine.adapter.setSubtitleTrack('');
  }

  Future<void> select(String trackId) async {
    await engine.setSubtitleTrack(trackId);
  }

  Future<List<dynamic>> getAvailableTracks() async {
    if (engine.currentSession == null) return const [];
    return await engine.adapter.getAvailableSubtitleTracks();
  }

  bool get isEnabled {
    return engine.currentSession?.availableSubtitleTracks.isNotEmpty ?? false;
  }
}
