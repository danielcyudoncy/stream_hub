// test/modules/free_live_tv/free_tv_embedded_player_narrow_test.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/repositories/free_tv_repository.dart';
import 'package:stream_hub/modules/free_live_tv/controllers/free_live_tv_controller.dart';
import 'package:stream_hub/modules/free_live_tv/widgets/free_tv_embedded_player.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';

class _FakeFreeTvRepository implements FreeTvRepository {
  @override
  Future<List<FreeTvChannel>> getCatalog({bool forceRefresh = false}) async =>
      const [];

  @override
  Set<String> getFavoriteIds() => <String>{};

  @override
  Future<bool> isFavorite(String channelId) async => false;

  @override
  Future<bool> toggleFavorite(String channelId) async => true;

  @override
  Stream<Set<String>> watchFavorites() => const Stream.empty();

  @override
  Future<List<FreeTvChannel>> getRecentlyWatched() async => const [];

  @override
  Future<void> recordWatch(FreeTvChannel channel) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubStreamRepository implements StreamRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubPlayerAdapter implements PlayerAdapter {
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
  Future<void> dispose() async {}
  @override
  PlaybackState get state => PlaybackState.playing;
  @override
  Stream<PlaybackState> get stateStream => const Stream.empty();
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
  Future<List<PlayerQuality>> getAvailableQualities() async => const [
    PlayerQuality.auto,
  ];
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
    'keeps free TV mini-player controls usable in narrow landscape without overflow',
    (tester) async {
      final channel = const FreeTvChannel(
        id: 'free-ng-1',
        name: 'Channels Television',
        country: 'Nigeria',
        countryCode: 'NG',
        categories: ['News'],
        streamUrls: ['https://example.com/live.m3u8'],
      );

      final controller = FreeLiveTvController(
        repository: _FakeFreeTvRepository(),
      );
      Get.put<FreeLiveTvController>(controller);

      final playerCtrl = PlayerController(
        adapter: _StubPlayerAdapter(),
        engineKind: PlaybackEngineKind.mediaKit,
        streamRepository: _StubStreamRepository(),
      );
      controller.inlinePlayerController = playerCtrl;
      controller.activePlayingChannel.value = channel;
      playerCtrl.playbackController.engine.stateRx.value =
          PlaybackState.playing;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 170.3,
                height: 149.0,
                child: FreeTvEmbeddedPlayer(
                  controller: controller,
                  isFullscreen: false,
                  autofocus: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_filled_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    },
  );
}
