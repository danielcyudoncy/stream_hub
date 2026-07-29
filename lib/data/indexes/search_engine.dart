import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/indexes/search_index.dart';
import 'package:stream_hub/data/models/media_item.dart';

class SearchEngine {
  final SearchIndex index;
  final LoggingService logger;
  final List<String> _recentQueries = [];
  final Map<String, int> _popularQueries = {};

  SearchEngine({LoggingService? logger, SearchIndex? index})
      : logger = logger ?? LoggingService(),
        index = index ?? SearchIndex();

  List<MediaItem> search(String query, List<MediaItem> allItems) {
    if (query.isEmpty) return [];

    final matches = index.search(query);
    return allItems.where((item) => matches.contains(item.id)).toList();
  }

  List<MediaItem> instantSearch(String query, List<MediaItem> allItems) {
    return search(query, allItems);
  }

  List<String> suggest(String query, List<MediaItem> allItems) {
    final results = search(query, allItems);
    return results.map((item) => item.title).toList();
  }

  List<String> recent({int limit = 10}) {
    return _recentQueries.take(limit).toList();
  }

  List<String> popular({int limit = 10}) {
    final entries = _popularQueries.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).map((e) => e.key).toList();
  }

  List<String> autocomplete(String query, List<MediaItem> allItems) {
    final results = search(query, allItems);
    return results.map((item) => item.title).toList();
  }

  void recordQuery(String query) {
    if (query.isEmpty) return;
    _recentQueries.insert(0, query);
    if (_recentQueries.length > 100) _recentQueries.removeLast();
    _popularQueries[query] = (_popularQueries[query] ?? 0) + 1;
  }

  void indexItems(List<MediaItem> items) {
    for (final item in items) {
      index.index(item);
    }
    logger.info('Indexed ${items.length} items', tag: 'SearchEngine');
  }

  void clearIndex() {
    index.clear();
    _recentQueries.clear();
    _popularQueries.clear();
  }
}