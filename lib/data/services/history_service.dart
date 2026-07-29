import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';

class HistoryService {
  final LoggingService logger;
  final List<MediaItem> _history = [];
  final Map<String, DateTime> _searchHistory = {};
  final Map<String, int> _providerUsage = {};

  HistoryService({LoggingService? logger}) : logger = logger ?? LoggingService();

  void recordOpened(MediaItem item) {
    _history.add(item.copyWith());
    logger.info('Recorded opened: ${item.title}', tag: 'HistoryService');
  }

  void recordPlayed(MediaItem item) {
    final existing = _history.indexWhere((h) => h.id == item.id);
    if (existing >= 0) {
      _history[existing] = item.copyWith();
    } else {
      _history.add(item.copyWith());
    }
    logger.info('Recorded played: ${item.title}', tag: 'HistoryService');
  }

  void recordFinished(MediaItem item) {
    final existing = _history.indexWhere((h) => h.id == item.id);
    if (existing >= 0) {
      _history[existing] = item.copyWith();
    }
    logger.info('Recorded finished: ${item.title}', tag: 'HistoryService');
  }

  void recordSearch(String query) {
    _searchHistory[query] = DateTime.now();
    logger.info('Recorded search: $query', tag: 'HistoryService');
  }

  void recordProviderUsage(String providerId) {
    _providerUsage[providerId] = (_providerUsage[providerId] ?? 0) + 1;
  }

  List<MediaItem> getHistory() {
    final sorted = List<MediaItem>.from(_history);
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  List<String> getRecentSearches({int limit = 10}) {
    final entries = _searchHistory.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).map((e) => e.key).toList();
  }

  Map<String, int> getProviderUsage() {
    return Map.unmodifiable(_providerUsage);
  }

  void clearHistory() {
    _history.clear();
    logger.info('History cleared', tag: 'HistoryService');
  }

  void clearSearchHistory() {
    _searchHistory.clear();
    logger.info('Search history cleared', tag: 'HistoryService');
  }
}