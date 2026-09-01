import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';

abstract class PlayerAdapter {
  /// Identifies the playback backend implemented by this adapter.
  ///
  /// Backends implementers must override this so the Playback Engine can
  /// negotiate, switch, and surface the active engine to the UI.
  PlaybackEngineKind get kind => PlaybackEngineKind.fallback;

  /// Whether the native player has been created and can accept media.
  ///
  /// This is `false` until [initialize] has completed. Backends must override
  /// it so the engine can avoid re-initializing an already-ready player.
  bool get isInitialized => false;

  /// Builds the widget that renders video output for this backend.
  ///
  /// The Playback Engine is the only component that knows which backend is
  /// active, so the player pages render video through this adapter rather than
  /// type-checking concrete implementations. Returns an empty widget when the
  /// backend has not been initialized yet.
  Widget buildPlayerWidget() => const SizedBox.shrink();

  Future<void> initialize();
  Future<void> dispose();

  Future<void> load(PlayableMediaSession session);

  /// Loads an authenticated stream produced by the Stream Engine. The player
  /// must never be given a raw provider URL or header set.
  ///
  /// [title] optionally carries the display title of the item being played so
  /// backends that render their own surfaces (e.g. a native Activity) can show
  /// it to the user.
  Future<void> playSession(PlayableSession session, {String? title});

  Future<void> play();
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> replay();
  Future<void> next();
  Future<void> previous();
  Future<void> retry();

  PlaybackState get state;
  Duration get position;
  Duration get duration;
  Duration get bufferPosition;
  double get volume;
  bool get isMuted;
  PlaybackSpeed get speed;
  AspectRatioMode get aspectRatio;
  PlayerQuality get currentQuality;

  Future<List<dynamic>> getAvailableAudioTracks();
  Future<List<dynamic>> getAvailableSubtitleTracks();
  Future<List<PlayerQuality>> getAvailableQualities();

  Future<void> setAudioTrack(String trackId);
  Future<void> setSubtitleTrack(String trackId);
  Future<void> setSpeed(PlaybackSpeed speed);
  Future<void> setAspectRatio(AspectRatioMode mode);
  Future<void> setQuality(PlayerQuality quality);
  Future<void> setVolume(double volume);
  Future<void> setMuted(bool muted);

  Future<BufferInfo> getBufferInfo();

  Stream<PlaybackState> get stateStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get bufferStream;
  Stream<String> get errorStream;
  Stream<String> get subtitleStream;

  Future<void> enterPictureInPicture();
  bool get isInPip;
}
