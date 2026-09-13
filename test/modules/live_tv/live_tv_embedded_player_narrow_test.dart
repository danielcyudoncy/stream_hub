import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/data/models/channel.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/modules/live_tv/controllers/live_tv_controller.dart';
import 'package:stream_hub/modules/live_tv/widgets/live_tv_embedded_player.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';

class _FakeCatalogRepository implements CatalogRepository {
  @override
  Stream<void> watchUpdates() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMediaEngine implements MediaEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMediaLibrary implements MediaLibrary {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFavoriteRepository implements FavoriteRepository {
  @override
  Stream<void> watchUpdates() => const Stream.empty();

  @override
  Future<List<MediaItem>> getAll() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubStreamRepository implements StreamRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubPlayerAdapter implements PlayerAdapter {
  final _stateController = StreamController<PlaybackState>.broadcast();

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.mediaKit;
  @override
  bool get isInitialized => true;
  @override
  Widget buildPlayerWidget() => const SizedBox.shrink();
  @override
  Future<void> initialize() async {}
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
  Future<void> dispose() async {
    await _stateController.close();
  }
  @override
  PlaybackState get state => PlaybackState.playing;
  @override
  Stream<PlaybackState> get stateStream => _stateController.stream;
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
  Future<List<PlayerQuality>> getAvailableQualities() async => const [PlayerQuality.auto];
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
  Stream<Duration> get positionStream => const Stream<Duration>.empty();
  @override
  Stream<Duration> get bufferStream => const Stream<Duration>.empty();
  @override
  Stream<String> get errorStream => const Stream<String>.empty();
  @override
  Stream<String> get subtitleStream => const Stream<String>.empty();
  @override
  Future<void> enterPictureInPicture() async {}
  @override
  bool get isInPip => false;
}

void main() {
  tearDown(() {
    Get.reset();
  });

  testWidgets(
    'renders player overlay controls in narrow landscape container without RenderFlex overflow',
    (tester) async {
      final channel = Channel(
        id: 'ch-test-1',
        providerId: 'prov-1',
        providerType: MediaSourceType.m3u,
        title: 'Sky Sports Premier League Ultra HD',
        mediaType: MediaType.channel,
        number: '101',
        isLive: true,
        genres: const ['Sports & Entertainment'],
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final liveTvCtrl = LiveTVController(
        mediaEngine: _FakeMediaEngine(),
        mediaLibrary: _FakeMediaLibrary(),
        catalogRepository: _FakeCatalogRepository(),
        favoriteRepository: _FakeFavoriteRepository(),
      );
      Get.put<LiveTVController>(liveTvCtrl);

      final playerCtrl = PlayerController(
        adapter: _StubPlayerAdapter(),
        engineKind: PlaybackEngineKind.mediaKit,
        streamRepository: _StubStreamRepository(),
      );
      Get.put<PlayerController>(playerCtrl);
      liveTvCtrl.inlinePlayerController = playerCtrl;
      liveTvCtrl.activePlayingChannel.value = channel;
      playerCtrl.playbackController.engine.stateRx.value = PlaybackState.playing;

      // Pump inside a tight 170.3px constraint (the exact width from the user's landscape overflow)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 170.3,
                height: 149.0,
                child: LiveTvEmbeddedPlayer(
                  controller: liveTvCtrl,
                  isFullscreen: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // In micro width (170.3px), 'LIVE' text is condensed to red indicator dot
      // Essential controls remain available without any RenderFlex overflow
      expect(find.text('Sky Sports Premier League Ultra HD'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_filled_rounded), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'renders all controls when space permits (>= 350px)',
    (tester) async {
      final channel = Channel(
        id: 'ch-test-2',
        providerId: 'prov-1',
        providerType: MediaSourceType.m3u,
        title: 'Sky Sports Main Event',
        mediaType: MediaType.channel,
        number: '102',
        isLive: true,
        genres: const ['Sports'],
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final liveTvCtrl = LiveTVController(
        mediaEngine: _FakeMediaEngine(),
        mediaLibrary: _FakeMediaLibrary(),
        catalogRepository: _FakeCatalogRepository(),
        favoriteRepository: _FakeFavoriteRepository(),
      );
      Get.put<LiveTVController>(liveTvCtrl);

      final playerCtrl = PlayerController(
        adapter: _StubPlayerAdapter(),
        engineKind: PlaybackEngineKind.mediaKit,
        streamRepository: _StubStreamRepository(),
      );
      Get.put<PlayerController>(playerCtrl);
      liveTvCtrl.inlinePlayerController = playerCtrl;
      liveTvCtrl.activePlayingChannel.value = channel;
      playerCtrl.playbackController.engine.stateRx.value = PlaybackState.playing;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400.0,
                height: 250.0,
                child: LiveTvEmbeddedPlayer(
                  controller: liveTvCtrl,
                  isFullscreen: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('102'), findsOneWidget);
      expect(find.text('Sky Sports Main Event'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_filled_rounded), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    },
  );
}
