import 'dart:async';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';

abstract class PlayerAdapter {
  Future<void> initialize();
  Future<void> dispose();

  Future<void> load(PlayableMediaSession session);

  /// Loads an authenticated stream produced by the Stream Engine. The player
  /// must never be given a raw provider URL or header set.
  Future<void> playSession(PlayableSession session);

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
  Stream<PlaybackState> get errorStream;
  Stream<String> get subtitleStream;
}
