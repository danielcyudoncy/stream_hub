import 'package:stream_hub/data/models/media_item.dart';

class MediaIndex {
  final Map<String, MediaItem> _byId = {};
  final Map<String, List<MediaItem>> _byTitle = {};
  final Map<String, List<MediaItem>> _byProvider = {};
  final Map<String, List<MediaItem>> _byCategory = {};
  final Map<String, List<MediaItem>> _byGenre = {};
  final Map<String, List<MediaItem>> _byLanguage = {};
  final Map<String, List<MediaItem>> _byType = {};

  void index(MediaItem item) {
    _byId[item.id] = item;
    _byTitle.putIfAbsent(item.title.toLowerCase(), () => []).add(item);
    _byProvider.putIfAbsent(item.providerId, () => []).add(item);
    for (final genre in item.genres) {
      _byGenre.putIfAbsent(genre.toLowerCase(), () => []).add(item);
    }
    final language = item.language;
    if (language != null && language.isNotEmpty) {
      _byLanguage.putIfAbsent(language.toLowerCase(), () => []).add(item);
    }
    _byType.putIfAbsent(item.mediaType.toString(), () => []).add(item);
  }

  MediaItem? getById(String id) => _byId[id];

  List<MediaItem> getByTitle(String title) => _byTitle[title.toLowerCase()] ?? [];

  List<MediaItem> getByProvider(String providerId) => _byProvider[providerId] ?? [];

  List<MediaItem> getByCategory(String category) => _byCategory[category.toLowerCase()] ?? [];

  List<MediaItem> getByGenre(String genre) => _byGenre[genre.toLowerCase()] ?? [];

  List<MediaItem> getByLanguage(String language) => _byLanguage[language.toLowerCase()] ?? [];

  List<MediaItem> getByType(String type) => _byType[type] ?? [];

  void remove(String id) {
    final item = _byId.remove(id);
    if (item == null) return;

    _byTitle[item.title.toLowerCase()]?.remove(item);
    _byProvider[item.providerId]?.remove(item);
    for (final genre in item.genres) {
      _byGenre[genre.toLowerCase()]?.remove(item);
    }
    final language = item.language;
    if (language != null && language.isNotEmpty) {
      _byLanguage[language.toLowerCase()]?.remove(item);
    }
    _byType[item.mediaType.toString()]?.remove(item);
  }

  void clear() {
    _byId.clear();
    _byTitle.clear();
    _byProvider.clear();
    _byCategory.clear();
    _byGenre.clear();
    _byLanguage.clear();
    _byType.clear();
  }

  int get totalCount => _byId.length;
}