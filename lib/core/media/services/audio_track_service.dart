import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/player/playback_engine.dart';

class AudioTrackService {
  final PlaybackEngine engine;
  final LoggingService logger;

  AudioTrackService(this.engine, {LoggingService? logger})
      : logger = logger ?? LoggingService();

  Future<void> select(String trackId) async {
    await engine.setAudioTrack(trackId);
  }

  Future<List<dynamic>> getAvailableTracks() async {
    if (engine.currentSession == null) return const [];
    return await engine.adapter.getAvailableAudioTracks();
  }

  String? get preferredLanguage {
    return engine.currentSession?.mediaItem.language;
  }
}
