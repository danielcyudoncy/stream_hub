import 'package:stream_hub/data/models/media_item.dart';

abstract class HistoryRepository {
  Future<void> add(MediaItem item);
  Future<void> remove(String itemId);
  Future<List<MediaItem>> getRecent({int limit = 50});
  Future<void> clear();
  Future<int> get count;
  Future<void> recordSearch(String query);
  Future<List<String>> getRecentSearches({int limit = 10});
  Future<Map<String, int>> getProviderUsage();
}