import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/stream_matching_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';

class FakeCatalogRepository implements CatalogRepository {
  final List<MediaItem> items;

  FakeCatalogRepository(this.items);

  @override
  Future<List<MediaItem>> getAllItems() async => items;

  @override
  Future<List<MediaItem>> topByUpdatedAt(
    MediaType type, {
    String? providerId,
    int limit = 20,
  }) async {
    final filtered = items.where((i) => i.mediaType == type).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return filtered.take(limit).toList();
  }

  @override
  Future<List<MediaItem>> topByCreatedAt(
    MediaType type, {
    String? providerId,
    int limit = 20,
  }) async {
    final filtered = items.where((i) => i.mediaType == type).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered.take(limit).toList();
  }

  @override
  Future<List<MediaItem>> getByProviderAndType(
    String providerId,
    MediaType type,
  ) async =>
      items
          .where((i) => i.mediaType == type && i.providerId == providerId)
          .toList();

  @override
  Future<List<MediaItem>> getByType(MediaType type) async {
    return items.where((i) => i.mediaType == type).toList();
  }

  @override
  Future<MediaItem?> getItem(String id) async {
    final matches = items.where((i) => i.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<void> upsertItems(List<MediaItem> newItems) async {}

  @override
  Future<void> deleteItem(String id) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<List<MediaSyncResult>> syncAll() async => [];

  @override
  Future<MediaSyncResult> syncSource(String sourceId) async =>
      MediaSyncResult(sourceId: sourceId, success: true, completedAt: DateTime.now());

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<MediaItem>> watchUpdates() => const Stream.empty();

  @override
  Future<void> enrichWithXMLTV(XMLTVGuide guide) async {}

  @override
  Future<void> mergeXMLTVMetadata(XMLTVGuide guide) async {}
}

void main() {
  group('StreamMatchingService Tests', () {
    final now = DateTime.now();

    final localProviderMovie = MediaItem(
      id: 'prov-movie-1',
      providerId: 'xtream_1',
      providerType: MediaSourceType.xtream,
      mediaType: MediaType.movie,
      title: 'EN| Oppenheimer 2023 4K UHD Remux',
      createdAt: now,
      updatedAt: now,
      metadata: {
        'tmdb_id': '872585',
        'year': 2023,
      },
    );

    final localProviderSeries = MediaItem(
      id: 'prov-series-1',
      providerId: 'stalker_1',
      providerType: MediaSourceType.stalker,
      mediaType: MediaType.series,
      title: 'Stranger Things (2016) [FHD 1080p]',
      createdAt: now,
      updatedAt: now,
      metadata: {
        'year': 2016,
      },
    );

    final fakeCatalog = FakeCatalogRepository([
      localProviderMovie,
      localProviderSeries,
    ]);

    final matcher = StreamMatchingService(catalogRepository: fakeCatalog);

    test('normalizeTitle cleans noise tokens, brackets, and resolutions', () {
      expect(StreamMatchingService.normalizeTitle('EN| Oppenheimer 2023 4K UHD Remux'), 'oppenheimer');
      expect(StreamMatchingService.normalizeTitle('Stranger Things (2016) [FHD 1080p]'), 'stranger things');
      expect(StreamMatchingService.normalizeTitle('Avatar: The Way of Water'), 'avatar the way of water');
    });

    test('findMatch directly matches on TMDB ID if present in candidate metadata', () async {
      final tmdbDiscoveryItem = MediaItem(
        id: 'tmdb-movie-872585',
        providerId: 'tmdb',
        providerType: MediaSourceType.custom,
        mediaType: MediaType.movie,
        title: 'Oppenheimer',
        createdAt: now,
        updatedAt: now,
        metadata: {
          'tmdbId': 872585,
          'year': 2023,
        },
      );

      final result = await matcher.matchMovie(tmdbDiscoveryItem);
      expect(result.isAvailable, isTrue);
      expect(result.matchedItem?.id, 'prov-movie-1');
      expect(result.matchedProviderId, 'xtream_1');
    });

    test('findMatch matches by normalized title and year when TMDB ID is absent', () async {
      final tmdbDiscoveryItem = MediaItem(
        id: 'tmdb-series-66732',
        providerId: 'tmdb',
        providerType: MediaSourceType.custom,
        mediaType: MediaType.series,
        title: 'Stranger Things',
        createdAt: now,
        updatedAt: now,
        metadata: {
          'tmdbId': 66732,
          'year': 2016,
        },
      );

      final result = await matcher.matchSeries(tmdbDiscoveryItem);
      expect(result.isAvailable, isTrue);
      expect(result.matchedItem?.id, 'prov-series-1');
      expect(result.matchedProviderId, 'stalker_1');
    });

    test('findMatch returns notAvailable when item is not in catalog', () async {
      final unavailableMovie = MediaItem(
        id: 'tmdb-movie-999999',
        providerId: 'tmdb',
        providerType: MediaSourceType.custom,
        mediaType: MediaType.movie,
        title: 'Nonexistent Film Title 2099',
        createdAt: now,
        updatedAt: now,
        metadata: {
          'tmdbId': 999999,
          'year': 2099,
        },
      );

      final result = await matcher.matchMovie(unavailableMovie);
      expect(result.isAvailable, isFalse);
      expect(result.matchedItem, isNull);
    });

    test('findMatch returns inherently available for non-TMDB provider items', () async {
      final result = await matcher.findMatch(localProviderMovie);
      expect(result.isAvailable, isTrue);
      expect(result.matchedItem?.id, localProviderMovie.id);
      expect(result.matchedProviderId, 'xtream_1');
    });
  });
}
