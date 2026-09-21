import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/services/tv_navigation_service.dart';
import 'package:stream_hub/data/models/channel.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/modules/epg/controllers/guide_controller.dart';
import 'package:stream_hub/modules/epg/models/epg_guide.dart';
import 'package:stream_hub/modules/epg/pages/tv_guide_page.dart';
import 'package:stream_hub/modules/epg/repositories/guide_repository.dart';
import 'package:stream_hub/modules/live_tv/controllers/live_tv_controller.dart';

class _MockCatalogRepository implements CatalogRepository {
  @override
  Stream<void> watchUpdates() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockMediaEngine implements MediaEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockMediaLibrary implements MediaLibrary {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockFavoriteRepository implements FavoriteRepository {
  @override
  Stream<void> watchUpdates() => const Stream.empty();

  @override
  Future<List<MediaItem>> getAll() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockGuideRepository implements GuideRepository {
  @override
  Future<EPGGuide> fetchGuide({
    required String sourceId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return EPGGuide(
      sourceId: sourceId,
      channels: const [],
      programs: const [],
      generatedAt: DateTime.now(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Get.reset();
  });

  testWidgets('TV Guide assigns initial focus and navigates with remote D-pad', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Get.put<TvNavigationService>(TvNavigationService());
    final guideCtrl = GuideController(guideRepository: _MockGuideRepository());
    Get.put<GuideController>(guideCtrl);

    final liveTvCtrl = LiveTVController(
      catalogRepository: _MockCatalogRepository(),
      mediaEngine: _MockMediaEngine(),
      mediaLibrary: _MockMediaLibrary(),
      favoriteRepository: _MockFavoriteRepository(),
    );
    Get.put<LiveTVController>(liveTvCtrl);

    final channel1 = Channel(
      id: 'ch-1',
      providerId: 'prov-1',
      providerType: MediaSourceType.m3u,
      title: 'BBC One HD',
      mediaType: MediaType.channel,
      number: '1',
      isLive: true,
      genres: const ['News'],
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    final channel2 = Channel(
      id: 'ch-2',
      providerId: 'prov-1',
      providerType: MediaSourceType.m3u,
      title: 'Sky Sports Premier League',
      mediaType: MediaType.channel,
      number: '2',
      isLive: true,
      genres: const ['Sports'],
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    liveTvCtrl.channels.assignAll([channel1, channel2]);
    liveTvCtrl.filteredChannels.assignAll([channel1, channel2]);
    liveTvCtrl.categories.assignAll(['All Channels', 'News', 'Sports']);
    liveTvCtrl.isLoading.value = false;
    guideCtrl.isLoading.value = false;

    await tester.pumpWidget(
      const GetMaterialApp(
        home: TVGuidePage(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Verify initial focus is assigned to an actionable element
    final primaryFocus = FocusManager.instance.primaryFocus;
    expect(primaryFocus, isNotNull);
    expect(primaryFocus?.hasFocus, isTrue);

    // Send D-pad ArrowDown to move to channels or category
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 100));

    // Focus must still be active and not trapped/null
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
  });

  testWidgets('Navigating right from Refresh button enters player and exits left back to Refresh', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Get.put<TvNavigationService>(TvNavigationService());
    final guideCtrl = GuideController(guideRepository: _MockGuideRepository());
    Get.put<GuideController>(guideCtrl);

    final liveTvCtrl = LiveTVController(
      catalogRepository: _MockCatalogRepository(),
      mediaEngine: _MockMediaEngine(),
      mediaLibrary: _MockMediaLibrary(),
      favoriteRepository: _MockFavoriteRepository(),
    );
    Get.put<LiveTVController>(liveTvCtrl);

    final channel1 = Channel(
      id: 'ch-1',
      providerId: 'prov-1',
      providerType: MediaSourceType.m3u,
      title: 'BBC One HD',
      mediaType: MediaType.channel,
      number: '1',
      isLive: true,
      genres: const ['News'],
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    liveTvCtrl.channels.assignAll([channel1]);
    liveTvCtrl.filteredChannels.assignAll([channel1]);
    liveTvCtrl.categories.assignAll(['All Channels', 'News']);
    liveTvCtrl.isLoading.value = false;
    guideCtrl.isLoading.value = false;

    await tester.pumpWidget(
      const GetMaterialApp(
        home: TVGuidePage(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Find the TvGuide_Refresh button focus node in the showcase
    final refreshFinders = find.ancestor(
      of: find.byIcon(Icons.refresh),
      matching: find.byType(FocusableActionDetector),
    );
    FocusNode? refreshNode;
    for (final widget in tester.widgetList<FocusableActionDetector>(refreshFinders)) {
      if (widget.focusNode?.debugLabel == 'TvGuide_Refresh') {
        refreshNode = widget.focusNode;
        break;
      }
    }

    expect(refreshNode, isNotNull);
    refreshNode!.requestFocus();
    await tester.pump(const Duration(milliseconds: 100));
    expect(refreshNode.hasFocus, isTrue);

    // Press ArrowRight from Refresh button -> should enter embedded player
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    // Focus should now be inside player (e.g. LiveTvPlayPause or LiveTvPlayerAnchor)
    final playerFocus = FocusManager.instance.primaryFocus;
    expect(playerFocus, isNotNull);
    expect(
      playerFocus?.debugLabel == 'LiveTvPlayPause' ||
          playerFocus?.debugLabel == 'LiveTvPlayerAnchor',
      isTrue,
    );

    // Press ArrowLeft from player -> should return to Refresh button
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 100));
    expect(refreshNode.hasFocus, isTrue);
  });
}
