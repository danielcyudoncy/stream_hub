import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/helpers/platform_helper.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
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
  Future<void> clearCache({String? sourceId}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(() {
    PlatformHelper.forceMobileMode = false;
    Get.reset();
  });

  testWidgets(
    'renders mobile category bar and channels from LiveTVController on phone screen',
    (tester) async {
      PlatformHelper.forceMobileMode = true;

      // Set phone size
      tester.view.physicalSize = const Size(400 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final guideCtrl = GuideController(
        guideRepository: _MockGuideRepository(),
      );
      Get.put<GuideController>(guideCtrl);

      final liveTvCtrl = LiveTVController(
        mediaEngine: _MockMediaEngine(),
        mediaLibrary: _MockMediaLibrary(),
        catalogRepository: _MockCatalogRepository(),
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

      // 1. Verify Category Pills render on Mobile
      expect(find.text('All Channels'), findsOneWidget);
      expect(find.text('News'), findsWidgets);
      expect(find.text('Sports'), findsWidgets);

      // 2. Verify Channels from LiveTVController render
      expect(find.text('BBC One HD'), findsOneWidget);
      expect(find.text('Sky Sports Premier League'), findsOneWidget);

      // 3. Verify Category Filtering
      await tester.tap(find.text('News').first);
      await tester.pump(const Duration(milliseconds: 200));

      // After filtering to News
      expect(liveTvCtrl.selectedCategory.value, 'News');

      // 4. Verify Channel Tap triggers openChannel
      await tester.tap(find.text('BBC One HD'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(liveTvCtrl.activePlayingChannel.value?.id, 'ch-1');
    },
  );

  testWidgets(
    'shows empty category view and resets to All Channels on click',
    (tester) async {
      PlatformHelper.forceMobileMode = true;

      tester.view.physicalSize = const Size(400 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final guideCtrl = GuideController(
        guideRepository: _MockGuideRepository(),
      );
      Get.put<GuideController>(guideCtrl);

      final liveTvCtrl = LiveTVController(
        mediaEngine: _MockMediaEngine(),
        mediaLibrary: _MockMediaLibrary(),
        catalogRepository: _MockCatalogRepository(),
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
      liveTvCtrl.filteredChannels.assignAll([]);
      liveTvCtrl.categories.assignAll(['All Channels', 'Movies']);
      liveTvCtrl.selectedCategory.value = 'Movies';
      liveTvCtrl.isLoading.value = false;
      guideCtrl.isLoading.value = false;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: TVGuidePage(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('No channels in "Movies"'), findsOneWidget);
      expect(find.text('Show All Channels'), findsOneWidget);

      await tester.tap(find.text('Show All Channels'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(liveTvCtrl.selectedCategory.value, 'All Channels');
    },
  );
}
