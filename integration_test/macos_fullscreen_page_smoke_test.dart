import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/media/player/media_kit_player_adapter.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/prepared_download.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
import 'package:stream_hub/modules/player/pages/fullscreen_player_page.dart';

/// Reproduces the production full-screen playback flow on macOS with the real
/// [FullscreenPlayerPage] widget tree (Stack overlays, state-driven rebuilds)
/// driving a real [PlayerController]/[PlaybackEngine] backed by a fake
/// [StreamRepository] that returns a local MPEG-TS stream.
///
/// This mirrors the app exactly: the player page mounts the video surface
/// while playback is starting (not before), and rebuilds on every engine
/// state change.
///
///   flutter test integration_test/macos_fullscreen_page_smoke_test.dart \
///     -d macos --dart-define=LIVE_STREAM_URL=http://127.0.0.1:8899/stream_test.ts
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'FullscreenPlayerPage renders the video surface and reaches playing',
    (tester) async {
      mk.MediaKit.ensureInitialized();

      final controller = PlayerController(
        streamRepository: _FakeStreamRepository(),
      );
      Get.put(controller);

      await tester.pumpWidget(
        const MaterialApp(home: FullscreenPlayerPage()),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final engine = controller.playbackController.engine;
      final states = <PlaybackState>[];
      final stateSub = engine.stateRx.listen(states.add);
      addTearDown(stateSub.cancel);
      addTearDown(Get.delete<PlayerController>);

      final item = MediaItem(
        id: 'local-ts-1',
        providerId: 'fake',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'Local MPEG-TS',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      unawaited(controller.playMediaItem(item));

      await _waitUntil(
        'engine reaches playing',
        () => engine.stateRx.value == PlaybackState.playing,
        timeout: const Duration(seconds: 45),
      );

      await _waitUntil(
        'video frames are decoded (width/height resolved)',
        () async {
          final adapter = engine.adapter;
          if (adapter is! MediaKitPlayerAdapter) return false;
          return (adapter.player?.state.width ?? 0) > 0;
        },
        timeout: const Duration(seconds: 45),
      );

      final mkAdapter = engine.adapter as MediaKitPlayerAdapter;
      debugPrint(
        'FULLSCREEN_SMOKE state=${engine.stateRx.value} '
        'size=${mkAdapter.player?.state.width}x'
        '${mkAdapter.player?.state.height} '
        'position=${engine.positionRx.value}',
      );

      // The video surface must actually be mounted while playing — the bug
      // surfaces here as a black screen with the Texture widget absent.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      final videos = find.byType(Video);
      debugPrint(
        'FULLSCREEN_SMOKE Video widgets in tree: ${tester.widgetList(videos).length}',
      );
      expect(videos, findsWidgets,
          reason: 'MediaKit Video surface must be mounted while playing');

      // No loading/buffering overlay may cover the video in the playing state.
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'State overlay must be hidden once playing',
      );

      expect(states, contains(PlaybackState.playing));
      expect(engine.stateRx.value, PlaybackState.playing);

      await tester.pump(const Duration(seconds: 2));
      debugPrint(
        'FULLSCREEN_SMOKE final position=${engine.positionRx.value} '
        'buffer=${engine.bufferRx.value}',
      );
    },
  );
}

class _FakeStreamRepository implements StreamRepository {
  @override
  Future<PlayableSession> resolvePlayback({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
    bool useCache = true,
    bool validate = true,
  }) async {
    return PlayableSession(
      sessionId: 'session_$mediaItemId',
      mediaItemId: mediaItemId,
      providerId: providerId ?? 'fake',
      providerType: providerType,
      streamUrl: const String.fromEnvironment(
        'LIVE_STREAM_URL',
        defaultValue: 'http://127.0.0.1:8899/stream_test.ts',
      ),
      streamType: StreamType.mpegTs,
      userAgent: 'StreamHub/1.0',
      supportsSeeking: false,
      supportsPause: true,
    );
  }

  @override
  Future<PlayableSession> resolveStream({
    required String mediaItemId,
    required String url,
    required ProviderSession providerSession,
    Map<String, dynamic> itemMetadata = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PreparedDownload> prepareDownload({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
    bool validate = true,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<bool> validate(PlayableSession session) async => true;

  @override
  Future<PlayableSession> selectWorking(PlayableSession session) async =>
      session;

  @override
  Future<void> startBackgroundTasks() async {}

  @override
  Future<void> stopBackgroundTasks() async {}
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
      debugPrint('FULLSCREEN_SMOKE condition met: $description');
      return true;
    }
    await Future<void>.delayed(interval);
  }
  debugPrint('FULLSCREEN_SMOKE timeout waiting for: $description');
  return false;
}
