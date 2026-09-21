// test/shared/tv_navigation_service_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/services/tv_navigation_service.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/prepared_download.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/modules/live_tv/widgets/live_tv_channel_card.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
import 'package:stream_hub/modules/player/widgets/player_controls.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';
import 'package:stream_hub/shared/widgets/tv_navigation_region.dart';
import 'package:stream_hub/shared/widgets/tv_player_keyboard_hint.dart';
import 'package:stream_hub/shared/widgets/tv_scaffold.dart';

Widget _wrap(Widget body) {
  return GetMaterialApp(home: Scaffold(body: body));
}

void main() {
  late TvNavigationService navService;

  setUp(() {
    Get.reset();
    navService = TvNavigationService();
    Get.put<TvNavigationService>(navService, permanent: true);
  });

  tearDown(() {
    Get.reset();
  });

  group('TvNavigationService Unit Tests', () {
    test('registers and unregisters regions cleanly', () {
      navService.registerRegion('row_1', TvFocusRegionType.rail);
      expect(navService.getMemory('row_1'), isNotNull);
      expect(navService.getMemory('row_1')!.type, TvFocusRegionType.rail);

      navService.unregisterRegion('row_1');
      // Unregistered from active tracking
      navService.registerRegion('row_2', TvFocusRegionType.hero);
      expect(navService.getMemory('row_2')!.type, TvFocusRegionType.hero);
    });

    test('records focus and restores focus by node and index', () {
      navService.registerRegion('row_movies', TvFocusRegionType.rail);

      final node1 = FocusNode(debugLabel: 'movie_1');
      final node2 = FocusNode(debugLabel: 'movie_2');
      final node3 = FocusNode(debugLabel: 'movie_3');

      navService.registerNode('row_movies', node1);
      navService.registerNode('row_movies', node2);
      navService.registerNode('row_movies', node3);

      // Record focus on node2 (index 1)
      navService.recordFocus(
        regionId: 'row_movies',
        node: node2,
        itemId: 'movie_2',
        itemIndex: 1,
        horizontalRatio: 0.5,
      );

      expect(navService.currentRegionId.value, 'row_movies');
      expect(navService.currentItemId.value, 'movie_2');

      final mem = navService.getMemory('row_movies');
      expect(mem, isNotNull);
      expect(mem!.lastFocusedItemId, 'movie_2');
      expect(mem.lastFocusedIndex, 1);
      expect(mem.lastHorizontalRatio, 0.5);

      node1.dispose();
      node2.dispose();
      node3.dispose();
    });

    test('preserves horizontal intent between vertically stacked rails', () {
      navService.registerRegion('rail_a', TvFocusRegionType.rail);
      navService.registerRegion('rail_b', TvFocusRegionType.rail);

      final aNodes = List.generate(5, (i) => FocusNode(debugLabel: 'A_$i'));
      final bNodes = List.generate(3, (i) => FocusNode(debugLabel: 'B_$i'));

      for (final n in aNodes) {
        navService.registerNode('rail_a', n);
      }
      for (final n in bNodes) {
        navService.registerNode('rail_b', n);
      }

      // In rail A, focus is at index 4 (far right, ratio = 0.9)
      navService.recordFocus(
        regionId: 'rail_a',
        node: aNodes[4],
        itemId: 'A_4',
        itemIndex: 4,
        horizontalRatio: 0.9,
      );

      // Navigate down to rail B
      final handled = navService.handleInterRailNavigation(
        currentRegionId: 'rail_a',
        direction: TraversalDirection.down,
      );

      expect(handled, isTrue);

      for (final n in [...aNodes, ...bNodes]) {
        n.dispose();
      }
    });

    test('unregisterRegion drops memory, nodes and item references', () {
      navService.registerRegion('row_x', TvFocusRegionType.rail);
      final node = FocusNode(debugLabel: 'x_node');
      navService.registerNode('row_x', node);
      navService.recordFocus(
        regionId: 'row_x',
        node: node,
        itemId: 'x_item',
        itemIndex: 0,
      );
      expect(navService.getMemory('row_x'), isNotNull);

      navService.unregisterRegion('row_x');

      expect(navService.getMemory('row_x'), isNull);
      expect(
        navService.currentRegionId.value,
        '',
        reason: 'Unregistering the active region clears currentRegionId',
      );
      expect(navService.restoreFocus('row_x'), isFalse);
      node.dispose();
    });

    test('unregisterNode removes node references so focus can never return to a disposed node', () {
      navService.registerRegion('row_y', TvFocusRegionType.rail);
      final node = FocusNode(debugLabel: 'y_node');
      navService.recordFocus(
        regionId: 'row_y',
        node: node,
        itemId: 'y_item',
        itemIndex: 0,
      );
      expect(navService.getMemory('row_y')!.lastFocusedItemId, 'y_item');

      navService.unregisterNode('row_y', node);

      expect(navService.getMemory('row_y')!.lastFocusedNode, isNull);
      node.dispose();
      expect(
        navService.restoreFocus('row_y'),
        isFalse,
        reason:
            'A region whose only node was unregistered must not re-focus a '
            'disposed node (this previously reached restoreFocus and could '
            'assert in debug builds).',
      );
    });

    test('clearFocusRegion resets markers but keeps memory for restoration', () {
      navService.registerRegion('row_z', TvFocusRegionType.rail);
      final node = FocusNode(debugLabel: 'z_node');
      navService.recordFocus(
        regionId: 'row_z',
        node: node,
        itemId: 'z_item',
        itemIndex: 0,
      );
      expect(navService.currentRegionId.value, 'row_z');

      navService.clearFocusRegion();

      expect(navService.currentRegionId.value, '');
      expect(navService.currentItemId.value, '');
      expect(
        navService.getMemory('row_z'),
        isNotNull,
        reason: 'Clearing the active marker must not erase focus memory',
      );
      node.dispose();
    });

    test('explicit rail order survives transient region unregistration', () {
      navService.registerRailOrder(<String>['rail_a', 'rail_b']);
      navService.registerRegion('rail_a', TvFocusRegionType.rail);
      navService.registerRegion('rail_b', TvFocusRegionType.rail);

      final aNode = FocusNode(debugLabel: 'A_node');
      navService.registerNode('rail_a', aNode);
      navService.recordFocus(
        regionId: 'rail_a',
        node: aNode,
        itemId: 'A_0',
        itemIndex: 0,
      );

      // rail_b unmounts and remounts; its canonical order slot must survive.
      navService.unregisterRegion('rail_b');
      navService.registerRegion('rail_b', TvFocusRegionType.rail);

      final handled = navService.handleInterRailNavigation(
        currentRegionId: 'rail_a',
        direction: TraversalDirection.down,
      );

      expect(
        handled,
        isTrue,
        reason:
            'Inter-rail navigation must still target rail_b after a transient '
            'unmount (auto-detected order would have dropped it permanently).',
      );
      aNode.dispose();
    });
  });

  group('TvNavigationRegion & TvFocusable Widget Tests', () {
    testWidgets(
      'TvFocusable registers automatically with parent TvNavigationRegion',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final node = FocusNode(debugLabel: 'Card_1');

        await tester.pumpWidget(
          _wrap(
            TvNavigationRegion(
              regionId: 'test_rail',
              type: TvFocusRegionType.rail,
              child: TvFocusable(
                focusNode: node,
                itemId: 'item_1',
                itemIndex: 0,
                child: const Text('Card 1'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        node.requestFocus();
        await tester.pump();

        expect(navService.currentRegionId.value, 'test_rail');
        expect(navService.currentItemId.value, 'item_1');

        node.dispose();
      },
    );

    testWidgets(
      'Focus memory restores previous item when returning to region',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final rail1Nodes = List.generate(
          3,
          (i) => FocusNode(debugLabel: 'R1_$i'),
        );
        final rail2Nodes = List.generate(
          3,
          (i) => FocusNode(debugLabel: 'R2_$i'),
        );

        await tester.pumpWidget(
          _wrap(
            Column(
              children: [
                TvNavigationRegion(
                  regionId: 'rail_1',
                  child: Row(
                    children: [
                      for (int i = 0; i < 3; i++)
                        TvFocusable(
                          focusNode: rail1Nodes[i],
                          itemId: 'r1_$i',
                          itemIndex: i,
                          child: Text('R1 Item $i'),
                        ),
                    ],
                  ),
                ),
                TvNavigationRegion(
                  regionId: 'rail_2',
                  child: Row(
                    children: [
                      for (int i = 0; i < 3; i++)
                        TvFocusable(
                          focusNode: rail2Nodes[i],
                          itemId: 'r2_$i',
                          itemIndex: i,
                          child: Text('R2 Item $i'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Focus item 2 of rail 1
        rail1Nodes[2].requestFocus();
        await tester.pump();
        expect(rail1Nodes[2].hasFocus, isTrue);
        expect(navService.currentItemId.value, 'r1_2');

        // Move focus to item 0 of rail 2
        rail2Nodes[0].requestFocus();
        await tester.pump();
        expect(rail2Nodes[0].hasFocus, isTrue);
        expect(navService.currentItemId.value, 'r2_0');

        // Use TvNavigationService to restore focus to rail 1
        final restored = navService.restoreFocus('rail_1');
        await tester.pump();

        expect(restored, isTrue);
        expect(
          rail1Nodes[2].hasFocus,
          isTrue,
          reason: 'Must restore exact last focused item in rail 1',
        );

        for (final n in [...rail1Nodes, ...rail2Nodes]) {
          n.dispose();
        }
      },
    );

    testWidgets(
      'same item ID in different regions restores to the correct node per region',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final regionANode = FocusNode(debugLabel: 'A_node');
        final regionBNode = FocusNode(debugLabel: 'B_node');

        await tester.pumpWidget(
          _wrap(
            Column(
              children: [
                TvNavigationRegion(
                  regionId: 'region_a',
                  child: TvFocusable(
                    focusNode: regionANode,
                    itemId: 'dup_item',
                    itemIndex: 0,
                    child: const Text('A'),
                  ),
                ),
                TvNavigationRegion(
                  regionId: 'region_b',
                  child: TvFocusable(
                    focusNode: regionBNode,
                    itemId: 'dup_item',
                    itemIndex: 1,
                    child: const Text('B'),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        regionANode.requestFocus();
        await tester.pump();
        expect(navService.currentItemId.value, 'dup_item');

        regionBNode.requestFocus();
        await tester.pump();
        expect(navService.currentItemId.value, 'dup_item');

        // Restoring region A must return to A's node, not B's. Before the
        // region-scoped identity fix both regions shared a single map entry
        // and this would focus region B.
        final restoredA = navService.restoreFocus('region_a');
        await tester.pump();

        expect(restoredA, isTrue);
        expect(
          regionANode.hasFocus,
          isTrue,
          reason: 'Region A must restore to its own dup_item node',
        );
        expect(regionBNode.hasFocus, isFalse);

        final restoredB = navService.restoreFocus('region_b');
        await tester.pump();

        expect(restoredB, isTrue);
        expect(
          regionBNode.hasFocus,
          isTrue,
          reason: 'Region B must restore to its own dup_item node',
        );

        regionANode.dispose();
        regionBNode.dispose();
      },
    );

    testWidgets(
      'focus on a non-region focusable clears the stale active region marker',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final regionNode = FocusNode(debugLabel: 'region_node');
        final plainNode = FocusNode(debugLabel: 'plain_node');

        await tester.pumpWidget(
          _wrap(
            Column(
              children: [
                TvNavigationRegion(
                  regionId: 'some_region',
                  child: TvFocusable(
                    focusNode: regionNode,
                    itemId: 'region_item',
                    child: const Text('Region Item'),
                  ),
                ),
                TvFocusable(
                  focusNode: plainNode,
                  child: const Text('Plain Item'),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        regionNode.requestFocus();
        await tester.pump();
        expect(navService.currentRegionId.value, 'some_region');

        plainNode.requestFocus();
        await tester.pump();
        expect(
          navService.currentRegionId.value,
          '',
          reason: 'Non-region focus must clear the stale active region marker',
        );

        regionNode.dispose();
        plainNode.dispose();
      },
    );

    testWidgets(
      'isAtLeftEdge does not trigger sidebar when a sibling exists to the left',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final leftNode = FocusNode(debugLabel: 'left_item');
        final currentNode = FocusNode(debugLabel: 'current_item');

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                Positioned(
                  left: 40,
                  top: 40,
                  child: Focus(
                    focusNode: leftNode,
                    child: const SizedBox(width: 120, height: 60),
                  ),
                ),
                Positioned(
                  left: 160,
                  top: 40,
                  child: Focus(
                    focusNode: currentNode,
                    child: const SizedBox(width: 120, height: 60),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        currentNode.requestFocus();
        await tester.pump();

        navService.registerNode('home_rail', currentNode);
        navService.registerNode('home_rail', leftNode);
        navService.recordFocus(
          regionId: 'home_rail',
          node: currentNode,
          itemId: 'current_item',
          itemIndex: 1,
          horizontalRatio: 0.4,
        );

        expect(navService.isAtLeftEdge(currentNode), isFalse);

        leftNode.dispose();
        currentNode.dispose();
      },
    );

    testWidgets(
      'TvScaffold body scope keeps left/right remote navigation working',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final leftNode = FocusNode(debugLabel: 'left_item');
        final rightNode = FocusNode(debugLabel: 'right_item');

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: TvScaffold(
                body: Row(
                  children: [
                    Focus(
                      focusNode: leftNode,
                      child: const SizedBox(width: 140, height: 80),
                    ),
                    Focus(
                      focusNode: rightNode,
                      child: const SizedBox(width: 140, height: 80),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        rightNode.requestFocus();
        await tester.pump();
        expect(rightNode.hasFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();

        expect(
          leftNode.hasFocus,
          isTrue,
          reason:
              'Directional traversal should move focus left to the adjacent body item.',
        );

        leftNode.dispose();
        rightNode.dispose();
      },
    );

    testWidgets(
      'LiveTvChannelCard registers through the shared TV focus system',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final channel = MediaItem(
          id: 'live_42',
          providerId: 'provider_1',
          providerType: MediaSourceType.xtream,
          mediaType: MediaType.channel,
          title: 'News 24',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          _wrap(
            TvNavigationRegion(
              regionId: 'live_channels',
              type: TvFocusRegionType.rail,
              child: LiveTvChannelCard(
                channel: channel,
                itemIndex: 3,
                onTap: () {},
                onFavorite: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TvFocusable), findsOneWidget);
        final focusable = tester.widget<TvFocusable>(find.byType(TvFocusable));
        expect(focusable.regionId, 'live_channels');
        expect(focusable.itemId, 'live_42');
        expect(focusable.itemIndex, 3);
      },
    );

    testWidgets('PlayerControls participates in a TV focus traversal group', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = _TestStreamRepository();
      Get.put<StreamRepository>(repository, permanent: true);

      final controller = PlayerController();

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: PlayerControls(controller: controller, isFullscreen: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FocusTraversalGroup), findsWidgets);
      expect(find.byType(TvFocusable), findsWidgets);

      await controller.playbackController.engine.dispose();
    });

    testWidgets(
      'TvPlayerKeyboard inline mode keeps a focus anchor for directional remote keys',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        int directionCount = 0;

        await tester.pumpWidget(
          _wrap(
            TvPlayerKeyboard(
              autofocus: false,
              onAnyKey: () => directionCount++,
              onToggleControls: () {},
              child: const Text('Player Inline Content'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final inlineFocus = tester
            .widgetList<Focus>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is Focus &&
                    widget.focusNode?.debugLabel == 'TvPlayerKeyboardInline',
              ),
            )
            .single
            .focusNode!;

        expect(inlineFocus.canRequestFocus, isFalse);
        expect(inlineFocus.skipTraversal, isTrue);

        // Inline player focus is intentionally not a page-level trap. It should
        // stay available for key handling without stealing primary focus from the
        // surrounding guide/channel content.
        expect(FocusManager.instance.primaryFocus, isNot(equals(inlineFocus)));

        final result = inlineFocus.onKeyEvent?.call(
          inlineFocus,
          KeyDownEvent(
            logicalKey: LogicalKeyboardKey.arrowLeft,
            physicalKey: PhysicalKeyboardKey.arrowLeft,
            timeStamp: const Duration(milliseconds: 0),
          ),
        );

        expect(result, KeyEventResult.ignored);
        expect(directionCount, 1);
      },
    );

    testWidgets(
      'TvPlayerKeyboard cleans up focus nodes and does not leak memory',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        bool toggleCalled = false;

        await tester.pumpWidget(
          _wrap(
            TvPlayerKeyboard(
              autofocus: true,
              onAnyKey: () {},
              onToggleControls: () {
                toggleCalled = true;
              },
              child: const Text('Player Content'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Send select key to trigger controls toggle
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump();

        expect(toggleCalled, isTrue);

        // Rebuilding with autofocus false switches cleanly without exception or leak
        await tester.pumpWidget(
          _wrap(
            TvPlayerKeyboard(
              autofocus: false,
              onAnyKey: () {},
              onToggleControls: () {},
              child: const Text('Player Inline Content'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Rebuild with different child
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  });
}

class _TestStreamRepository extends StreamRepository {
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
    throw UnimplementedError();
  }

  @override
  Future<PlayableSession> resolveStream({
    required String mediaItemId,
    required String url,
    required ProviderSession providerSession,
    Map<String, dynamic> itemMetadata = const {},
  }) async {
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
  }) async {
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
