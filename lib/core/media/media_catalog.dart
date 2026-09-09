import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/canonical_media_item.dart';
import 'package:stream_hub/data/models/media_item.dart';

/// Bounded, newest-first index that stays cheap no matter how large the
/// catalog grows. Queries only ever touch at most [maxEntries] items instead
/// of re-scanning and re-sorting the full catalog.
class _LeadIndex {
  _LeadIndex(this._keyOf);

  static const int maxEntries = 64;

  final DateTime Function(MediaItem item) _keyOf;
  final List<MediaItem> _entries = <MediaItem>[];

  void add(MediaItem item) {
    final existing = _indexOf(item.id);
    if (existing >= 0) {
      _entries.removeAt(existing);
    }
    final key = _keyOf(item);
    var low = 0;
    var high = _entries.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      // Insert at the first entry that is strictly older (descending order).
      if (_keyOf(_entries[mid]).isBefore(key)) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    _entries.insert(low, item);
    if (_entries.length > maxEntries) {
      _entries.removeLast();
    }
  }

  void remove(String id) {
    final index = _indexOf(id);
    if (index >= 0) {
      _entries.removeAt(index);
    }
  }

  List<MediaItem> top(int count) {
    if (count >= _entries.length) return List.of(_entries);
    return _entries.sublist(0, count);
  }

  void clear() => _entries.clear();

  int _indexOf(String id) {
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].id == id) return i;
    }
    return -1;
  }
}

class _LeadPair {
  final UpdateLeads updatedAt = UpdateLeads();
  final _LeadIndex created = _LeadIndex((item) => item.createdAt);

  void add(MediaItem item) {
    updatedAt.add(item);
    created.add(item);
  }

  void remove(String id) {
    updatedAt.remove(id);
    created.remove(id);
  }

  void clear() {
    updatedAt.clear();
    created.clear();
  }
}

class UpdateLeads {
  final _LeadIndex _index = _LeadIndex((item) => item.updatedAt);

  void add(MediaItem item) => _index.add(item);

  void remove(String id) => _index.remove(id);

  void clear() => _index.clear();

  List<MediaItem> top(int count) => _index.top(count);
}

class MediaCatalog {
  final Map<String, MediaItem> _items = {};
  final Map<String, Set<String>> _providerItemIds = {};
  final Map<MediaType, Set<String>> _typeItemIds = {};
  final Map<String, Set<String>> _categoryItemIds = {};
  final Map<String, Set<String>> _genreItemIds = {};
  final Map<String, CanonicalMediaItem> _canonical = {};

  final Map<MediaType, _LeadPair> _globalLeads = {};
  final Map<String, Map<MediaType, _LeadPair>> _providerLeads = {};

  List<MediaItem> getAll() => _items.values.toList();

  MediaItem? getById(String id) => _items[id];

  CanonicalMediaItem? getCanonical(String id) => _canonical[id];

  List<MediaItem> getByProvider(String providerId) {
    final ids = _providerItemIds[providerId];
    if (ids == null) return [];
    return ids.map((id) => _items[id]).whereType<MediaItem>().toList();
  }

  List<MediaItem> getByProviderAndType(String providerId, MediaType type) {
    final ids = _providerItemIds[providerId];
    if (ids == null) return [];
    return ids
        .map((id) => _items[id])
        .whereType<MediaItem>()
        .where((item) => item.mediaType == type)
        .toList();
  }

  List<MediaItem> getByType(MediaType type) {
    final ids = _typeItemIds[type];
    if (ids == null) return [];
    return ids.map((id) => _items[id]).whereType<MediaItem>().toList();
  }

  List<MediaItem> getByGenre(String genre) {
    final ids = _genreItemIds[genre];
    if (ids == null) return [];
    return ids.map((id) => _items[id]).whereType<MediaItem>().toList();
  }

  /// Newest [limit] items of [type], optionally scoped to [providerId].
  List<MediaItem> topByUpdatedAt(
    MediaType type, {
    String? providerId,
    int limit = 20,
  }) {
    return _leadsFor(providerId, type).updatedAt.top(limit);
  }

  /// Newest [limit] items of [type], optionally scoped to [providerId].
  List<MediaItem> topByCreatedAt(
    MediaType type, {
    String? providerId,
    int limit = 20,
  }) {
    return _leadsFor(providerId, type).created.top(limit);
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
    _register(item);
  }

  void upsertAll(Iterable<MediaItem> items) {
    for (final item in items) {
      upsert(item);
    }
  }

  void upsertCanonical(CanonicalMediaItem canonical) {
    _canonical[canonical.id] = canonical;
    _register(canonical.toMediaItem());
  }

  void remove(String id) {
    final item = _items.remove(id);
    if (item != null) {
      _unregister(item);
      _canonical.remove(id);
    }
  }

  void clear() {
    _items.clear();
    _providerItemIds.clear();
    _typeItemIds.clear();
    _categoryItemIds.clear();
    _genreItemIds.clear();
    _canonical.clear();
    _globalLeads.clear();
    _providerLeads.clear();
  }

  int get totalCount => _items.length;

  int get canonicalCount => _canonical.length;

  void _register(MediaItem item) {
    _items[item.id] = item;
    if (item.providerId.isNotEmpty) {
      _providerItemIds.putIfAbsent(item.providerId, () => <String>{}).add(item.id);
    }
    _typeItemIds.putIfAbsent(item.mediaType, () => <String>{}).add(item.id);
    for (final genre in item.genres) {
      if (genre.isNotEmpty) {
        _genreItemIds.putIfAbsent(genre, () => <String>{}).add(item.id);
      }
    }
    _leadsFor(null, item.mediaType).add(item);
    _leadsFor(item.providerId, item.mediaType).add(item);
  }

  void _unregister(MediaItem item) {
    _providerItemIds[item.providerId]?.remove(item.id);
    _typeItemIds[item.mediaType]?.remove(item.id);
    for (final genre in item.genres) {
      _genreItemIds[genre]?.remove(item.id);
    }
    final globalPair = _globalLeads[item.mediaType];
    if (globalPair != null) {
      globalPair.remove(item.id);
    }
    final providerLeads = _providerLeads[item.providerId];
    final providerPair = providerLeads?[item.mediaType];
    if (providerPair != null) {
      providerPair.remove(item.id);
    }
  }

  _LeadPair _leadsFor(String? providerId, MediaType type) {
    if (providerId == null || providerId.isEmpty) {
      return _globalLeads.putIfAbsent(type, _LeadPair.new);
    }
    final perType = _providerLeads.putIfAbsent(providerId, () => <MediaType, _LeadPair>{});
    return perType.putIfAbsent(type, _LeadPair.new);
  }
}