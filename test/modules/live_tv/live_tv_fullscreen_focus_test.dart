import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
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
  Future<void> add(MediaItem item) async {}
  @override
  Future<void> remove(String id) async {}
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
  Future<void> setAspectRatio(dynamic mode) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Live TV Fullscreen Controls Focus Tests', () {
    late LiveTVController liveTvCtrl;
    late PlayerController playerCtrl;
    late Channel channel;

    setUp(() {
      Get.reset();
      channel = Channel(
        id: 'ch-test-1',
        providerId: 'prov-1',
        providerType: MediaSourceType.m3u,
        title: 'Sky Sports Premier League',
        mediaType: MediaType.channel,
        number: '101',
        isLive: true,
        genres: const ['Sports'],
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      liveTvCtrl = LiveTVController(
        mediaEngine: _FakeMediaEngine(),
        mediaLibrary: _FakeMediaLibrary(),
        catalogRepository: _FakeCatalogRepository(),
        favoriteRepository: _FakeFavoriteRepository(),
      );
      Get.put<LiveTVController>(liveTvCtrl);

      playerCtrl = PlayerController(
        adapter: _StubPlayerAdapter(),
        engineKind: PlaybackEngineKind.mediaKit,
        streamRepository: _StubStreamRepository(),
      );
      Get.put<PlayerController>(playerCtrl);
      liveTvCtrl.inlinePlayerController = playerCtrl;
      liveTvCtrl.activePlayingChannel.value = channel;
      playerCtrl.playbackController.engine.stateRx.value = PlaybackState.playing;
    });

    tearDown(() {
      liveTvCtrl.stopInlinePlayer();
      Get.reset();
    });

    testWidgets(
        'fullscreen mode focuses interactive center play button and allows D-pad navigation across all bottom controls',
        (tester) async {
      final key = GlobalKey<LiveTvEmbeddedPlayerState>();
      liveTvCtrl.isFullscreenMode.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1280.0,
              height: 720.0,
              child: LiveTvEmbeddedPlayer(
                key: key,
                controller: liveTvCtrl,
                isFullscreen: true,
                autofocus: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Center play button should have primary focus initially
      final initialFocus = FocusManager.instance.primaryFocus;
      expect(initialFocus, isNotNull);
      expect(initialFocus!.debugLabel, equals('LiveTvPlayPause'));

      // 2. Pressing arrowDown should move focus directly to the bottom controls row
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 100));

      final bottomPlayFocus = FocusManager.instance.primaryFocus;
      expect(bottomPlayFocus, isNotNull);
      expect(bottomPlayFocus!.debugLabel, equals('LiveTvBottomPlayPause'));

      // 3. Pressing arrowUp from bottom controls should return to center play button
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump(const Duration(milliseconds: 100));

      final upFocus = FocusManager.instance.primaryFocus;
      expect(upFocus, isNotNull);
      expect(upFocus!.debugLabel, equals('LiveTvPlayPause'));

      // 4. Move down again to bottom controls
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 100));
      expect(FocusManager.instance.primaryFocus!.debugLabel, equals('LiveTvBottomPlayPause'));

      // 5. Navigate right to Stop button
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 100));
      final stopFocus = FocusManager.instance.primaryFocus;
      expect(stopFocus, isNotNull);
      expect(stopFocus!.debugLabel, equals('LiveTvStop'));

      // 6. Navigate right to Favorite button and press Select
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 100));
      final favFocus = FocusManager.instance.primaryFocus;
      expect(favFocus, isNotNull);
      expect(favFocus!.debugLabel, equals('LiveTvFavorite'));

      expect(liveTvCtrl.favorites.isEmpty, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 100));
      expect(liveTvCtrl.favorites.isNotEmpty, isTrue);

      // 7. Navigate right to Aspect Ratio button and press Select
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 100));
      final aspectFocus = FocusManager.instance.primaryFocus;
      expect(aspectFocus, isNotNull);
      expect(aspectFocus!.debugLabel, equals('LiveTvAspectRatio'));

      // 8. Navigate right to Audio Tracks button
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 100));
      final audioFocus = FocusManager.instance.primaryFocus;
      expect(audioFocus, isNotNull);
      expect(audioFocus!.debugLabel, equals('LiveTvAudio'));

      // 9. Navigate right to Subtitles button
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 100));
      final subtitleFocus = FocusManager.instance.primaryFocus;
      expect(subtitleFocus, isNotNull);
      expect(subtitleFocus!.debugLabel, equals('LiveTvSubtitle'));

      // 10. Navigate right to Quick Zapper button
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 100));
      final zapperFocus = FocusManager.instance.primaryFocus;
      expect(zapperFocus, isNotNull);
      expect(zapperFocus!.debugLabel, equals('LiveTvQuickZapper'));

      // 11. Navigate right to Fullscreen Restore / Exit button and press Select
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 100));
      final exitFsFocus = FocusManager.instance.primaryFocus;
      expect(exitFsFocus, isNotNull);
      expect(exitFsFocus!.debugLabel, equals('LiveTvFullscreen'));

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 100));
      expect(liveTvCtrl.isFullscreenMode.value, isFalse);
    });

    testWidgets('fullscreen mode allows mouse tap on all bottom buttons',
        (tester) async {
      final key = GlobalKey<LiveTvEmbeddedPlayerState>();
      liveTvCtrl.isFullscreenMode.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1280.0,
              height: 720.0,
              child: LiveTvEmbeddedPlayer(
                key: key,
                controller: liveTvCtrl,
                isFullscreen: true,
                autofocus: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Favorite
      final favFinder = find.byTooltip('Add Favorite');
      expect(favFinder, findsOneWidget);
      await tester.tap(favFinder);
      await tester.pump(const Duration(milliseconds: 100));
      expect(liveTvCtrl.favorites.isNotEmpty, isTrue);

      // Tap Aspect Ratio
      final aspectFinder = find.byWidgetPredicate(
        (widget) => widget is IconButton && (widget.tooltip?.startsWith('Aspect Ratio') ?? false),
      );
      expect(aspectFinder, findsOneWidget);
      await tester.tap(aspectFinder);
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Quick Zapper
      final zapperFinder = find.byTooltip('Quick Channel List');
      expect(zapperFinder, findsOneWidget);
      await tester.tap(zapperFinder);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Quick Channel Zapper'), findsOneWidget);
    });
  });
}
