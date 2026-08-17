import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';

class FavoriteService {
  final LoggingService logger;
  final Box? _box;
  final Set<String> _favoriteIds = {};
  final Map<String, DateTime> _favoritedAt = {};
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  Stream<void> get onChange => _changeController.stream;

  FavoriteService({LoggingService? logger, Box? box})
      : logger = logger ?? LoggingService(),
        _box = box {
    _loadFromBox();
  }

  void _loadFromBox() {
    if (_box != null) {
      try {
        for (final key in _box.keys) {
          final keyStr = key.toString();
          _favoriteIds.add(keyStr);
          final val = _box.get(key);
          if (val is String) {
            _favoritedAt[keyStr] = DateTime.tryParse(val) ?? DateTime.now();
          } else {
            _favoritedAt[keyStr] = DateTime.now();
          }
        }
        logger.info(
          'Loaded ${_favoriteIds.length} favorites from persistent storage',
          tag: 'FavoriteService',
        );
      } catch (e) {
        logger.warning(
          'Failed to load favorites from box',
          tag: 'FavoriteService',
          error: e,
        );
      }
    }
  }

  Future<void> addFavorite(MediaItem item) async {
    _favoriteIds.add(item.id);
    _favoritedAt[item.id] = DateTime.now();
    if (_box != null) {
      try {
        await _box.put(item.id, DateTime.now().toIso8601String());
      } catch (e) {
        logger.warning(
          'Failed to persist favorite ${item.id}',
          tag: 'FavoriteService',
          error: e,
        );
      }
    }
    _changeController.add(null);
    logger.info('Added favorite: ${item.title}', tag: 'FavoriteService');
  }

  Future<void> removeFavorite(String itemId) async {
    _favoriteIds.remove(itemId);
    _favoritedAt.remove(itemId);
    if (_box != null) {
      try {
        await _box.delete(itemId);
      } catch (e) {
        logger.warning(
          'Failed to delete favorite $itemId from storage',
          tag: 'FavoriteService',
          error: e,
        );
      }
    }
    _changeController.add(null);
    logger.info('Removed favorite: $itemId', tag: 'FavoriteService');
  }

  bool isFavorite(String itemId) => _favoriteIds.contains(itemId);

  List<MediaItem> getFavorites(List<MediaItem> allItems) {
    return allItems.where((item) => _favoriteIds.contains(item.id)).toList();
  }

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  int get favoriteCount => _favoriteIds.length;

  Future<void> clearFavorites() async {
    _favoriteIds.clear();
    _favoritedAt.clear();
    if (_box != null) {
      try {
        await _box.clear();
      } catch (e) {
        logger.warning(
          'Failed to clear favorites box',
          tag: 'FavoriteService',
          error: e,
        );
      }
    }
    _changeController.add(null);
    logger.info('Favorites cleared', tag: 'FavoriteService');
  }
}