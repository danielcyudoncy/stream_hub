import 'dart:async';

import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/media_item.dart';

abstract class MediaLibrary {
  Stream<List<MediaItem>> get liveTVStream;
  Stream<List<MediaItem>> get moviesStream;
  Stream<List<MediaItem>> get seriesStream;
  Stream<List<MediaItem>> get favoritesStream;
  Stream<List<MediaItem>> get downloadsStream;
  Stream<List<MediaItem>> get historyStream;
  Stream<List<MediaItem>> get recentStream;
  Stream<List<MediaItem>> get recommendedStream;
  Stream<List<MediaItem>> get searchStream;
  Stream<List<MediaItem>> get collectionsStream;

  List<MediaItem> getLiveTV();
  List<MediaItem> getMovies();
  List<MediaItem> getSeries();
  List<MediaItem> getFavorites();
  List<MediaItem> getDownloads();
  List<MediaItem> getHistory();
  List<MediaItem> getRecent();
  List<MediaItem> getRecommended();
  List<MediaItem> getCollections();
  List<MediaItem> search(String query);
  List<MediaItem> getByType(MediaType type);
  void addToFavorites(MediaItem item);
  void removeFromFavorites(String itemId);
  void addToHistory(MediaItem item);
  void clearHistory();
}
