import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/media/player/media_kit_player_adapter.dart';
import 'package:stream_hub/core/media/player/playback_engine.dart';
import 'package:stream_hub/core/media/player/vlc_player_adapter.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';

/// Drives the exact production playback path on a device:
/// PlaybackEngine (Auto) -> PlayerSelectionStrategy -> adapter (VLC or
/// MediaKit) -> native renderer. Logs every stage so the failing stage is
/// identifiable from the output.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'full pipeline on device: engine selects a backend and reports a state',
    (tester) async {
      mk.MediaKit.ensureInitialized();

      final logger = LoggingService();
      final engine = PlaybackEngine(logger: logger);

      final states = <PlaybackState>[];
      final stateSub = engine.stateRx.listen(states.add);
      addTearDown(stateSub.cancel);
      addTearDown(engine.dispose);

      const streamUrl = String.fromEnvironment(
        'LIVE_STREAM_URL',
        defaultValue: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      );

      debugPrint('PIPELINE_STAGE engine_initial_kind=${engine.engineKind} '
          'adapter=${engine.adapter.runtimeType}');

      await engine.initialize();
      debugPrint('PIPELINE_STAGE engine_initialized '
          'adapter_initialized=${engine.adapter.isInitialized} '
          'vlc_supported=${VlcPlayerAdapter.isSupported}');

      final session = PlayableSession(
        sessionId: 'android-full-pipeline-1',
        mediaItemId: 'android-full-pipeline-1',
        providerId: 'pipeline-smoke',
        providerType: MediaSourceType.m3u,
        streamUrl: streamUrl,
        streamType: StreamType.httpsLive,
        userAgent: 'StreamHub/1.0',
      );

      final playFuture = engine
          .playFromStreamEngine(session)
          .then((value) {
            debugPrint('PIPELINE_STAGE playFromStreamEngine_resolved '
                'engine_kind=${engine.engineKind} '
                'adapter=${engine.adapter.runtimeType}');
          })
          .catchError((Object e) {
            debugPrint('PIPELINE_STAGE playFromStreamEngine_THREW: $e');
            throw e;
          });

      // Mount the adapter's video surface so platform views can initialize.
      await tester.pumpWidget(
        MaterialApp(
          home: ColoredBox(
            color: Colors.black,
            child: Center(child: engine.adapter.buildPlayerWidget()),
          ),
        ),
      );

      var done = false;
      playFuture.then<void>((_) => done = true).catchError((Object _) {
        done = true;
      });
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (!done && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 250));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await playFuture.catchError((Object _) {});

      debugPrint('PIPELINE_STAGE after_load state=${engine.stateRx.value} '
          'engine_kind=${engine.engineKind} '
          'adapter=${engine.adapter.runtimeType}');

      // Give the native backend a chance to actually render video frames.
      var videoPixels = 0;
      final renderDeadline = DateTime.now().add(const Duration(seconds: 20));
      while (DateTime.now().isBefore(renderDeadline)) {
        await tester.pump(const Duration(milliseconds: 500));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final adapter = engine.adapter;
        if (adapter is MediaKitPlayerAdapter) {
          videoPixels =
              (adapter.player?.state.width ?? 0) *
              (adapter.player?.state.height ?? 0);
        }
        if (videoPixels > 0) break;
      }

      BufferInfo? bufferInfo;
      try {
        bufferInfo = await engine.adapter.getBufferInfo();
      } catch (_) {
        bufferInfo = null;
      }
      debugPrint(
        'PIPELINE_STAGE final state=${engine.stateRx.value} '
        'engine_kind=${engine.engineKind} '
        'adapter=${engine.adapter.runtimeType} '
        'video_pixels=$videoPixels '
        'position=${engine.positionRx.value} '
        'buffer_pct=${bufferInfo?.bufferPercentage} '
        'buffer_healthy=${bufferInfo?.isHealthy} '
        'error=${engine.errorMessageRx.value}',
      );
      debugPrint('PIPELINE_STATE_SEQUENCE ${states.join(" -> ")}');

      await tester.pump(const Duration(seconds: 1));
    },
  );
}
