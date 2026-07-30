import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/history_repository.dart';
import 'package:stream_hub/data/services/history_service.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  final HistoryService _service;

  HistoryRepositoryImpl(this._service);

  @override
  Future<void> add(MediaItem item) async {
    _service.recordPlayed(item);
  }

  @override
  Future<void> remove(String itemId) async {
  }

  @override
  Future<List<MediaItem>> getRecent({int limit = 50}) async {
    final history = _service.getHistory();
    return history.take(limit).toList();
  }

  @override
  Future<void> clear() async {
    _service.clearHistory();
  }

  @override
  Future<int> get count async => _service.getHistory().length;

  @override
  Future<void> recordSearch(String query) async {
    _service.recordSearch(query);
  }

  @override
  Future<List<String>> getRecentSearches({int limit = 10}) async {
    return _service.getRecentSearches(limit: limit);
  }

  @override
  Future<Map<String, int>> getProviderUsage() async {
    return _service.getProviderUsage();
  }
}
