import 'package:stream_hub/data/models/media_item.dart';

abstract class RecommendationService {
  Future<List<MediaItem>> similar(String itemId);
  Future<List<MediaItem>> becauseYouWatched(String itemId);
  Future<List<MediaItem>> continueWatching();
  Future<List<MediaItem>> recommended();
  Future<void> recordInteraction(String itemId, String type);
}