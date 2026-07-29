import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/models/media_item.dart';

class XMLTVSearchService {
  final Map<String, List<MediaItem>> _index = {};
  final Map<String, MediaItem> _items = {};

  void indexGuide(XMLTVGuide guide) {
    for (final program in guide.programs) {
      final item = program.toMediaItem(guide.sourceId);
      _items[item.id] = item;
      _indexItem(item);
    }
  }

  void _indexItem(MediaItem item) {
    _indexField(item.title, item);
    _indexField(item.description, item);
    _indexField(item.subtitle, item);

    final cast = item.metadata['cast'] is List ? List<String>.from(item.metadata['cast'] as List) : <String>[];
    if (cast.isNotEmpty) {
      for (final person in cast) {
        _indexField(person, item);
      }
    }

    final directors = item.metadata['directors'] is List ? List<String>.from(item.metadata['directors'] as List) : <String>[];
    if (directors.isNotEmpty) {
      for (final person in directors) {
        _indexField(person, item);
      }
    }

    for (final genre in item.genres) {
      _indexField(genre, item);
    }

    final language = item.language;
    if (language != null && language.isNotEmpty) {
      _indexField(language, item);
    }
  }

  void _indexField(String? value, MediaItem item) {
    if (value == null || value.isEmpty) return;

    final words = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2);

    for (final word in words) {
      _index.putIfAbsent(word, () => []).add(item);
    }
  }

  List<MediaItem> search(String query) {
    if (query.isEmpty) return [];

    final terms = query
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    if (terms.isEmpty) return [];

    final results = <MediaItem>[];
    final seen = <String>{};

    for (final term in terms) {
      final matches = _index[term] ?? [];
      for (final match in matches) {
        if (!seen.contains(match.id)) {
          seen.add(match.id);
          results.add(match);
        }
      }
    }

    results.sort((a, b) {
      final aScore = _scoreItem(a, terms);
      final bScore = _scoreItem(b, terms);
      return bScore.compareTo(aScore);
    });

    return results;
  }

  int _scoreItem(MediaItem item, List<String> terms) {
    int score = 0;
    final title = item.title.toLowerCase();
    final description = (item.description ?? '').toLowerCase();
    final subtitle = (item.subtitle ?? '').toLowerCase();

    for (final term in terms) {
      if (title.contains(term)) score += 10;
      if (subtitle.contains(term)) score += 5;
      if (description.contains(term)) score += 3;
    }

    return score;
  }

  void clearIndex() {
    _index.clear();
    _items.clear();
  }

  int get indexedItemCount => _items.length;
}