import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/repositories/free_tv_repository.dart';
import 'package:stream_hub/modules/free_live_tv/controllers/free_live_tv_controller.dart';
import 'package:stream_hub/modules/free_live_tv/pages/free_live_tv_page.dart';
import 'package:stream_hub/modules/free_live_tv/widgets/free_tv_category_bar.dart';
import 'package:stream_hub/modules/free_live_tv/widgets/free_tv_channel_card.dart';
import 'package:stream_hub/shared/widgets/error_view.dart';

class _FakeFreeTvRepository implements FreeTvRepository {
  final List<FreeTvChannel> channels;
  final Set<String> favorites = {};
  bool failCatalog = false;

  _FakeFreeTvRepository(this.channels);

  @override
  Future<List<FreeTvChannel>> getCatalog({bool forceRefresh = false}) async {
    if (failCatalog) {
      throw Exception('network unavailable');
    }
    return channels.map((c) => c.copyWith(isFavorite: favorites.contains(c.id))).toList();
  }

  @override
  Set<String> getFavoriteIds() => Set.of(favorites);

  @override
  Future<bool> isFavorite(String channelId) async => favorites.contains(channelId);

  @override
  Future<bool> toggleFavorite(String channelId) async {
    final isFav = !favorites.contains(channelId);
    if (isFav) {
      favorites.add(channelId);
    } else {
      favorites.remove(channelId);
    }
    return isFav;
  }

  @override
  Stream<Set<String>> watchFavorites() => const Stream.empty();

  @override
  Future<List<FreeTvChannel>> getRecentlyWatched() async => const [];

  @override
  Future<void> recordWatch(FreeTvChannel channel) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStreamRepository implements StreamRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    Get.reset();
    Get.put<StreamRepository>(_FakeStreamRepository());
  });

  group('FreeLiveTvPage Widget Tests', () {
    testWidgets('renders FreeLiveTvPage, top app bar, and category bar',
        (tester) async {
      final fakeChannels = [
        const FreeTvChannel(
          id: 'ChannelsTV.ng',
          name: 'Channels Television',
          country: 'Nigeria',
          countryCode: 'NG',
          categories: ['News'],
          streamUrls: ['https://stream.channelstv.com/live.m3u8'],
        ),
        const FreeTvChannel(
          id: 'BBCNews.uk',
          name: 'BBC News',
          country: 'United Kingdom',
          countryCode: 'UK',
          categories: ['News'],
          streamUrls: ['https://stream.bbc.com/live.m3u8'],
        ),
      ];

      final fakeRepo = _FakeFreeTvRepository(fakeChannels);
      final controller = FreeLiveTvController(repository: fakeRepo);
      Get.put<FreeLiveTvController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: FreeLiveTvPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Top App Bar title
      expect(find.text('Free Live TV'), findsOneWidget);
      expect(find.text('2 Public Free Channels'), findsOneWidget);

      // Category bar
      expect(find.byType(FreeTvCategoryBar), findsOneWidget);

      // The category bar scrolls horizontally; curated country chips may be
      // beyond the initially-built viewport in the landscape two-pane layout,
      // so drag the category bar until the Nigeria chip is visible.
      await _revealCategoryChip(tester, find.text('🇳🇬 Nigeria'));
      expect(find.text('🇳🇬 Nigeria'), findsOneWidget);

      // Channel Cards
      expect(find.byType(FreeTvChannelCard), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(FreeTvChannelCard),
          matching: find.text('Channels Television'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(FreeTvChannelCard),
          matching: find.text('BBC News'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('filters channels when Nigeria chip is tapped', (tester) async {
      final fakeChannels = [
        const FreeTvChannel(
          id: 'ChannelsTV.ng',
          name: 'Channels Television',
          country: 'Nigeria',
          countryCode: 'NG',
          categories: ['News'],
          streamUrls: ['https://stream.channelstv.com/live.m3u8'],
        ),
        const FreeTvChannel(
          id: 'BBCNews.uk',
          name: 'BBC News',
          country: 'United Kingdom',
          countryCode: 'UK',
          categories: ['News'],
          streamUrls: ['https://stream.bbc.com/live.m3u8'],
        ),
      ];

      final fakeRepo = _FakeFreeTvRepository(fakeChannels);
      final controller = FreeLiveTvController(repository: fakeRepo);
      Get.put<FreeLiveTvController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: FreeLiveTvPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Nigeria chip
      await _revealCategoryChip(tester, find.text('🇳🇬 Nigeria'));
      await tester.tap(find.text('🇳🇬 Nigeria'));
      await tester.pumpAndSettle();

      // Should only show Channels Television in the channel list
      expect(find.byType(FreeTvChannelCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FreeTvChannelCard),
          matching: find.text('Channels Television'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(FreeTvChannelCard),
          matching: find.text('BBC News'),
        ),
        findsNothing,
      );
    });

    testWidgets('shows error view when the catalog API fails with no cache',
        (tester) async {
      final fakeRepo = _FakeFreeTvRepository(const []);
      fakeRepo.failCatalog = true;
      final controller = FreeLiveTvController(repository: fakeRepo);
      Get.put<FreeLiveTvController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: FreeLiveTvPage(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(
        find.text('Unable to load Free Live TV'),
        findsOneWidget,
      );
    });
  });
}

/// Horizontally drags the category bar until [finder] is built and visible.
/// The category bar sits inside a narrow pane in the landscape two-pane layout,
/// so chips beyond the initially-built viewport are lazily not present.
Future<void> _revealCategoryChip(WidgetTester tester, Finder finder) async {
  final bar = find.byType(FreeTvCategoryBar);
  if (bar.evaluate().isEmpty) return;
  var attempts = 0;
  while (finder.evaluate().isEmpty && attempts < 8) {
    // Drag left to reveal chips to the right of the visible viewport.
    await tester.drag(bar, const Offset(-250, 0));
    await tester.pumpAndSettle();
    attempts++;
  }
}
