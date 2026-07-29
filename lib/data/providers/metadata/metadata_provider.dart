import 'package:stream_hub/data/models/metadata_models.dart';
import 'package:stream_hub/data/models/media_item.dart';

abstract class MetadataProvider {
  String get id;
  MetadataSourceType get sourceType;
  bool get isEnabled;

  Future<void> initialize();
  Future<void> refresh();
  Future<MediaItem?> search(String query);
  Future<MediaItem?> lookup(String externalId);
  Future<MediaItem> enrich(MediaItem item);
  Future<bool> validate();
  Future<void> dispose();
}