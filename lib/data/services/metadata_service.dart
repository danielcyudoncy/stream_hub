import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_metadata.dart';

abstract class MetadataService {
  Future<MediaMetadata> enrich(MediaItem item);
  Future<Map<String, dynamic>> fetch(String itemId);
  Future<void> update(String itemId, Map<String, dynamic> metadata);
  Future<void> batchUpdate(List<String> itemIds, Map<String, dynamic> metadata);
}
