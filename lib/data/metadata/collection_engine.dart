import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';

class CollectionEngine {
  final LoggingService logger;

  CollectionEngine({LoggingService? logger}) : logger = logger ?? LoggingService();

  List<MediaItem> getByGenre(String genre, List<MediaItem> items) {
    return items.where((item) => item.genres.contains(genre)).toList();
  }

  List<MediaItem> getRecentlyAdded(List<MediaItem> items, {int limit = 20}) {
    final sorted = List<MediaItem>.from(items);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  List<MediaItem> getFavorites(List<MediaItem> items) {
    return items.where((item) => item.favorite).toList();
  }

  List<MediaItem> getDownloads(List<MediaItem> items) {
    return items.where((item) => item.metadata['downloaded'] == true).toList();
  }

  List<MediaItem> getContinueWatching(List<MediaItem> items) {
    return items.where((item) {
      final progress = item.metadata['watchProgress'] as double?;
      return progress != null && progress > 0 && progress < 0.95;
    }).toList();
  }

  List<MediaItem> getLiveNow(List<MediaItem> items) {
    return items.where((item) => item.metadata['isLive'] == true).toList();
  }

  List<MediaItem> getUpcoming(List<MediaItem> items) {
    return items.where((item) {
      final start = item.metadata['start']?.toString();
      if (start == null) return false;
      final startDate = DateTime.tryParse(start);
      return startDate != null && startDate.isAfter(DateTime.now());
    }).toList();
  }

  List<MediaItem> getCustomCollection(String collectionId, List<MediaItem> items) {
    return items.where((item) {
      final collections = item.metadata['collections'] as List?;
      return collections != null && collections.contains(collectionId);
    }).toList();
  }

  List<String> getAllGenres(List<MediaItem> items) {
    final genres = <String>{};
    for (final item in items) {
      genres.addAll(item.genres);
    }
    return genres.toList()..sort();
  }
}