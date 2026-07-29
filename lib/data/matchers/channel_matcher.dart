import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/models/media_item.dart';

class ChannelMatcher {
  final Map<String, String> aliases;
  final double fuzzyThreshold;

  ChannelMatcher({
    Map<String, String>? aliases,
    this.fuzzyThreshold = 0.8,
  }) : aliases = aliases != null ? Map<String, String>.from(aliases) : {};

  Map<String, XMLTVChannel> matchChannels(
    List<XMLTVChannel> xmltvChannels,
  ) {
    final matched = <String, XMLTVChannel>{};

    for (final xmltvChannel in xmltvChannels) {
      final match = _findMatch(xmltvChannel);
      if (match != null) {
        matched[xmltvChannel.id] = match;
      }
    }

    return matched;
  }

  Map<String, XMLTVChannel> matchChannelsToExisting(
    List<XMLTVChannel> xmltvChannels,
    List<MediaItem> existingChannels,
  ) {
    final matched = <String, XMLTVChannel>{};

    for (final xmltvChannel in xmltvChannels) {
      for (final existing in existingChannels) {
        if (_isChannelMatch(xmltvChannel, existing)) {
          matched[xmltvChannel.id] = xmltvChannel;
          break;
        }
      }
    }

    return matched;
  }

  XMLTVChannel? _findMatch(XMLTVChannel xmltvChannel) {
    if (aliases.containsKey(xmltvChannel.id)) {
      return xmltvChannel;
    }

    for (final alias in xmltvChannel.aliases) {
      if (aliases.containsKey(alias)) {
        return xmltvChannel;
      }
    }

    if (aliases.containsKey(xmltvChannel.displayName.toLowerCase())) {
      return xmltvChannel;
    }

    return null;
  }

  bool _isChannelMatch(XMLTVChannel xmltvChannel, MediaItem existing) {
    final existingTvgId = existing.metadata['tvgId'] as String?;
    final existingTvgName = existing.metadata['tvgName'] as String?;
    final existingAliases = existing.metadata['aliases'] as List?;

    if (existingTvgId != null && existingTvgId == xmltvChannel.id) {
      return true;
    }

    if (existingTvgName != null && existingTvgName == xmltvChannel.displayName) {
      return true;
    }

    if (existing.id == xmltvChannel.id) {
      return true;
    }

    if (existing.title == xmltvChannel.displayName) {
      return true;
    }

    if (existingAliases != null) {
      for (final alias in existingAliases) {
        if (alias == xmltvChannel.displayName) return true;
        if (xmltvChannel.aliases.contains(alias)) return true;
      }
    }

    for (final alias in xmltvChannel.aliases) {
      if (alias == existing.title) return true;
      if (_fuzzyMatch(alias, existing.title)) {
        return true;
      }
    }

    if (_fuzzyMatch(xmltvChannel.displayName, existing.title)) {
      return true;
    }

    return false;
  }

  bool _fuzzyMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;

    final normalizedA = _normalizeName(a);
    final normalizedB = _normalizeName(b);

    if (normalizedA == normalizedB) return true;

    if (normalizedA.contains(normalizedB) || normalizedB.contains(normalizedA)) {
      return true;
    }

    final similarity = _calculateSimilarity(normalizedA, normalizedB);
    return similarity >= fuzzyThreshold;
  }

  String _normalizeName(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  double _calculateSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final wordsA = a.split(' ').where((w) => w.isNotEmpty).toList();
    final wordsB = b.split(' ').where((w) => w.isNotEmpty).toList();

    if (wordsA.isEmpty && wordsB.isEmpty) return 1.0;
    if (wordsA.isEmpty || wordsB.isEmpty) return 0.0;

    int matchingWords = 0;
    for (final wordA in wordsA) {
      for (final wordB in wordsB) {
        if (wordA == wordB) {
          matchingWords++;
          break;
        }
        if (wordA.contains(wordB) || wordB.contains(wordA)) {
          matchingWords++;
          break;
        }
      }
    }

    final totalWords = wordsA.length + wordsB.length;
    return totalWords > 0 ? (2.0 * matchingWords / totalWords) : 0.0;
  }

  void addAlias(String xmltvId, String existingId) {
    aliases[xmltvId] = existingId;
  }

  void removeAlias(String xmltvId) {
    aliases.remove(xmltvId);
  }
}