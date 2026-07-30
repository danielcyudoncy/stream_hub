import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/history_repository.dart';

class PlaybackHistoryRepository implements HistoryRepository {
  final HistoryRepository delegate;

  PlaybackHistoryRepository(this.delegate);

  @override
  Future<void> add(MediaItem item) => delegate.add(item);

  @override
  Future<void> remove(String itemId) => delegate.remove(itemId);

  @override
  Future<List<MediaItem>> getRecent({int limit = 50}) =>
      delegate.getRecent(limit: limit);

  @override
  Future<void> clear() => delegate.clear();

  @override
  Future<int> get count => delegate.count;

  @override
  Future<void> recordSearch(String query) => delegate.recordSearch(query);

  @override
  Future<List<String>> getRecentSearches({int limit = 10}) =>
      delegate.getRecentSearches(limit: limit);

  @override
  Future<Map<String, int>> getProviderUsage() => delegate.getProviderUsage();
}
