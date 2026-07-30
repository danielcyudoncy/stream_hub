import 'dart:async';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/player/playback_engine.dart';

class PlaybackService {
  final LoggingService logger;
  final PlaybackEngine engine;

  PlaybackService(this.engine, {LoggingService? logger})
      : logger = logger ?? LoggingService();

  Future<void> play() => engine.play();
  Future<void> pause() => engine.pause();
  Future<void> resume() => engine.resume();
  Future<void> stop() => engine.stop();
  Future<void> seek(Duration position) => engine.seek(position);
  Future<void> replay() => engine.replay();
  Future<void> next() => engine.next();
  Future<void> previous() => engine.previous();
  Future<void> retry() => engine.retry();

  Future<void> setSpeed(double speed) async {
    final speedEnum = PlaybackSpeed.values.firstWhere(
      (s) => s.value == speed,
      orElse: () => PlaybackSpeed.speed1_0,
    );
    await engine.setSpeed(speedEnum);
  }

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
}
