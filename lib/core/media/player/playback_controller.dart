import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/events/playback_event.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/media/player/player_settings.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/playback_engine.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playable_stream.dart';

class PlaybackController extends GetxController {
  final PlayerSettings settings;
  final LoggingService logger;

  late final PlaybackEngine engine;

  PlaybackController({
    PlayerAdapter? adapter,
    PlaybackEngineKind? engineKind,
    PlayerSettings? settings,
    LoggingService? logger,
  })  : settings = settings ?? const PlayerSettings(),
        logger = logger ?? LoggingService() {
    // Created eagerly (not in onInit) because this controller is composed
    // manually inside PlayerController and is never registered with GetX, so
    // GetX lifecycle hooks (onInit) would never fire and `engine` would stay
    // uninitialized, causing a LateInitializationError on first access.
    //
    // When `adapter`/`engineKind` are omitted the engine runs in Auto mode: it
    // selects the best backend per session and can fall back on failure.
    engine = PlaybackEngine(
      adapter: adapter,
      engineKind: engineKind,
      settings: this.settings,
      logger: this.logger,
    );
  }

  /// The currently active playback backend. Delegates to the engine so the
  /// value always reflects engine selection/fallback (Auto mode) and never a
  /// stale eagerly-created adapter.
  PlayerAdapter get adapter => engine.adapter;

  /// The kind of the currently active playback backend.
  PlaybackEngineKind get engineKind => engine.engineKind;

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
