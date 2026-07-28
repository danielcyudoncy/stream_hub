import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_metadata.dart';

abstract class MediaRepository {
  Future<List<MediaItem>> getAll();
  Future<MediaItem?> getById(String id);
  Future<MediaItem> save(MediaItem item);
  Future<void> delete(String id);
  Future<List<MediaItem>> batchSave(List<MediaItem> items);
  Future<void> clear();
  Future<MediaMetadata?> getMetadata(String itemId);
  Future<void> saveMetadata(String itemId, MediaMetadata metadata);
  Stream<List<MediaItem>> watchAll();
}
