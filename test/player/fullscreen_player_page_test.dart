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
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/prepared_download.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
import 'package:stream_hub/modules/player/pages/fullscreen_player_page.dart';
import 'package:stream_hub/modules/player/widgets/player_touch_gesture_overlay.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

/// Remote/keyboard coverage for the fullscreen player: every on-screen control
/// icon (transport, settings popups, subtitle/audio sheets, favorite, back,
/// fullscreen exit) must render, expose a live focus handler, and react to
/// activation on the desktop path (PiP is Android-only and must stay hidden).
void main() {
  setUp(Get.reset);

  testWidgets(
    'fullscreen player renders every control icon with a live focus handler',
    (tester) async {
      await _startPlayer(tester);
      final expected = <IconData>[
        AppIcons.back,
        Icons.favorite_border,
        AppIcons.previous,
        AppIcons.rewind,
        AppIcons.pause,
        AppIcons.stop,
        AppIcons.forward,
        AppIcons.next,
        AppIcons.aspectRatio,
        AppIcons.speed,
        AppIcons.quality,
        AppIcons.subtitles,
        AppIcons.audioTrack,
        AppIcons.fullscreenExit,
      ];
      for (final icon in expected) {
        expect(find.byIcon(icon), findsWidgets, reason: 'missing $icon');
      }
      expect(
        find.byIcon(Icons.picture_in_picture_alt),
        findsNothing,
        reason: 'PiP control must stay hidden on non-Android platforms',
      );
      expect(find.byIcon(AppIcons.forward), findsOneWidget);
      expect(find.byIcon(AppIcons.pause), findsOneWidget);

      _expectNoDeadFocusTargets(tester, 'Player');

      await _disposePlayer(tester);
    },
  );

  testWidgets('transport controls: seek back/forward, play/pause, stop', (
    tester,
  ) async {
    final (adapter, _) = await _startPlayer(tester);

    await tester.tap(find.byIcon(AppIcons.rewind));
    await tester.pumpAndSettle();
    expect(
      adapter.seeks,
      contains(Duration(seconds: -10)),
      reason: 'rewind must seek 10s back',
    );

    await tester.tap(find.byIcon(AppIcons.forward));
    await tester.pumpAndSettle();
    expect(
      adapter.seeks,
      contains(Duration(seconds: 10)),
      reason: 'forward must seek 10s forward',
    );

    await tester.tap(find.byIcon(AppIcons.pause));
    await tester.pumpAndSettle();
    expect(adapter.pauseCount, 1, reason: 'pause must reach the adapter');
    expect(find.byIcon(AppIcons.pause), findsNothing);
    expect(
      find.byIcon(AppIcons.play),
      findsWidgets,
      reason: 'icon must reflect the paused state',
    );

    await tester.tap(find.byIcon(AppIcons.play));
    await tester.pumpAndSettle();
    expect(adapter.playCount, 1, reason: 'play must reach the adapter');
    expect(find.byIcon(AppIcons.pause), findsWidgets);

    await tester.tap(find.byIcon(AppIcons.stop));
    await tester.pumpAndSettle();
    expect(adapter.stopCount, 1, reason: 'stop must reach the adapter');
    expect(
      find.text('BASE'),
      findsOneWidget,
      reason: 'stop must leave the fullscreen player route',
    );

    await _disposePlayer(tester);
  });

  testWidgets('favorite icon toggles the item in the favorites repository', (
    tester,
  ) async {
    final (_, favorites) = await _startPlayer(tester);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();
    expect(favorites.added, hasLength(1));
    expect(
      favorites.added.single.favorite,
      isTrue,
      reason: 'favorited item must be stored with favorite=true',
    );
    expect(
      find.byIcon(Icons.favorite),
      findsWidgets,
      reason: 'icon must fill when favorited',
    );

    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();
    expect(
      favorites.removed,
      contains('movie-1'),
      reason: 'second tap must un-favorite the item',
    );
    expect(
      find.byIcon(Icons.favorite_border),
      findsWidgets,
      reason: 'icon must return to outline when removed',
    );

    await _disposePlayer(tester);
  });

  testWidgets('settings popups: speed, aspect ratio, and quality apply', (
    tester,
  ) async {
    final (adapter, _) = await _startPlayer(tester);

    await _tapIcon(tester, AppIcons.speed);
    await tester.tap(find.text('1.5x'));
    await tester.pumpAndSettle();
    expect(adapter.lastSpeed, PlaybackSpeed.speed1_5);

    await _tapIcon(tester, AppIcons.aspectRatio);
    await tester.tap(find.text('16:9'));
    await tester.pumpAndSettle();
    expect(adapter.lastAspectRatio, AspectRatioMode.ratio16x9);

    await _tapIcon(tester, AppIcons.quality);
    await tester.tap(find.text('1080p'));
    await tester.pumpAndSettle();
    expect(adapter.lastQuality, PlayerQuality.p1080);

    await _disposePlayer(tester);
  });

  testWidgets('subtitle sheet opens and applies a track selection', (
    tester,
  ) async {
    final (adapter, _) = await _startPlayer(tester);

    await tester.tap(find.byIcon(AppIcons.subtitles));
    await tester.pumpAndSettle();
    expect(
      find.text('Off'),
      findsWidgets,
      reason: 'subtitle sheet must list the Off option',
    );
    expect(
      find.text('English'),
      findsWidgets,
      reason: 'subtitle sheet must list the subtitle track',
    );

    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();
    expect(adapter.lastSubtitleTrack, 'no');
    expect(
      find.text('Off'),
      findsNothing,
      reason: 'sheet must close after applying the track',
    );

    await _disposePlayer(tester);
  });

  testWidgets('audio track sheet opens and applies a track selection', (
    tester,
  ) async {
    final (adapter, _) = await _startPlayer(tester);

    await tester.tap(find.byIcon(AppIcons.audioTrack));
    await tester.pumpAndSettle();
    expect(
      find.text('English'),
      findsWidgets,
      reason: 'audio sheet must list the English track',
    );
    expect(
      find.text('Spanish'),
      findsWidgets,
      reason: 'audio sheet must list the Spanish track',
    );

    await tester.tap(find.text('Spanish'));
    await tester.pumpAndSettle();
    expect(adapter.lastAudioTrack, '2');

    await _disposePlayer(tester);
  });

  testWidgets('top bar back and fullscreen-exit icons both leave the player', (
    tester,
  ) async {
    await _startPlayer(tester);

    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();
    expect(
      find.text('BASE'),
      findsOneWidget,
      reason: 'top bar back must return to the previous screen',
    );

    await _openPlayer(tester);
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.fullscreenExit), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.fullscreenExit));
    await tester.pumpAndSettle();
    expect(
      find.text('BASE'),
      findsOneWidget,
      reason: 'fullscreen-exit must return to the previous screen',
    );

    await _disposePlayer(tester);
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Future<(_FakePlayerAdapter, _FakeFavoriteRepository)> _startPlayer(
  WidgetTester tester,
) async {
  final adapter = _FakePlayerAdapter();
  final favorites = _FakeFavoriteRepository();
  final controller = PlayerController(
    adapter: adapter,
    engineKind: PlaybackEngineKind.mediaKit,
    streamRepository: _StubStreamRepository(),
    favoriteRepository: favorites,
  );
  Get.put(controller);
  addTearDown(Get.delete<PlayerController>);

  final movie = MediaItem(
    id: 'movie-1',
    providerId: 'prov-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.movie,
    title: 'Test Movie',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
  final session = PlayableSession(
    sessionId: 'session-1',
    mediaItemId: movie.id,
    providerId: movie.providerId,
    providerType: movie.providerType,
    streamUrl: 'https://example.com/movie.m3u8',
    streamType: StreamType.hls,
    supportsPause: true,
    supportsSeeking: true,
    supportsSubtitles: true,
    supportsAudioTracks: true,
    supportsPiP: true,
    metadata: const {'title': 'Test Movie'},
  );
  await controller.playWithSession(movie, session);
  await _openPlayer(tester);
  // Let the controller's delayed subtitle auto-selection fire so it does not
  // leave a pending timer behind when the test finishes.
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
  return (adapter, favorites);
}

/// Tears the player down inside the test body so the engine's periodic
/// analytics/buffer timers are cancelled before the binding verifies that no
/// timers are pending.
/// Taps a player control icon, first re-revealing the controls overlay if the
/// page's 4s auto-hide has already hidden it.
Future<void> _tapIcon(WidgetTester tester, IconData icon) async {
  if (find.byIcon(icon).evaluate().isEmpty) {
    await tester.tap(
      find.byType(PlayerTouchGestureOverlay),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle();
}

Future<void> _disposePlayer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  if (Get.isRegistered<PlayerController>()) {
    final controller = Get.find<PlayerController>();
    // Cancel the engine's periodic analytics/buffer timers synchronously.
    controller.playbackController.engine.dispose();
    Get.delete<PlayerController>(force: true);
  }
  await tester.pump();
}

Future<void> _openPlayer(WidgetTester tester) async {
  await tester.pumpWidget(
    const GetMaterialApp(
      home: Scaffold(body: Center(child: Text('BASE'))),
    ),
  );
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.push(
    MaterialPageRoute<void>(builder: (_) => const FullscreenPlayerPage()),
  );
  await tester.pumpAndSettle();
}

void _expectNoDeadFocusTargets(WidgetTester tester, String label) {
  final focusables = tester
      .widgetList<TvFocusable>(find.byType(TvFocusable))
      .toList();
  expect(focusables, isNotEmpty, reason: '$label has no focusable elements');
  for (final w in focusables) {
    expect(
      w.onTap != null || w.onLongPress != null || w.onKeyEvent != null,
      isTrue,
      reason:
          '$label contains a dead focus target (no handler): '
          '${w.itemId ?? w.regionId}',
    );
  }
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakePlayerAdapter implements PlayerAdapter {
  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _buffers =
      StreamController<Duration>.broadcast();
  final StreamController<String> _errors = StreamController<String>.broadcast();
  final StreamController<String> _subtitles =
      StreamController<String>.broadcast();

  int playCount = 0;
  int pauseCount = 0;
  int stopCount = 0;
  final List<Duration> seeks = [];
  PlaybackSpeed? lastSpeed;
  AspectRatioMode? lastAspectRatio;
  PlayerQuality? lastQuality;
  String? lastSubtitleTrack;
  String? lastAudioTrack;
  bool _initialized = false;

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.mediaKit;

  @override
  bool get isInitialized => _initialized;

  @override
  Widget buildPlayerWidget() => const SizedBox(key: ValueKey('video-surface'));

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<void> dispose() async {
    await _states.close();
    await _positions.close();
    await _buffers.close();
    await _errors.close();
    await _subtitles.close();
  }

  @override
  Future<void> load(PlayableMediaSession session) async {}

  @override
  Future<void> playSession(PlayableSession session, {String? title}) async {}

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
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
  PlaybackState get state => PlaybackState.playing;

  @override
  Duration get position => seeks.isEmpty ? Duration.zero : seeks.last;

  @override
  Duration get duration => const Duration(minutes: 90);

  @override
  Duration get bufferPosition => Duration.zero;

  @override
  double get volume => 1.0;

  @override
  bool get isMuted => false;

  @override
  PlaybackSpeed get speed => lastSpeed ?? PlaybackSpeed.speed1_0;

  @override
  AspectRatioMode get aspectRatio => lastAspectRatio ?? AspectRatioMode.fit;

  @override
  PlayerQuality get currentQuality => lastQuality ?? PlayerQuality.auto;

  @override
  Future<List<dynamic>> getAvailableAudioTracks() async => [
    {'id': '1', 'label': 'English', 'selected': false},
    {'id': '2', 'label': 'Spanish', 'selected': false},
  ];

  @override
  Future<List<dynamic>> getAvailableSubtitleTracks() async => [
    {'id': 'en', 'label': 'English', 'selected': false},
  ];

  @override
  Future<List<PlayerQuality>> getAvailableQualities() async => const [
    PlayerQuality.auto,
    PlayerQuality.p1080,
    PlayerQuality.p720,
  ];

  @override
  Future<void> setAudioTrack(String trackId) async {
    lastAudioTrack = trackId;
  }

  @override
  Future<void> setSubtitleTrack(String trackId) async {
    lastSubtitleTrack = trackId;
  }

  @override
  Future<void> setSpeed(PlaybackSpeed speed) async {
    lastSpeed = speed;
  }

  @override
  Future<void> setAspectRatio(AspectRatioMode mode) async {
    lastAspectRatio = mode;
  }

  @override
  Future<void> setQuality(PlayerQuality quality) async {
    lastQuality = quality;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<BufferInfo> getBufferInfo() async => BufferInfo(
    currentBuffer: Duration.zero,
    totalDuration: const Duration(minutes: 90),
    bufferPercentage: 0,
    bufferHealthMs: 0,
    measuredAt: DateTime(2024),
  );

  @override
  Stream<PlaybackState> get stateStream => _states.stream;

  @override
  Stream<Duration> get positionStream => _positions.stream;

  @override
  Stream<Duration> get bufferStream => _buffers.stream;

  @override
  Stream<String> get errorStream => _errors.stream;

  @override
  Stream<String> get subtitleStream => _subtitles.stream;

  @override
  Future<void> enterPictureInPicture() async {}

  @override
  bool get isInPip => false;
}

class _FakeFavoriteRepository implements FavoriteRepository {
  final List<MediaItem> added = [];
  final List<String> removed = [];

  @override
  Stream<void> watchUpdates() => const Stream.empty();

  @override
  Future<void> add(MediaItem item) async {
    added.add(item);
  }

  @override
  Future<void> remove(String itemId) async {
    removed.add(itemId);
  }

  @override
  Future<List<MediaItem>> getAll() async => List.of(added);

  @override
  Future<bool> isFavorite(String itemId) async =>
      added.any((i) => i.id == itemId);

  @override
  Future<void> clear() async {}

  @override
  Future<int> get count async => added.length;
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
