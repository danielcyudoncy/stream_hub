import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/media/player/vlc_player_adapter.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';

/// Regression test for the pigeon channel-name mismatch that made every
/// Dart->native VLC call fail with
/// `PlatformException(channel-error, Unable to establish connection on
/// channel)` (flutter_vlc_player 7.4.4 vs platform interface 2.0.5).
///
/// Mounts the [VlcPlayer] widget, then drives the adapter exactly like the
/// app does. A broken channel throws from `playSession`; a healthy channel
/// lets native VLC process the stream (buffering/playing/error — any of
/// which proves the pipeline is wired).
///
/// Override the stream with:
///   flutter test integration_test/android_vlc_channel_smoke_test.dart \
///     -d `device` --dart-define=VLC_TEST_URL=your-stream-url
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'VLC adapter mounts, initializes over pigeon channels and engages native '
    'VLC without channel-error',
    (tester) async {
      final adapter = VlcPlayerAdapter();
      addTearDown(adapter.dispose);

      await adapter.initialize();

      const streamUrl = String.fromEnvironment(
        'VLC_TEST_URL',
        defaultValue: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      );

      final session = PlayableSession(
        sessionId: 'vlc-channel-smoke-1',
        mediaItemId: 'vlc-channel-smoke-1',
        providerId: 'vlc-smoke',
        providerType: MediaSourceType.m3u,
        streamUrl: streamUrl,
        streamType: StreamType.httpsLive,
        userAgent: 'StreamHub/1.0',
      );

      final states = <PlaybackState>[];
      final stateSub = adapter.stateStream.listen(states.add);
      addTearDown(stateSub.cancel);

      final playFuture = adapter.playSession(session);

      await tester.pumpWidget(
        MaterialApp(
          home: ColoredBox(
            color: Colors.black,
            child: Center(child: adapter.buildPlayerWidget()),
          ),
        ),
      );

      // Pump frames while playSession runs: the VLC platform view is only
      // created on a laid-out frame, and initialize() cannot proceed until
      // the view reports ready.
      var done = false;
      playFuture.then((_) => done = true).catchError((Object e) {
        done = true;
        throw e;
      });
      final playDeadline = DateTime.now().add(const Duration(seconds: 30));
      while (!done && DateTime.now().isBefore(playDeadline)) {
        await tester.pump(const Duration(milliseconds: 250));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      // A broken pigeon channel throws PlatformException(channel-error) here.
      await playFuture;

      final engaged = await _pumpUntil(
        tester,
        'native VLC engaged (state != idle)',
        () => adapter.state != PlaybackState.idle,
        timeout: const Duration(seconds: 30),
      );

      debugPrint(
        'VLC_CHANNEL_SMOKE states=$states engaged=$engaged '
        'adapterState=${adapter.state}',
      );
      expect(engaged, isTrue,
          reason: 'Native VLC must process the stream after initialize()');

      // Keep pumping so the native view stays attached during teardown.
      await tester.pump(const Duration(seconds: 1));
    },
  );
}

/// Waits for [condition] while continuously pumping frames so platform views
/// mount and native callbacks fire.
Future<bool> _pumpUntil(
  WidgetTester tester,
  String description,
  FutureOr<bool> Function() condition, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) {
      debugPrint('VLC_CHANNEL_SMOKE condition met: $description');
      return true;
    }
    await tester.pump(const Duration(milliseconds: 250));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  debugPrint('VLC_CHANNEL_SMOKE timeout waiting for: $description');
  return false;
}
