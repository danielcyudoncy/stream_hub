import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/media_item.dart';

class MediaCatalog {
  final Map<String, MediaItem> _items = {};
  final Map<String, List<MediaItem>> _byProvider = {};
  final Map<String, List<MediaItem>> _byCategory = {};
  final Map<String, List<MediaItem>> _byGenre = {};

  List<MediaItem> getAll() => _items.values.toList();

  MediaItem? getById(String id) => _items[id];

  List<MediaItem> getByProvider(String providerId) => _byProvider[providerId] ?? [];

  List<MediaItem> getByType(MediaType type) {
    return _items.values.where((item) => item.mediaType == type).toList();
  }

  List<MediaItem> getByGenre(String genre) => _byGenre[genre] ?? [];

  void upsert(MediaItem item) {
    _items[item.id] = item;
    _byProvider.putIfAbsent(item.providerId, () => []).add(item);
    for (final genre in item.genres) {
      _byGenre.putIfAbsent(genre, () => []).add(item);
    }
  }

  void remove(String id) {
    final item = _items.remove(id);
    if (item != null) {
      _byProvider[item.providerId]?.remove(item);
      for (final genre in item.genres) {
        _byGenre[genre]?.remove(item);
      }
    }
  }

  void clear() {
    _items.clear();
    _byProvider.clear();
    _byCategory.clear();
    _byGenre.clear();
  }

  int get totalCount => _items.length;
}
