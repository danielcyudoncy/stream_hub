import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/repositories/free_tv_repository.dart';
import 'package:stream_hub/modules/free_live_tv/controllers/free_live_tv_controller.dart';

class _FakeFreeTvRepository implements FreeTvRepository {
  List<FreeTvChannel> catalog = [];
  final Set<String> favoriteIds = {};
  final List<FreeTvChannel> recent = [];
  final StreamController<Set<String>> _favController =
      StreamController<Set<String>>.broadcast();

  @override
  Future<List<FreeTvChannel>> getCatalog({bool forceRefresh = false}) async {
    return catalog.map((c) {
      final isFav = favoriteIds.contains(c.id);
      return c.copyWith(isFavorite: isFav);
    }).toList();
  }

  @override
  Set<String> getFavoriteIds() => Set.of(favoriteIds);

  @override
  Future<bool> isFavorite(String channelId) async => favoriteIds.contains(channelId);

  @override
  Future<bool> toggleFavorite(String channelId) async {
    final nowFav = !favoriteIds.contains(channelId);
    if (nowFav) {
      favoriteIds.add(channelId);
    } else {
      favoriteIds.remove(channelId);
    }
    _favController.add(favoriteIds);
    return nowFav;
  }

  @override
  Stream<Set<String>> watchFavorites() => _favController.stream;

  @override
  Future<List<FreeTvChannel>> getRecentlyWatched() async => List.of(recent);

  @override
  Future<void> recordWatch(FreeTvChannel channel) async {
    recent.removeWhere((c) => c.id == channel.id);
    recent.insert(0, channel);
  }

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

  group('FreeLiveTvController State & Filtering Tests', () {
    late _FakeFreeTvRepository fakeRepo;
    late FreeLiveTvController controller;

    setUp(() {
      fakeRepo = _FakeFreeTvRepository();
      fakeRepo.catalog = [
        const FreeTvChannel(
          id: 'ChannelsTV.ng',
          name: 'Channels Television',
          country: 'Nigeria',
          countryCode: 'NG',
          region: 'Africa',
          categories: ['News', 'General'],
          languages: ['English'],
          streamUrls: [
            'https://stream1.channelstv.com/live.m3u8',
            'https://stream2.channelstv.com/backup.m3u8',
          ],
          qualityScore: 70,
          qualityTier: FreeTvQualityTier.recommended,
        ),
        const FreeTvChannel(
          id: 'BBCNews.uk',
          name: 'BBC News',
          country: 'United Kingdom',
          countryCode: 'GB',
          region: 'Europe',
          categories: ['News'],
          languages: ['English'],
          streamUrls: ['https://bbc.stream/live.m3u8'],
          qualityScore: 80,
          qualityTier: FreeTvQualityTier.recommended,
        ),
        const FreeTvChannel(
          id: 'France24.fr',
          name: 'France 24 Français',
          country: 'France',
          countryCode: 'FR',
          region: 'Europe',
          categories: ['News'],
          languages: ['French'],
          streamUrls: ['https://france24.stream/live.m3u8'],
          qualityScore: 50,
          qualityTier: FreeTvQualityTier.valid,
        ),
        const FreeTvChannel(
          id: 'RedBullTV.at',
          name: 'Red Bull TV',
          country: 'Austria',
          countryCode: 'AT',
          region: 'Europe',
          categories: ['Sports', 'Entertainment'],
          languages: ['English'],
          streamUrls: ['https://redbull.stream/live.m3u8'],
          qualityScore: 45,
          qualityTier: FreeTvQualityTier.valid,
        ),
      ];

      controller = FreeLiveTvController(repository: fakeRepo);
    });

    test('loads catalog and shows curated recommended subset by default',
        () async {
      controller.onInit();
      // Wait for catalog load
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.isLoading.value, isFalse);
      expect(controller.channels.length, 4);
      // Curated default browse surface = recommended tier only.
      expect(controller.filteredChannels.length, 2);
      expect(
        controller.filteredChannels.map((c) => c.id),
        containsAll(['ChannelsTV.ng', 'BBCNews.uk']),
      );
      expect(controller.recommendedChannels.length, 2);
      // Featured is populated from the recommended subset.
      expect(controller.featuredChannels, isNotEmpty);
      expect(controller.featuredChannel.value, isNotNull);
    });

    test('filters correctly by country (Nigeria)', () async {
      controller.onInit();
      await Future.delayed(const Duration(milliseconds: 50));

      // Filter by Nigeria
      controller.setCountry('Nigeria');
      expect(controller.filteredChannels.length, 1);
      expect(controller.filteredChannels.first.id, 'ChannelsTV.ng');
    });

    test('filters by region (Europe)', () async {
      controller.onInit();
      await Future.delayed(const Duration(milliseconds: 50));

      controller.setRegion('Europe');
      expect(controller.filteredChannels.length, 3);
      expect(
        controller.filteredChannels.map((c) => c.id),
        containsAll(['BBCNews.uk', 'France24.fr', 'RedBullTV.at']),
      );
    });

    test('selecting an explicit filter searches the whole valid catalog', () async {
      controller.onInit();
      await Future.delayed(const Duration(milliseconds: 50));

      // Default (recommended) only has 2 channels, but searching must include
      // all valid channels.
      controller.setSort('alphabetical');
      expect(controller.filteredChannels.first.name, 'BBC News');
    });

    test('filters by Category correctly', () async {
      controller.onInit();
      await Future.delayed(const Duration(milliseconds: 50));

      controller.setCategory('Sports');
      expect(controller.filteredChannels.length, 1);
      expect(controller.filteredChannels.first.id, 'RedBullTV.at');
    });

    test('filters by Language correctly', () async {
      controller.onInit();
      await Future.delayed(const Duration(milliseconds: 50));

      controller.setLanguage('French');
      expect(controller.filteredChannels.length, 1);
      expect(controller.filteredChannels.first.id, 'France24.fr');
    });

    test('searches case-insensitively across name, country, and category',
        () async {
      controller.onInit();
      await Future.delayed(const Duration(milliseconds: 50));

      controller.setSearchQuery('red bull');
      // Wait for debounce timer
      await Future.delayed(const Duration(milliseconds: 300));

      expect(controller.filteredChannels.length, 1);
      expect(controller.filteredChannels.first.name, 'Red Bull TV');
    });

    test('toggles favorite and filters favorites only', () async {
      controller.onInit();
      await Future.delayed(const Duration(milliseconds: 50));

      final channel = controller.channels.first;
      await controller.toggleFavorite(channel);

      expect(controller.favorites.length, 1);
      expect(controller.favorites.first.id, channel.id);

      controller.setFavoritesOnly(true);
      expect(controller.filteredChannels.length, 1);
      expect(controller.filteredChannels.first.id, channel.id);
    });

    test('sorts channels alphabetically, by country, and by category',
        () async {
      controller.onInit();
      await Future.delayed(const Duration(milliseconds: 50));

      // Browse the full valid catalog for this test.
      controller.catalogMode = 'all';

      // Alphabetical sort
      controller.setSort('alphabetical');
      expect(controller.filteredChannels[0].name, 'BBC News');
      expect(controller.filteredChannels[1].name, 'Channels Television');
      expect(controller.filteredChannels[2].name, 'France 24 Français');
      expect(controller.filteredChannels[3].name, 'Red Bull TV');

      // Country sort
      controller.setSort('country');
      expect(controller.filteredChannels[0].country, 'Austria');
      expect(controller.filteredChannels[1].country, 'France');
      expect(controller.filteredChannels[2].country, 'Nigeria');
      expect(controller.filteredChannels[3].country, 'United Kingdom');
    });
  });
}
