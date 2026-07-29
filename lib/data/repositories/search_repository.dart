import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';

abstract class SearchRepository {
  Future<List<MediaItem>> search(String query);
  Future<List<MediaItem>> searchChannels(String query);
  Future<List<MediaItem>> searchMovies(String query);
  Future<List<MediaItem>> searchSeries(String query);
  Future<List<MediaItem>> searchPrograms(String query);
  Future<List<MediaItem>> searchProviders(String query);
  Future<void> index(List<MediaItem> items);
  Future<void> clearIndex();
  Future<void> update(String itemId, Map<String, dynamic> changes);
  Future<void> delete(String itemId);
  Future<void> indexXMLTVGuide(XMLTVGuide guide);
  Future<List<MediaItem>> searchXMLTV(String query);
}
