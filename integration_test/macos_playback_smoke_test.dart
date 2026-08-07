import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/media/player/media_kit_player_adapter.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';

/// End-to-end smoke test that proves the media_kit playback stack renders real
/// video on macOS (the desktop target where the native EGL texture handshake
/// used on Android is replaced by a working rendering path).
///
/// Override the stream with:
///   flutter test integration_test/macos_playback_smoke_test.dart -d macos \
///     --dart-define=LIVE_STREAM_URL=your-stream-url
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'media_kit adapter opens a live stream, decodes video and advances',
    (tester) async {
      mk.MediaKit.ensureInitialized();

      final adapter = MediaKitPlayerAdapter();
      addTearDown(adapter.dispose);

      const streamUrl = String.fromEnvironment(
        'LIVE_STREAM_URL',
        defaultValue: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      );

      final session = PlayableSession(
        sessionId: 'macos-smoke-1',
        mediaItemId: 'macos-smoke-1',
        providerId: 'macos-smoke',
        providerType: MediaSourceType.m3u,
        streamUrl: streamUrl,
        streamType: StreamType.httpsLive,
        userAgent: 'StreamHub/1.0',
      );

      await adapter.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: ColoredBox(
            color: Colors.black,
            child: Center(child: adapter.buildPlayerWidget()),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final states = <PlaybackState>[];
      final stateSub = adapter.stateStream.listen(states.add);
      addTearDown(stateSub.cancel);

      await adapter.playSession(session);
      await adapter.play();

      await _waitUntil(
        'player reports playing',
        () => adapter.state == PlaybackState.playing,
        timeout: const Duration(seconds: 45),
      );

      final resolved = await _waitUntil(
        'video frames are being decoded (width/height resolved)',
        () async {
          final size = adapter.player?.state.width ?? 0;
          return size > 0;
        },
        timeout: const Duration(seconds: 45),
      );
      debugPrint('MACOS_SMOKE video size: '
          '${adapter.player?.state.width}x${adapter.player?.state.height}');

      await _waitUntil(
        'playback position advances',
        () => adapter.position > Duration.zero,
        timeout: const Duration(seconds: 45),
      );
      debugPrint(
        'MACOS_SMOKE position=${adapter.position} '
        'buffer=${adapter.bufferPosition}',
      );

      expect(states, contains(PlaybackState.playing));
      expect(resolved, isTrue);
      expect(adapter.position, greaterThan(Duration.zero));

      // Keep pumping so the native video view stays attached during teardown.
      await tester.pump(const Duration(seconds: 1));
    },
  );
}

Future<bool> _waitUntil(
  String description,
  FutureOr<bool> Function() condition, {
  required Duration timeout,
  Duration interval = const Duration(seconds: 1),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) {
      debugPrint('MACOS_SMOKE condition met: $description');
      return true;
    }
    await Future<void>.delayed(interval);
  }
  debugPrint('MACOS_SMOKE timeout waiting for: $description');
  return false;
}
