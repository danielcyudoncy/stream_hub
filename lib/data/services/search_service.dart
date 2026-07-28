import 'package:stream_hub/data/models/media_item.dart';

abstract class SearchService {
  Future<List<MediaItem>> search(String query);
  Future<List<MediaItem>> searchChannels(String query);
  Future<List<MediaItem>> searchMovies(String query);
  Future<List<MediaItem>> searchSeries(String query);
  Future<List<MediaItem>> searchPrograms(String query);
  Future<List<MediaItem>> searchProviders(String query);
  Future<void> index(List<MediaItem> items);
  Future<void> clearIndex();
}
