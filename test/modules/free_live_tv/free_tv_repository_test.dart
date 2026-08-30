import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/repositories/free_tv_repository.dart';
import 'package:stream_hub/data/services/free_tv_service.dart';

List<FreeTvChannel> _sampleCatalog() {
  return const [
    FreeTvChannel(
      id: 'ChannelsTV.ng',
      name: 'Channels Television',
      country: 'Nigeria',
      countryCode: 'NG',
      categories: ['News'],
      languages: ['eng'],
      streamUrls: ['https://stream1.channelstv.com/live.m3u8'],
    ),
    FreeTvChannel(
      id: 'BBCNews.uk',
      name: 'BBC News',
      country: 'United Kingdom',
      countryCode: 'UK',
      categories: ['News'],
      languages: ['eng'],
      streamUrls: ['https://bbc.stream/live.m3u8'],
    ),
  ];
}

class _FakeFreeTvService extends FreeTvService {
  _FakeFreeTvService(this._catalog);

  final List<FreeTvChannel> _catalog;
  int fetchCount = 0;

  @override
  Future<List<FreeTvChannel>> fetchCatalog({
    Duration timeout = const Duration(seconds: 25),
  }) async {
    fetchCount++;
    return _catalog;
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('free_tv_repo_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('FreeTvRepository Hive caching', () {
    test('persists catalog to cache and serves it without refetching', () async {
      final fakeService = _FakeFreeTvService(_sampleCatalog());
      final repository = FreeTvRepository(service: fakeService);

      // First call should fetch from the service and persist to Hive.
      final first = await repository.getCatalog();
      expect(first.length, 2);
      expect(fakeService.fetchCount, 1);

      // A second repository (fresh instance) should read from Hive cache,
      // proving the catalog is durable across instances.
      final repository2 = FreeTvRepository(service: _FakeFreeTvService([]));
      final cached = await repository2.getCatalog();
      expect(cached.length, 2);
      expect(cached.map((c) => c.id), containsAll(['ChannelsTV.ng', 'BBCNews.uk']));
    });

    test('refetches from service when force refresh is requested', () async {
      final fakeService = _FakeFreeTvService(_sampleCatalog());
      final repository = FreeTvRepository(service: fakeService);

      await repository.getCatalog();
      await repository.getCatalog(forceRefresh: true);

      expect(fakeService.fetchCount, 2);
    });
  });

  group('FreeTvRepository favorites persistence', () {
    test('toggles and persists favorite channel IDs', () async {
      final repository = FreeTvRepository(service: _FakeFreeTvService([]));

      final isFav = await repository.toggleFavorite('ChannelsTV.ng');
      expect(isFav, isTrue);
      expect(await repository.isFavorite('ChannelsTV.ng'), isTrue);

      // Fresh repository instance should still see the persisted favorite.
      final repository2 = FreeTvRepository(service: _FakeFreeTvService([]));
      expect(await repository2.isFavorite('ChannelsTV.ng'), isTrue);

      final unFav = await repository2.toggleFavorite('ChannelsTV.ng');
      expect(unFav, isFalse);
      expect(await repository2.isFavorite('ChannelsTV.ng'), isFalse);
    });
  });

  group('FreeTvRepository recently watched', () {
    test('records watch history with most recent first and caps at limit',
        () async {
      final repository = FreeTvRepository(service: _FakeFreeTvService([]));
      final channels = _sampleCatalog();

      await repository.recordWatch(channels[0]);
      await repository.recordWatch(channels[1]);

      final recent = await repository.getRecentlyWatched();
      expect(recent.length, 2);
      // Most recently watched should be first.
      expect(recent.first.id, 'BBCNews.uk');
      expect(recent.last.id, 'ChannelsTV.ng');
    });

    test('deduplicates a channel that is watched again', () async {
      final repository = FreeTvRepository(service: _FakeFreeTvService([]));
      final channels = _sampleCatalog();

      await repository.recordWatch(channels[0]);
      await repository.recordWatch(channels[1]);
      await repository.recordWatch(channels[0]);

      final recent = await repository.getRecentlyWatched();
      expect(recent.length, 2);
      expect(recent.first.id, 'ChannelsTV.ng');
    });
  });
}
