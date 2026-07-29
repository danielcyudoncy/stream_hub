import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';

class FavoriteService {
  final LoggingService logger;
  final Set<String> _favoriteIds = {};
  final Map<String, DateTime> _favoritedAt = {};

  FavoriteService({LoggingService? logger}) : logger = logger ?? LoggingService();

  void addFavorite(MediaItem item) {
    _favoriteIds.add(item.id);
    _favoritedAt[item.id] = DateTime.now();
    logger.info('Added favorite: ${item.title}', tag: 'FavoriteService');
  }

  void removeFavorite(String itemId) {
    _favoriteIds.remove(itemId);
    _favoritedAt.remove(itemId);
    logger.info('Removed favorite: $itemId', tag: 'FavoriteService');
  }

  bool isFavorite(String itemId) => _favoriteIds.contains(itemId);

  List<MediaItem> getFavorites(List<MediaItem> allItems) {
    return allItems.where((item) => _favoriteIds.contains(item.id)).toList();
  }

  int get favoriteCount => _favoriteIds.length;

  void clearFavorites() {
    _favoriteIds.clear();
    _favoritedAt.clear();
    logger.info('Favorites cleared', tag: 'FavoriteService');
  }
}