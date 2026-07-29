import 'package:stream_hub/data/models/media_item.dart';

abstract class MediaLibraryRepository {
  Future<void> ingest(List<MediaItem> items);
  Future<void> enrichMetadata(List<MediaItem> items);
  List<MediaItem> getAllItems();
  List<MediaItem> getByType(String type);
  List<MediaItem> search(String query);
  void addToFavorites(MediaItem item);
  void removeFromFavorites(String itemId);
  void addToHistory(MediaItem item);
  void clearHistory();
}