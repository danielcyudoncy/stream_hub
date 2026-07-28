import 'package:stream_hub/data/models/media_item.dart';

abstract class MergeService {
  Future<List<MediaItem>> mergeDuplicates(List<MediaItem> items);
  Future<String> normalizeTitle(String title);
  Future<Map<String, dynamic>> normalizeMetadata(Map<String, dynamic> metadata);
  Future<Map<String, dynamic>> resolveConflicts(List<Map<String, dynamic>> candidates);
  Future<String?> choosePreferredArtwork(List<String> urls);
}
