import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/streaming/auth/authentication_engine.dart';
import 'package:stream_hub/core/streaming/cache/session_cache.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/core/streaming/series/xtream_series_info_service.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory_registry.dart';
import 'package:stream_hub/core/streaming/session/session_manager.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
import 'package:stream_hub/modules/series/series_details_controller.dart';
import 'package:stream_hub/modules/series/widgets/series_inline_player.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

import '../../stream_engine/fakes/fake_local_service.dart';

class _FakePlayerAdapter implements PlayerAdapter {
  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durations =
      StreamController<Duration>.broadcast();

  bool playCalled = false;
  bool pauseCalled = false;
  Duration? lastSeekPosition;
  Duration currentPosition = const Duration(minutes: 5);

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.mediaKit;

  @override
  bool get isInitialized => true;

  @override
  Widget buildPlayerWidget() => const SizedBox.expand();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playSession(PlayableSession session, {String? title}) async {
    _states.add(PlaybackState.playing);
  }

  @override
  Stream<PlaybackState> get stateStream => _states.stream;

  @override
  Stream<Duration> get positionStream => _positions.stream;

  Stream<Duration> get durationStream => _durations.stream;

  @override
  Future<void> play() async {
    playCalled = true;
    _states.add(PlaybackState.playing);
  }

  @override
  Future<void> resume() async {
    playCalled = true;
    _states.add(PlaybackState.playing);
  }

  @override
  Future<void> pause() async {
    pauseCalled = true;
    _states.add(PlaybackState.paused);
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeekPosition = position;
    currentPosition = position;
    _positions.add(position);
  }

  @override
  Future<void> dispose() async {
    await _states.close();
    await _positions.close();
    await _durations.close();
  }

  @override
  Stream<Duration> get bufferStream => const Stream<Duration>.empty();

  @override
  Stream<String> get errorStream => const Stream<String>.empty();

  @override
  Stream<String> get subtitleStream => const Stream<String>.empty();

  @override
  PlaybackState get state => PlaybackState.playing;

  @override
  Duration get position => currentPosition;

  @override
  Duration get duration => const Duration(hours: 1);

  @override
  Duration get bufferPosition => const Duration(minutes: 10);

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
  Future<void> stop() async {
    _states.add(PlaybackState.stopped);
  }

  @override
  Future<void> replay() async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> retry() async {}

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
  Future<void> enterPictureInPicture() async {}

  @override
  bool get isInPip => false;

  @override
  Future<void> load(PlayableMediaSession session) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubStreamRepository implements StreamRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCatalogRepository implements CatalogRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProviderRepository implements ProviderRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSeriesInfoService extends XtreamSeriesInfoService {
  @override
  Future<XtreamSeriesInfo> fetch({
    required ProviderSession session,
    required String seriesId,
    List<String> alternativeIds = const [],
  }) async {
    return const XtreamSeriesInfo(seriesId: 's1', name: 'Test Series', seasons: []);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePlayerAdapter fakeAdapter;
  late PlayerController playerController;
  late SeriesDetailsController seriesDetailsController;
  late MediaItem testSeries;
  late MediaItem testEpisode;

  setUp(() async {
    Get.reset();
    fakeAdapter = _FakePlayerAdapter();
    playerController = PlayerController(
      adapter: fakeAdapter,
      engineKind: PlaybackEngineKind.mediaKit,
      streamRepository: _StubStreamRepository(),
    );

    final now = DateTime.now();
    testSeries = MediaItem(
      id: 'series-1',
      providerId: 'prov-1',
      providerType: MediaSourceType.xtream,
      mediaType: MediaType.series,
      title: 'Breaking Bad',
      createdAt: now,
      updatedAt: now,
    );

    testEpisode = MediaItem(
      id: 'ep-1',
      providerId: 'prov-1',
      providerType: MediaSourceType.xtream,
      mediaType: MediaType.series,
      title: 'Pilot',
      metadata: {'seasonNumber': 1, 'episodeNumber': 1},
      createdAt: now,
      updatedAt: now,
    );

    final sessionCache = SessionCache(FakeLocalService());
    final sessionManager = SessionManager(
      sessionCache: sessionCache,
      authenticationEngine: AuthenticationEngine(),
      cookieManager: CookieManager(),
      registry: ProviderSessionFactoryRegistry(),
    );

    Get.routing.args = testSeries;
    seriesDetailsController = SeriesDetailsController(
      sessionManager: sessionManager,
      providerRepository: _FakeProviderRepository(),
      catalogRepository: _FakeCatalogRepository(),
      seriesInfoService: _FakeSeriesInfoService(),
      initialSeries: testSeries,
    );
    seriesDetailsController.onInit();
    seriesDetailsController.activeEpisode.value = testEpisode;
    seriesDetailsController.inlinePlayerController = playerController;

    final session = PlayableSession(
      sessionId: 'session-ep-1',
      mediaItemId: testEpisode.id,
      providerId: testEpisode.providerId,
      providerType: testEpisode.providerType,
      streamUrl: 'http://example.com/ep1.mp4',
      streamType: StreamType.mp4,
      supportsSeeking: true,
      supportsPause: true,
    );
    await playerController.playbackController.engine.playFromStreamEngine(
      session,
      mediaItem: testEpisode,
    );
  });

  tearDown(() async {
    await playerController.playbackController.stop();
    playerController.dispose();
    Get.reset();
  });

  testWidgets(
    'SeriesInlinePlayer TV remote D-pad navigation and OK button are fully functional',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SeriesInlinePlayer(
              controller: seriesDetailsController,
              isFullscreen: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial state: controls are visible and Play/Pause has focus
      final playPauseNode = tester.widgetList<TvFocusable>(find.byType(TvFocusable)).firstWhere(
        (w) => w.focusNode?.debugLabel == 'SeriesPlayPause',
      );
      expect(playPauseNode.focusNode?.hasFocus, isTrue);

      // 2. Remote OK on Play/Pause triggers togglePlayPause
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(fakeAdapter.pauseCalled || fakeAdapter.playCalled, isTrue);

      // 3. Arrow Left moves focus to Replay 10s button
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      final replayNode = tester.widgetList<TvFocusable>(find.byType(TvFocusable)).firstWhere(
        (w) => w.focusNode?.debugLabel == 'SeriesReplay',
      );
      expect(replayNode.focusNode?.hasFocus, isTrue);

      // 4. Arrow Left again moves focus to Skip Previous Episode
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      final skipPrevNode = tester.widgetList<TvFocusable>(find.byType(TvFocusable)).firstWhere(
        (w) => w.focusNode?.debugLabel == 'SeriesSkipPrev',
      );
      expect(skipPrevNode.focusNode?.hasFocus, isTrue);

      // 5. Arrow Right moves back to Replay 10s
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(replayNode.focusNode?.hasFocus, isTrue);

      // 6. Arrow Right moves back to Play/Pause
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(playPauseNode.focusNode?.hasFocus, isTrue);

      // 7. Arrow Right moves to Forward 10s
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      final forwardNode = tester.widgetList<TvFocusable>(find.byType(TvFocusable)).firstWhere(
        (w) => w.focusNode?.debugLabel == 'SeriesForward',
      );
      expect(forwardNode.focusNode?.hasFocus, isTrue);

      // 8. Arrow Right moves to Skip Next Episode
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      final skipNextNode = tester.widgetList<TvFocusable>(find.byType(TvFocusable)).firstWhere(
        (w) => w.focusNode?.debugLabel == 'SeriesSkipNext',
      );
      expect(skipNextNode.focusNode?.hasFocus, isTrue);

      // 9. Arrow Down from Skip Next Episode moves focus to Seekbar
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final seekbarNode = tester.widgetList<TvFocusable>(find.byType(TvFocusable)).firstWhere(
        (w) => w.focusNode?.debugLabel == 'SeriesSeekbar',
      );
      expect(seekbarNode.focusNode?.hasFocus, isTrue);

      // 10. Arrow Left on Seekbar triggers seek backwards
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(fakeAdapter.lastSeekPosition, isNotNull);

      // 11. Arrow Up from Seekbar moves focus back to Play/Pause
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(playPauseNode.focusNode?.hasFocus, isTrue);

      // 12. Arrow Up from Play/Pause moves focus to Back button
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      final backNode = tester.widgetList<TvFocusable>(find.byType(TvFocusable)).firstWhere(
        (w) => w.focusNode?.debugLabel == 'SeriesBack',
      );
      expect(backNode.focusNode?.hasFocus, isTrue);

      // 13. Arrow Down from Back button moves focus back to Play/Pause
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(playPauseNode.focusNode?.hasFocus, isTrue);

      // Resume playback so auto-hide timer can engage while playing
      await playerController.playbackController.resume();
      await tester.pumpAndSettle();

      // 14. Wait for controls to auto-hide after 5 seconds
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      // 15. Remote OK button wakes up controls and focuses Play/Pause again!
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      final playPauseAfterNode = tester.widgetList<TvFocusable>(find.byType(TvFocusable)).firstWhere(
        (w) => w.focusNode?.debugLabel == 'SeriesPlayPause',
      );
      expect(playPauseAfterNode.focusNode?.hasFocus, isTrue);

      await playerController.playbackController.stop();
    },
  );
}
