import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/events/playback_event.dart';
import 'package:stream_hub/core/media/player/media_kit_player_adapter.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/media/player/player_settings.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/playback_engine.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playable_stream.dart';

class PlaybackController extends GetxController {
  final PlayerAdapter adapter;
  final PlayerSettings settings;
  final LoggingService logger;

  late final PlaybackEngine engine;

  PlaybackController({
    PlayerAdapter? adapter,
    PlayerSettings? settings,
    LoggingService? logger,
  })  : adapter = adapter ?? MediaKitPlayerAdapter(),
        settings = settings ?? const PlayerSettings(),
        logger = logger ?? LoggingService();

  @override
  void onInit() {
    super.onInit();
    engine = PlaybackEngine(
      adapter: adapter,
      settings: settings,
      logger: logger,
    );
  }

  @override
  void onClose() {
    engine.dispose();
    super.onClose();
  }

  Future<void> initialize() async {
    await engine.initialize();
  }

  Future<PlayableMediaSession> playMedia(
    MediaItem mediaItem,
    PlayableStream stream, {
    String? providerId,
    Duration? resumePosition,
  }) async {
    return engine.createSession(
      mediaItem,
      stream,
      providerId: providerId,
      resumePosition: resumePosition,
    );
  }

  /// Plays an authenticated session produced by the Stream Engine.
  Future<PlayableMediaSession> playSession(
    PlayableSession session, {
    MediaItem? mediaItem,
    Duration? resumePosition,
  }) async {
    return engine.playFromStreamEngine(
      session,
      mediaItem: mediaItem,
      resumePosition: resumePosition,
    );
  }

  Future<void> play() => engine.play();
  Future<void> pause() => engine.pause();
  Future<void> resume() => engine.resume();
  Future<void> stop() => engine.stop();
  Future<void> seek(Duration position) => engine.seek(position);
  Future<void> replay() => engine.replay();
  Future<void> next() => engine.next();
  Future<void> previous() => engine.previous();
  Future<void> retry() => engine.retry();

  Future<void> setSpeed(PlaybackSpeed speed) => engine.setSpeed(speed);
  Future<void> setAspectRatio(AspectRatioMode mode) =>
      engine.setAspectRatio(mode);
  Future<void> setQuality(PlayerQuality quality) =>
      engine.setQuality(quality);
  Future<void> setSubtitleTrack(String trackId) =>
      engine.setSubtitleTrack(trackId);
  Future<void> setAudioTrack(String trackId) => engine.setAudioTrack(trackId);
  Future<void> setVolume(double volume) => engine.setVolume(volume);
  Future<void> setMuted(bool muted) => engine.setMuted(muted);

  void addStateListener(void Function(PlaybackState) listener) =>
      engine.addStateListener(listener);
  void removeStateListener(void Function(PlaybackState) listener) =>
      engine.removeStateListener(listener);
  void addPositionListener(void Function(Duration) listener) =>
      engine.addPositionListener(listener);
  void removePositionListener(void Function(Duration) listener) =>
      engine.removePositionListener(listener);
  void addBufferListener(void Function(Duration) listener) =>
      engine.addBufferListener(listener);
  void removeBufferListener(void Function(Duration) listener) =>
      engine.removeBufferListener(listener);
  void addEventListener(void Function(PlaybackEvent) listener) =>
      engine.addEventListener(listener);
  void removeEventListener(void Function(PlaybackEvent) listener) =>
      engine.removeEventListener(listener);
}
