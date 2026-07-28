import 'package:stream_hub/data/models/media_item.dart';

abstract class FilterService {
  List<MediaItem> applyFilters(List<MediaItem> items, Map<String, dynamic> filters);
  List<MediaItem> byGenre(List<MediaItem> items, List<String> genres);
  List<MediaItem> byLanguage(List<MediaItem> items, List<String> languages);
  List<MediaItem> byCountry(List<MediaItem> items, List<String> countries);
  List<MediaItem> byProvider(List<MediaItem> items, List<String> providerIds);
  List<MediaItem> byResolution(List<MediaItem> items, List<String> resolutions);
  List<MediaItem> favoritesOnly(List<MediaItem> items);
  List<MediaItem> downloadsOnly(List<MediaItem> items);
  List<MediaItem> recentlyAdded(List<MediaItem> items);
  List<MediaItem> continueWatching(List<MediaItem> items);
}
