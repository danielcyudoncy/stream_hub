import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';

abstract class CatalogRepository {
  Future<List<MediaItem>> getAllItems();
  Future<MediaItem?> getItem(String id);
  Future<void> upsertItems(List<MediaItem> items);
  Future<void> deleteItem(String id);
  Future<void> clear();
  Future<List<MediaSyncResult>> syncAll();
  Future<MediaSyncResult> syncSource(String sourceId);
  Future<void> refresh();
  Stream<List<MediaItem>> watchUpdates();
  Future<void> enrichWithXMLTV(XMLTVGuide guide);
  Future<void> mergeXMLTVMetadata(XMLTVGuide guide);
}
