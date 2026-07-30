import 'dart:async';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/player/playback_engine.dart';

class BufferService {
  final PlaybackEngine engine;
  final LoggingService logger;

  BufferService(this.engine, {LoggingService? logger})
      : logger = logger ?? LoggingService();

  Stream<Duration> get bufferStream => engine.bufferRx.stream;

  void addListener(void Function(Duration) listener) {
    engine.addBufferListener(listener);
  }

  void removeListener(void Function(Duration) listener) {
    engine.removeBufferListener(listener);
  }

  bool get isHealthy {
    final info = engine.bufferInfoRx.value;
    return info != null && info.isHealthy;
  }

  double get bufferPercentage {
    return engine.bufferInfoRx.value?.bufferPercentage ?? 0.0;
  }

  Duration get currentBuffer {
    return engine.bufferRx.value;
  }

  int get droppedFrames {
    return engine.bufferInfoRx.value?.droppedFrames ?? 0;
  }

  int get networkSpeedKbps {
    return engine.bufferInfoRx.value?.networkSpeedKbps ?? 0;
  }

  int get playbackLatencyMs {
    return engine.bufferInfoRx.value?.playbackLatencyMs ?? 0;
  }
}
