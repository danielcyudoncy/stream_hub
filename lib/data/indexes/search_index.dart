import 'package:stream_hub/data/models/media_item.dart';

class SearchIndex {
  final Map<String, Set<String>> _index = {};
  final Map<String, MediaItem> _items = {};

  void index(MediaItem item) {
    _items[item.id] = item;
    _indexField(item.title, item.id);
    _indexField(item.description, item.id);
    _indexField(item.subtitle, item.id);

    for (final genre in item.genres) {
      _indexField(genre, item.id);
    }

    final language = item.language;
    if (language != null && language.isNotEmpty) {
      _indexField(language, item.id);
    }

    final country = item.country;
    if (country != null && country.isNotEmpty) {
      _indexField(country, item.id);
    }

    final providerType = item.providerType.toString();
    _indexField(providerType, item.id);

    final cast = item.metadata['cast'] as List?;
    if (cast != null) {
      for (final person in cast) {
        _indexField(person.toString(), item.id);
      }
    }

    final directors = item.metadata['directors'] as List?;
    if (directors != null) {
      for (final director in directors) {
        _indexField(director.toString(), item.id);
      }
    }
  }

  void _indexField(String? value, String itemId) {
    if (value == null || value.isEmpty) return;

    final words = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2);

    for (final word in words) {
      _index.putIfAbsent(word, () => <String>{}).add(itemId);
    }
  }

  Set<String> search(String query) {
    if (query.isEmpty) return {};

    final terms = query
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    if (terms.isEmpty) return {};

    final results = <String>{};
    for (final term in terms) {
      final matches = _index[term];
      if (matches != null) {
        results.addAll(matches);
      }
    }

    return results;
  }

  MediaItem? get(String id) => _items[id];

  void remove(String id) {
    _items.remove(id);
    for (final entry in _index.entries) {
      entry.value.remove(id);
    }
  }

  void clear() {
    _index.clear();
    _items.clear();
  }

  int get itemCount => _items.length;
}