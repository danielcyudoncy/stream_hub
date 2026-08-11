import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/prepared_download.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
import 'package:stream_hub/modules/player/pages/embedded_player_page.dart';

const _surfaceKey = Key('video-surface');

/// Regression test for the macOS "audio but no video" class of bugs:
/// the embedded video layer must mount the backend surface once the engine
/// initializes the adapter, even when the engine kind never changes (desktop
/// where VLC is unavailable) — i.e. it must react to playback state, not only
/// to backend switches.
void main() {
  testWidgets(
    'embedded player mounts the video surface when playback starts '
    'without an engine-kind switch',
    (tester) async {
      final adapter = _SurfaceTrackingAdapter();
      final controller = PlayerController(
        adapter: adapter,
        engineKind: PlaybackEngineKind.mediaKit,
        streamRepository: _StubStreamRepository(),
      );
      Get.put(controller);
      addTearDown(() {
        Get.delete<PlayerController>();
      });

      await tester.pumpWidget(
        const MaterialApp(home: EmbeddedPlayerPage(showControls: false)),
      );
      await tester.pump();

      expect(
        find.byKey(_surfaceKey),
        findsNothing,
        reason: 'adapter is initialized lazily; surface must start hidden',
      );

      await controller.playbackController.engine.initialize();
      adapter.emit(PlaybackState.buffering);
      // The engine delivers the adapter event on a microtask and GetX's nested
      // Obx needs a frame to re-subscribe after the parent Obx rebuilds, so
      // pump a few frames before asserting.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        find.byKey(_surfaceKey),
        findsOneWidget,
        reason: 'video surface must mount once playback starts, '
            'even though the engine kind never changed',
      );

      adapter.emit(PlaybackState.playing);
      await tester.pump();
      expect(find.byKey(_surfaceKey), findsOneWidget);
    },
  );
}

class _StubStreamRepository implements StreamRepository {
  @override
  Future<PlayableSession> resolvePlayback({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
    bool useCache = true,
    bool validate = true,
  }) {
    throw UnimplementedError();
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

class _SurfaceTrackingAdapter implements PlayerAdapter {
  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();

  bool _initialized = false;

  void emit(PlaybackState state) => _states.add(state);

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.mediaKit;

  @override
  bool get isInitialized => _initialized;

  @override
  Widget buildPlayerWidget() {
    if (!_initialized) return const SizedBox.shrink();
    return const SizedBox(key: _surfaceKey);
  }

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Stream<PlaybackState> get stateStream => _states.stream;

  @override
  Future<void> dispose() async {
    await _states.close();
  }

  @override
  Future<void> load(PlayableMediaSession session) async {}

  @override
  Future<void> playSession(PlayableSession session, {String? title}) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> replay() async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> retry() async {}

  @override
  PlaybackState get state => PlaybackState.idle;

  @override
  Duration get position => Duration.zero;

  @override
  Duration get duration => Duration.zero;

  @override
  Duration get bufferPosition => Duration.zero;

  @override
  double get volume => 1.0;

  @override
  bool get isMuted => false;

  @override
  PlaybackSpeed get speed => PlaybackSpeed.speed1_0;

  @override
  AspectRatioMode get aspectRatio => AspectRatioMode.fit;

  @override
  PlayerQuality get currentQuality => PlayerQuality.auto;

  @override
  Future<List<dynamic>> getAvailableAudioTracks() async => const [];

  @override
  Future<List<dynamic>> getAvailableSubtitleTracks() async => const [];

  @override
  Future<List<PlayerQuality>> getAvailableQualities() async =>
      const [PlayerQuality.auto];

  @override
  Future<void> setAudioTrack(String trackId) async {}

  @override
  Future<void> setSubtitleTrack(String trackId) async {}

  @override
  Future<void> setSpeed(PlaybackSpeed speed) async {}

  @override
  Future<void> setAspectRatio(AspectRatioMode mode) async {}

  @override
  Future<void> setQuality(PlayerQuality quality) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<BufferInfo> getBufferInfo() async => BufferInfo(
        currentBuffer: Duration.zero,
        totalDuration: Duration.zero,
        bufferPercentage: 0,
        bufferHealthMs: 0,
        measuredAt: DateTime.now(),
      );

  @override
  Stream<Duration> get positionStream =>
      const Stream<Duration>.empty();

  @override
  Stream<Duration> get bufferStream => const Stream<Duration>.empty();

  @override
  Stream<String> get errorStream => const Stream<String>.empty();

  @override
  Stream<String> get subtitleStream => const Stream<String>.empty();
}
