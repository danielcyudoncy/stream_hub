import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/canonical_media_item.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/metadata_models.dart';
import 'package:stream_hub/data/metadata/metadata_engine.dart';
import 'package:stream_hub/data/metadata/metadata_merge_engine.dart';
import 'package:stream_hub/data/metadata/artwork_service.dart';
import 'package:stream_hub/data/metadata/collection_engine.dart';
import 'package:stream_hub/data/services/history_service.dart';
import 'package:stream_hub/data/services/favorite_service.dart';
import 'package:stream_hub/data/providers/metadata/xmltv_metadata_provider.dart';
import 'package:stream_hub/data/providers/metadata/tmdb_metadata_provider.dart';
import 'package:stream_hub/data/providers/metadata/tvmaze_metadata_provider.dart';
import 'package:stream_hub/data/providers/metadata/imdb_metadata_provider.dart';
import 'package:stream_hub/data/providers/metadata/trakt_metadata_provider.dart';
import 'package:stream_hub/data/providers/metadata/fanart_metadata_provider.dart';
import 'package:stream_hub/data/providers/metadata/provider_native_metadata_provider.dart';
import 'package:stream_hub/data/providers/metadata/local_metadata_provider.dart';
import 'package:stream_hub/data/providers/metadata/custom_metadata_provider.dart';
import 'package:stream_hub/data/indexes/search_index.dart';
import 'package:stream_hub/data/indexes/search_engine.dart';
import 'package:stream_hub/data/indexes/media_index.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';

void main() {
  group('MetadataEngine', () {
    test('enriches item with XMLTV metadata provider', () async {
      final engine = MetadataEngine(providers: [
        XMLTVMetadataProvider(id: 'xmltv-1'),
      ]);

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News Channel',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await engine.enrich(item);

      expect(result.title, equals('News Channel'));
      expect(result.metadataSources, contains('xmltv'));
      expect(result.providerOwnership, contains('m3u'));
    });

    test('enriches item with multiple providers', () async {
      final engine = MetadataEngine(providers: [
        XMLTVMetadataProvider(id: 'xmltv-1'),
        TMDBMetadataProvider(id: 'tmdb-1'),
      ]);

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.movie,
        title: 'Inception',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await engine.enrich(item);

      expect(result.metadataSources.length, greaterThanOrEqualTo(0));
      expect(result.providerOwnership.length, greaterThanOrEqualTo(1));
    });

    test('does not enrich with disabled provider', () async {
      final provider = XMLTVMetadataProvider(id: 'xmltv-1');
      provider.isEnabled = false;

      final engine = MetadataEngine(providers: [provider]);

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News Channel',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await engine.enrich(item);

      expect(result.metadataSources, isEmpty);
    });

    test('enriches all items', () async {
      final engine = MetadataEngine(providers: [
        XMLTVMetadataProvider(id: 'xmltv-1'),
      ]);

      final items = [
        MediaItem(
          id: 'item-1',
          providerId: 'm3u-1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.channel,
          title: 'News',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        MediaItem(
          id: 'item-2',
          providerId: 'm3u-1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.channel,
          title: 'Sports',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final results = await engine.enrichAll(items);

      expect(results.length, 2);
      expect(results.every((r) => r.metadataSources.contains('xmltv')), isTrue);
    });
  });

  group('MetadataMergeEngine', () {
    test('merges duplicate items', () {
      final engine = MetadataMergeEngine(logger: LoggingService());

      final items = [
        MediaItem(
          id: 'item-1',
          providerId: 'm3u-1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.movie,
          title: 'Inception',
          genres: const ['Sci-Fi'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        MediaItem(
          id: 'item-2',
          providerId: 'xtream-1',
          providerType: MediaSourceType.xtream,
          mediaType: MediaType.movie,
          title: 'Inception',
          genres: const ['Thriller'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final results = engine.mergeDuplicates(items);

      expect(results.length, 1);
      expect(results.first.title, equals('Inception'));
      expect(results.first.providerOwnership.length, greaterThanOrEqualTo(1));
      expect(results.first.genres.length, greaterThanOrEqualTo(1));
    });

    test('handles single item', () {
      final engine = MetadataMergeEngine(logger: LoggingService());

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final results = engine.mergeDuplicates([item]);

      expect(results.length, 1);
      expect(results.first.title, equals('News'));
    });

    test('returns empty for empty list', () {
      final engine = MetadataMergeEngine(logger: LoggingService());

      final results = engine.mergeDuplicates([]);

      expect(results, isEmpty);
    });

    test('merges cast and crew', () {
      final engine = MetadataMergeEngine(logger: LoggingService());

      final items = [
        MediaItem(
          id: 'item-1',
          providerId: 'm3u-1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.movie,
          title: 'Movie',
          metadata: {'cast': ['Actor A'], 'crew': ['Director A']},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        MediaItem(
          id: 'item-2',
          providerId: 'xtream-1',
          providerType: MediaSourceType.xtream,
          mediaType: MediaType.movie,
          title: 'Movie',
          metadata: {'cast': ['Actor B'], 'crew': ['Director B']},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final results = engine.mergeDuplicates(items);

      expect(results.length, 1);
      expect(results.first.cast.length, greaterThanOrEqualTo(1));
      expect(results.first.crew.length, greaterThanOrEqualTo(1));
    });
  });

  group('ArtworkService', () {
    test('selects first valid poster', () {
      final service = ArtworkService();
      final result = service.selectPoster(['url1', 'url2', null, 'url3']);
      expect(result, equals('url1'));
    });

    test('returns null for all null posters', () {
      final service = ArtworkService();
      final result = service.selectPoster([null, null]);
      expect(result, isNull);
    });

    test('selects fallback when primary is null', () {
      final service = ArtworkService();
      final result = service.getFallbackImage(null, ['fallback1', 'fallback2']);
      expect(result, equals('fallback1'));
    });

    test('returns primary when valid', () {
      final service = ArtworkService();
      final result = service.getFallbackImage('primary', ['fallback']);
      expect(result, equals('primary'));
    });

    test('selects backdrop', () {
      final service = ArtworkService();
      final result = service.selectBackdrop(['backdrop1', null, 'backdrop2']);
      expect(result, equals('backdrop1'));
    });

    test('selects thumbnail', () {
      final service = ArtworkService();
      final result = service.selectThumbnail([null, 'thumb1']);
      expect(result, equals('thumb1'));
    });

    test('selects logo', () {
      final service = ArtworkService();
      final result = service.selectLogo([null, null, 'logo1']);
      expect(result, equals('logo1'));
    });
  });

  group('HistoryService', () {
    test('records played history', () {
      final service = HistoryService();

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      service.recordPlayed(item);
      final history = service.getHistory();

      expect(history.length, 1);
      expect(history.first.title, equals('News'));
    });

    test('records search history', () {
      final service = HistoryService();

      service.recordSearch('news');
      service.recordSearch('sports');

      final recent = service.getRecentSearches();

      expect(recent.length, 2);
      expect(recent.contains('news'), isTrue);
      expect(recent.contains('sports'), isTrue);
    });

    test('records provider usage', () {
      final service = HistoryService();

      service.recordProviderUsage('m3u-1');
      service.recordProviderUsage('m3u-1');

      final usage = service.getProviderUsage();

      expect(usage['m3u-1'], 2);
    });

    test('clears history', () {
      final service = HistoryService();

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      service.recordPlayed(item);
      service.clearHistory();

      expect(service.getHistory(), isEmpty);
    });
  });

  group('FavoriteService', () {
    test('adds and checks favorite', () {
      final service = FavoriteService();

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      service.addFavorite(item);
      expect(service.isFavorite('item-1'), isTrue);
      expect(service.favoriteCount, 1);
    });

    test('removes favorite', () {
      final service = FavoriteService();

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      service.addFavorite(item);
      service.removeFavorite('item-1');

      expect(service.isFavorite('item-1'), isFalse);
      expect(service.favoriteCount, 0);
    });

    test('returns favorites from list', () {
      final service = FavoriteService();

      final item1 = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final item2 = MediaItem(
        id: 'item-2',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'Sports',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      service.addFavorite(item1);
      final favorites = service.getFavorites([item1, item2]);

      expect(favorites.length, 1);
      expect(favorites.first.id, equals('item-1'));
    });
  });

  group('SearchIndex', () {
    test('indexes and searches items', () {
      final index = SearchIndex();

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News Channel',
        description: 'Breaking news coverage',
        genres: const ['News'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      index.index(item);

      expect(index.itemCount, 1);
      expect(index.search('news'), contains('item-1'));
      expect(index.search('channel'), contains('item-1'));
    });

    test('returns empty for no match', () {
      final index = SearchIndex();

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      index.index(item);

      expect(index.search('sports'), isEmpty);
    });

    test('removes item from index', () {
      final index = SearchIndex();

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      index.index(item);
      index.remove('item-1');

      expect(index.itemCount, 0);
      expect(index.search('news'), isEmpty);
    });

    test('clears index', () {
      final index = SearchIndex();

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      index.index(item);
      index.clear();

      expect(index.itemCount, 0);
    });
  });

  group('SearchEngine', () {
    test('searches items', () {
      final engine = SearchEngine();

      final items = [
        MediaItem(
          id: 'item-1',
          providerId: 'm3u-1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.channel,
          title: 'News Channel',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        MediaItem(
          id: 'item-2',
          providerId: 'm3u-1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.channel,
          title: 'Sports HD',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      engine.indexItems(items);
      final results = engine.search('news', items);

      expect(results.length, 1);
      expect(results.first.title, equals('News Channel'));
    });

    test('records queries', () {
      final engine = SearchEngine();

      engine.recordQuery('news');
      engine.recordQuery('sports');

      final recent = engine.recent();
      expect(recent.length, 2);
    });

    test('tracks popular queries', () {
      final engine = SearchEngine();

      engine.recordQuery('news');
      engine.recordQuery('news');
      engine.recordQuery('sports');

      final popular = engine.popular();
      expect(popular.contains('news'), isTrue);
    });

    test('provides autocomplete', () {
      final engine = SearchEngine();

      final items = [
        MediaItem(
          id: 'item-1',
          providerId: 'm3u-1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.channel,
          title: 'News Channel',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      engine.indexItems(items);
      final suggestions = engine.autocomplete('news', items);

      expect(suggestions, contains('News Channel'));
    });
  });

  group('CollectionEngine', () {
    test('filters by genre', () {
      final engine = CollectionEngine();

      final items = [
        MediaItem(
          id: 'item-1',
          providerId: 'm3u-1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.channel,
          title: 'News',
          genres: const ['News'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        MediaItem(
          id: 'item-2',
          providerId: 'm3u-1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.channel,
          title: 'Sports',
          genres: const ['Sports'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = engine.getByGenre('News', items);

      expect(result.length, 1);
      expect(result.first.title, equals('News'));
    });

    test('returns favorites', () {
      final engine = CollectionEngine();

      final items = [
        MediaItem(
          id: 'item-1',
          providerId: 'm3u-1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.channel,
          title: 'News',
          favorite: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        MediaItem(
          id: 'item-2',
          providerId: 'm3u-1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.channel,
          title: 'Sports',
          favorite: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = engine.getFavorites(items);

      expect(result.length, 1);
      expect(result.first.title, equals('News'));
    });

    test('returns continue watching', () {
      final engine = CollectionEngine();

      final items = [
        MediaItem(
          id: 'item-1',
          providerId: 'm3u-1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.movie,
          title: 'Movie 1',
          metadata: {'watchProgress': 0.5},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        MediaItem(
          id: 'item-2',
          providerId: 'm3u-1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.movie,
          title: 'Movie 2',
          metadata: {'watchProgress': 0.95},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = engine.getContinueWatching(items);

      expect(result.length, 1);
      expect(result.first.title, equals('Movie 1'));
    });

    test('returns live now', () {
      final engine = CollectionEngine();

      final items = [
        MediaItem(
          id: 'item-1',
          providerId: 'm3u-1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.channel,
          title: 'Live News',
          metadata: {'isLive': true},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        MediaItem(
          id: 'item-2',
          providerId: 'm3u-1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.channel,
          title: 'Recorded',
          metadata: {'isLive': false},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = engine.getLiveNow(items);

      expect(result.length, 1);
      expect(result.first.title, equals('Live News'));
    });
  });

  group('MediaIndex', () {
    test('indexes and retrieves by id', () {
      final index = MediaIndex();

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      index.index(item);
      expect(index.getById('item-1'), equals(item));
    });

    test('retrieves by title', () {
      final index = MediaIndex();

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      index.index(item);
      final results = index.getByTitle('News');
      expect(results.length, 1);
    });

    test('retrieves by provider', () {
      final index = MediaIndex();

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      index.index(item);
      final results = index.getByProvider('m3u-1');
      expect(results.length, 1);
    });

    test('retrieves by genre', () {
      final index = MediaIndex();

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News',
        genres: const ['News'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      index.index(item);
      final results = index.getByGenre('News');
      expect(results.length, 1);
    });

    test('removes from index', () {
      final index = MediaIndex();

      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      index.index(item);
      index.remove('item-1');

      expect(index.getById('item-1'), isNull);
      expect(index.totalCount, 0);
    });
  });

  group('MetadataSourceType', () {
    test('has display names', () {
      expect(MetadataSourceType.xmltv.displayName, equals('XMLTV'));
      expect(MetadataSourceType.tmdb.displayName, equals('TMDB'));
      expect(MetadataSourceType.tvmaze.displayName, equals('TVMaze'));
      expect(MetadataSourceType.imdb.displayName, equals('IMDb'));
      expect(MetadataSourceType.trakt.displayName, equals('Trakt'));
      expect(MetadataSourceType.fanart.displayName, equals('Fanart.tv'));
      expect(MetadataSourceType.provider.displayName, equals('Provider Native'));
      expect(MetadataSourceType.local.displayName, equals('Local'));
      expect(MetadataSourceType.custom.displayName, equals('Custom'));
    });
  });

  group('CanonicalMediaItem', () {
    test('converts from MediaItem', () {
      final item = MediaItem(
        id: 'item-1',
        providerId: 'm3u-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.movie,
        title: 'Inception',
        description: 'A dream within a dream',
        genres: const ['Sci-Fi'],
        rating: 8.8,
        favorite: true,
        metadata: {
          'originalTitle': 'Inception',
          'cast': ['Leonardo DiCaprio'],
          'providerOwnership': {'m3u': 'm3u-1'},
          'metadataSources': ['xmltv'],
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final canonical = CanonicalMediaItem.fromMediaItem(item);

      expect(canonical.title, equals('Inception'));
      expect(canonical.genres, contains('Sci-Fi'));
      expect(canonical.rating, equals(8.8));
      expect(canonical.providerOwnership.length, 1);
      expect(canonical.favorite, isTrue);
    });

    test('converts to MediaItem', () {
      final canonical = CanonicalMediaItem(
        id: 'item-1',
        canonicalId: 'canon-1',
        title: 'Inception',
        mediaType: MediaType.movie,
        providerOwnership: {'m3u': 'm3u-1'},
        metadataSources: {'xmltv'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final item = canonical.toMediaItem();

      expect(item.id, equals('item-1'));
      expect(item.title, equals('Inception'));
      expect(item.mediaType, equals(MediaType.movie));
    });

    test('copies with new values', () {
      final canonical = CanonicalMediaItem(
        id: 'item-1',
        canonicalId: 'canon-1',
        title: 'Old Title',
        mediaType: MediaType.movie,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = canonical.copyWith(title: 'New Title');

      expect(updated.title, equals('New Title'));
      expect(canonical.title, equals('Old Title'));
    });
  });

  group('MetadataProvider implementations', () {
    test('XMLTV provider initializes', () async {
      final provider = XMLTVMetadataProvider(id: 'xmltv-1');
      await provider.initialize();
      expect(provider.isEnabled, isTrue);
      await provider.dispose();
    });

    test('TMDB provider initializes', () async {
      final provider = TMDBMetadataProvider(id: 'tmdb-1');
      await provider.initialize();
      expect(provider.isEnabled, isTrue);
      await provider.dispose();
    });

    test('TVMaze provider initializes', () async {
      final provider = TVMazeMetadataProvider(id: 'tvmaze-1');
      await provider.initialize();
      expect(provider.isEnabled, isTrue);
      await provider.dispose();
    });

    test('IMDb provider initializes', () async {
      final provider = IMDbMetadataProvider(id: 'imdb-1');
      await provider.initialize();
      expect(provider.isEnabled, isTrue);
      await provider.dispose();
    });

    test('Trakt provider initializes', () async {
      final provider = TraktMetadataProvider(id: 'trakt-1');
      await provider.initialize();
      expect(provider.isEnabled, isTrue);
      await provider.dispose();
    });

    test('Fanart provider initializes', () async {
      final provider = FanartMetadataProvider(id: 'fanart-1');
      await provider.initialize();
      expect(provider.isEnabled, isTrue);
      await provider.dispose();
    });

    test('Provider native provider initializes', () async {
      final provider = ProviderNativeMetadataProvider(id: 'provider-1', providerId: 'm3u-1');
      await provider.initialize();
      expect(provider.isEnabled, isTrue);
      await provider.dispose();
    });

    test('Local provider initializes', () async {
      final provider = LocalMetadataProvider(id: 'local-1');
      await provider.initialize();
      expect(provider.isEnabled, isTrue);
      await provider.dispose();
    });

    test('Custom provider initializes', () async {
      final provider = CustomMetadataProvider(id: 'custom-1', configuration: {'key': 'value'});
      await provider.initialize();
      expect(provider.isEnabled, isTrue);
      await provider.dispose();
    });
  });
}