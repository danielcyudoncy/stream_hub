import 'dart:async';

import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/data/models/media_item.dart';

class DefaultMediaLibrary implements MediaLibrary {
  final List<MediaItem> _favorites = [];
  final List<MediaItem> _history = [];
  final List<MediaItem> _recent = [];
  final List<MediaItem> _downloads = [];
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
  List<MediaItem> getLiveTV() => List.unmodifiable(_recent.where((item) => item.mediaType == MediaType.channel).toList());

  @override
  List<MediaItem> getMovies() => List.unmodifiable(_favorites.where((item) => item.mediaType == MediaType.movie).toList());

  @override
  List<MediaItem> getSeries() => List.unmodifiable(_favorites.where((item) => item.mediaType == MediaType.series).toList());

  @override
  List<MediaItem> getFavorites() => List.unmodifiable(_favorites);

  @override
  List<MediaItem> getDownloads() => List.unmodifiable(_downloads);

  @override
  List<MediaItem> getHistory() => List.unmodifiable(_history);

  @override
  List<MediaItem> getRecent() => List.unmodifiable(_recent);

  @override
  List<MediaItem> getRecommended() => const <MediaItem>[];

  @override
  List<MediaItem> getCollections() => List.unmodifiable(_collections);

  @override
  List<MediaItem> search(String query) {
    final lower = query.toLowerCase();
    final results = _favorites.where((item) => item.title.toLowerCase().contains(lower)).toList();
    _searchController.add(results);
    return results;
  }

  @override
  List<MediaItem> getByType(MediaType type) {
    return _favorites.where((item) => item.mediaType == type).toList();
  }

  @override
  void addToFavorites(MediaItem item) {
    if (!_favorites.any((i) => i.id == item.id)) {
      _favorites.add(item);
      _favoritesController.add(List.unmodifiable(_favorites));
    }
  }

  @override
  void removeFromFavorites(String itemId) {
    _favorites.removeWhere((i) => i.id == itemId);
    _favoritesController.add(List.unmodifiable(_favorites));
  }

  @override
  void addToHistory(MediaItem item) {
    _history.removeWhere((i) => i.id == item.id);
    _history.insert(0, item);
    if (_history.length > 200) _history.removeLast();
    _historyController.add(List.unmodifiable(_history));
  }

  @override
  void clearHistory() {
    _history.clear();
    _historyController.add(const []);
  }
}
