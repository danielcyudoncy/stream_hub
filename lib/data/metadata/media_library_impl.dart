import 'dart:async';

import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/metadata/artwork_service.dart';
import 'package:stream_hub/data/metadata/collection_engine.dart';
import 'package:stream_hub/data/metadata/metadata_engine.dart';
import 'package:stream_hub/data/metadata/metadata_merge_engine.dart';
import 'package:stream_hub/data/services/favorite_service.dart';
import 'package:stream_hub/data/services/history_service.dart';
import 'package:stream_hub/data/services/recommendation_service.dart';
import 'package:stream_hub/data/indexes/media_index.dart';
import 'package:stream_hub/data/indexes/search_engine.dart';

class MediaLibraryImpl implements MediaLibrary {
  final MetadataEngine metadataEngine;
  final MetadataMergeEngine mergeEngine;
  final ArtworkService artworkService;
  final CollectionEngine collectionEngine;
  final HistoryService historyService;
  final FavoriteService favoriteService;
  final RecommendationService recommendationService;
  final MediaIndex mediaIndex;
  final SearchEngine searchEngine;

  final List<MediaItem> _liveTV = [];
  final List<MediaItem> _movies = [];
  final List<MediaItem> _series = [];
  final List<MediaItem> _favorites = [];
  final List<MediaItem> _downloads = [];
  final List<MediaItem> _history = [];
  final List<MediaItem> _recent = [];
  final List<MediaItem> _recommended = [];
  final List<MediaItem> _collections = [];

  final StreamController<List<MediaItem>> _liveTVController = StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _moviesController = StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _seriesController = StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _favoritesController = StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _downloadsController = StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _historyController = StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _recentController = StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _recommendedController = StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _searchController = StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _collectionsController = StreamController<List<MediaItem>>.broadcast();

  MediaLibraryImpl({
    MetadataEngine? metadataEngine,
    MetadataMergeEngine? mergeEngine,
    ArtworkService? artworkService,
    CollectionEngine? collectionEngine,
    HistoryService? historyService,
    FavoriteService? favoriteService,
    RecommendationService? recommendationService,
    MediaIndex? mediaIndex,
    SearchEngine? searchEngine,
  })  : metadataEngine = metadataEngine ?? MetadataEngine(),
        mergeEngine = mergeEngine ?? MetadataMergeEngine(logger: LoggingService()),
        artworkService = artworkService ?? ArtworkService(),
        collectionEngine = collectionEngine ?? CollectionEngine(),
        historyService = historyService ?? HistoryService(),
        favoriteService = favoriteService ?? FavoriteService(),
        recommendationService = recommendationService ?? _DefaultRecommendationService(),
        mediaIndex = mediaIndex ?? MediaIndex(),
        searchEngine = searchEngine ?? SearchEngine();

  @override
  Stream<List<MediaItem>> get liveTVStream => _liveTVController.stream;

  @override
  Stream<List<MediaItem>> get moviesStream => _moviesController.stream;

  @override
  Stream<List<MediaItem>> get seriesStream => _seriesController.stream;

  @override
  Stream<List<MediaItem>> get favoritesStream => _favoritesController.stream;

  @override
  Stream<List<MediaItem>> get downloadsStream => _downloadsController.stream;

  @override
  Stream<List<MediaItem>> get historyStream => _historyController.stream;

  @override
  Stream<List<MediaItem>> get recentStream => _recentController.stream;

  @override
  Stream<List<MediaItem>> get recommendedStream => _recommendedController.stream;

  @override
  Stream<List<MediaItem>> get searchStream => _searchController.stream;

  @override
  Stream<List<MediaItem>> get collectionsStream => _collectionsController.stream;

  @override
  List<MediaItem> getLiveTV() => List.unmodifiable(_liveTV);

  @override
  List<MediaItem> getMovies() => List.unmodifiable(_movies);

  @override
  List<MediaItem> getSeries() => List.unmodifiable(_series);

  @override
  List<MediaItem> getFavorites() => List.unmodifiable(_favorites);

  @override
  List<MediaItem> getDownloads() => List.unmodifiable(_downloads);

  @override
  List<MediaItem> getHistory() => List.unmodifiable(historyService.getHistory());

  @override
  List<MediaItem> getRecent() => List.unmodifiable(_recent);

  @override
  List<MediaItem> getRecommended() => List.unmodifiable(_recommended);

  @override
  List<MediaItem> getCollections() => List.unmodifiable(_collections);

  @override
  List<MediaItem> search(String query) {
    if (query.isEmpty) return [];
    searchEngine.recordQuery(query);
    final results = searchEngine.search(query, getAllItems());
    _searchController.add(results);
    return results;
  }

  @override
  List<MediaItem> getByType(MediaType type) {
    switch (type) {
      case MediaType.channel:
        return getLiveTV();
      case MediaType.movie:
        return getMovies();
      case MediaType.series:
        return getSeries();
      default:
        return getAllItems().where((item) => item.mediaType == type).toList();
    }
  }

  @override
  void addToFavorites(MediaItem item) {
    favoriteService.addFavorite(item);
    _updateFavorites();
  }

  @override
  void removeFromFavorites(String itemId) {
    favoriteService.removeFavorite(itemId);
    _updateFavorites();
  }

  @override
  void addToHistory(MediaItem item) {
    historyService.recordPlayed(item);
    _updateHistory();
  }

  @override
  void clearHistory() {
    historyService.clearHistory();
    _updateHistory();
  }

  Future<void> ingest(List<MediaItem> items) async {
    final merged = mergeEngine.mergeDuplicates(items);
    final mergedItems = merged.map((c) => c.toMediaItem()).toList();
    final enriched = await metadataEngine.enrichAll(mergedItems);

    _liveTV.clear();
    _movies.clear();
    _series.clear();
    _recent.clear();

    for (final canonical in enriched) {
      final item = canonical.toMediaItem();
      mediaIndex.index(item);
      switch (item.mediaType) {
        case MediaType.channel:
          _liveTV.add(item);
        case MediaType.movie:
          _movies.add(item);
        case MediaType.series:
          _series.add(item);
        default:
          break;
      }
    }

    _recent.addAll(collectionEngine.getRecentlyAdded(enriched.map((c) => c.toMediaItem()).toList()));
    _updateFavorites();
    _updateHistory();
    _updateDownloads();
    _updateCollections();

    _liveTVController.add(getLiveTV());
    _moviesController.add(getMovies());
    _seriesController.add(getSeries());
    _recentController.add(getRecent());
    searchEngine.indexItems(enriched.map((c) => c.toMediaItem()).toList());
  }

  Future<void> enrichMetadata(List<MediaItem> items) async {
    final enriched = await metadataEngine.enrichAll(items);
    for (final canonical in enriched) {
      mediaIndex.index(canonical.toMediaItem());
    }
  }

  List<MediaItem> getAllItems() {
    return [
      ..._liveTV,
      ..._movies,
      ..._series,
      ..._downloads,
    ];
  }

  void _updateFavorites() {
    _favorites.clear();
    _favorites.addAll(favoriteService.getFavorites(getAllItems()));
    _favoritesController.add(getFavorites());
  }

  void _updateHistory() {
    _history.clear();
    _history.addAll(historyService.getHistory());
    _historyController.add(getHistory());
  }

  void _updateDownloads() {
    _downloads.clear();
    _downloads.addAll(collectionEngine.getDownloads(getAllItems()));
    _downloadsController.add(getDownloads());
  }

  void _updateCollections() {
    _collections.clear();
    _collections.addAll(collectionEngine.getContinueWatching(getAllItems()));
    _collectionsController.add(getCollections());
  }

  void dispose() {
    _liveTVController.close();
    _moviesController.close();
    _seriesController.close();
    _favoritesController.close();
    _downloadsController.close();
    _historyController.close();
    _recentController.close();
    _recommendedController.close();
    _searchController.close();
    _collectionsController.close();
  }
}

class _DefaultRecommendationService implements RecommendationService {
  @override
  Future<List<MediaItem>> similar(String itemId) async => [];

  @override
  Future<List<MediaItem>> becauseYouWatched(String itemId) async => [];

  @override
  Future<List<MediaItem>> continueWatching() async => [];

  @override
  Future<List<MediaItem>> recommended() async => [];

  @override
  Future<void> recordInteraction(String itemId, String type) async {}
}