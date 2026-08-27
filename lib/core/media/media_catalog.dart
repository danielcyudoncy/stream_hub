import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/canonical_media_item.dart';
import 'package:stream_hub/data/models/media_item.dart';

class MediaCatalog {
  final Map<String, MediaItem> _items = {};
  final Map<String, Set<String>> _providerItemIds = {};
  final Map<String, Set<String>> _categoryItemIds = {};
  final Map<String, Set<String>> _genreItemIds = {};
  final Map<String, CanonicalMediaItem> _canonical = {};

  List<MediaItem> getAll() => _items.values.toList();

  MediaItem? getById(String id) => _items[id];

  CanonicalMediaItem? getCanonical(String id) => _canonical[id];

  List<MediaItem> getByProvider(String providerId) {
    final ids = _providerItemIds[providerId];
    if (ids == null) return [];
    return ids.map((id) => _items[id]).whereType<MediaItem>().toList();
  }

  List<MediaItem> getByType(MediaType type) {
    return _items.values.where((item) => item.mediaType == type).toList();
  }

  List<MediaItem> getByGenre(String genre) {
    final ids = _genreItemIds[genre];
    if (ids == null) return [];
    return ids.map((id) => _items[id]).whereType<MediaItem>().toList();
  }

  void upsert(MediaItem item) {
    final existing = _items[item.id];
    if (existing != null) {
      if (existing.providerId != item.providerId) {
        _providerItemIds[existing.providerId]?.remove(item.id);
      }
      for (final g in existing.genres) {
        if (!item.genres.contains(g)) {
          _genreItemIds[g]?.remove(item.id);
        }
      }
    }
    _items[item.id] = item;
    if (item.providerId.isNotEmpty) {
      _providerItemIds.putIfAbsent(item.providerId, () => <String>{}).add(item.id);
    }
    for (final genre in item.genres) {
      if (genre.isNotEmpty) {
        _genreItemIds.putIfAbsent(genre, () => <String>{}).add(item.id);
      }
    }
  }

  void upsertAll(Iterable<MediaItem> items) {
    for (final item in items) {
      upsert(item);
    }
  }

  void upsertCanonical(CanonicalMediaItem canonical) {
    _canonical[canonical.id] = canonical;
    _items[canonical.id] = canonical.toMediaItem();
  }

  void remove(String id) {
    final item = _items.remove(id);
    if (item != null) {
      _providerItemIds[item.providerId]?.remove(id);
      for (final genre in item.genres) {
        _genreItemIds[genre]?.remove(id);
      }
    }
    _canonical.remove(id);
  }

  void clear() {
    _items.clear();
    _providerItemIds.clear();
    _categoryItemIds.clear();
    _genreItemIds.clear();
    _canonical.clear();
  }

  int get totalCount => _items.length;

  int get canonicalCount => _canonical.length;
}