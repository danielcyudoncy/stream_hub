import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';

void main() {
  DateTime now() => DateTime.now();

  group('BufferInfo.isHealthy', () {
    test('flags VOD with a low buffer percentage as unhealthy', () {
      final info = BufferInfo(
        currentBuffer: const Duration(seconds: 1),
        totalDuration: const Duration(minutes: 10),
        bufferPercentage: 5,
        bufferHealthMs: 1000,
        measuredAt: now(),
      );
      expect(info.isHealthy, isFalse);
    });

    test('treats VOD with an adequate buffer as healthy', () {
      final info = BufferInfo(
        currentBuffer: const Duration(seconds: 30),
        totalDuration: const Duration(minutes: 10),
        bufferPercentage: 25,
        bufferHealthMs: 30000,
        measuredAt: now(),
      );
      expect(info.isHealthy, isTrue);
    });

    test('never flags an unbounded (live) stream unhealthy on percentage', () {
      final info = BufferInfo(
        currentBuffer: const Duration(seconds: 1),
        totalDuration: Duration.zero,
        bufferPercentage: 0,
        bufferHealthMs: 1000,
        measuredAt: now(),
      );
      expect(info.isHealthy, isTrue);
    });

    test('flags excessive dropped frames as unhealthy regardless of type', () {
      final live = BufferInfo(
        currentBuffer: const Duration(seconds: 1),
        totalDuration: Duration.zero,
        bufferPercentage: 0,
        bufferHealthMs: 1000,
        droppedFrames: 30,
        measuredAt: now(),
      );
      expect(live.isHealthy, isFalse);

      final vod = BufferInfo(
        currentBuffer: const Duration(seconds: 30),
        totalDuration: const Duration(minutes: 10),
        bufferPercentage: 25,
        bufferHealthMs: 30000,
        droppedFrames: 45,
        measuredAt: now(),
      );
      expect(vod.isHealthy, isFalse);
    });
  });
}
