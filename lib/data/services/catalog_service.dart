import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';

abstract class CatalogService {
  Future<void> initialize();
  Future<List<MediaItem>> fetchAll();
  Future<MediaSyncResult> syncSource(String sourceId);
  Future<void> clearCache();
  Future<void> refresh();
}
