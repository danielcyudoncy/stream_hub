import 'package:stream_hub/data/models/media_item.dart';

abstract class FavoriteRepository {
  Stream<void> watchUpdates();
  Future<void> add(MediaItem item);
  Future<void> remove(String itemId);
  Future<List<MediaItem>> getAll();
  Future<bool> isFavorite(String itemId);
  Future<void> clear();
  Future<int> get count;
}