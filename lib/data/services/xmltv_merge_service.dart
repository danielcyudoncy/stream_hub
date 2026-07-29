import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/models/media_item.dart';

class XMLTVMergeService {
  XMLTVMergeService();

  XMLTVGuide enrichGuide(
    XMLTVGuide guide,
    Map<String, XMLTVChannel> matchedChannels,
  ) {
    final enrichedChannels = <XMLTVChannel>[];

    for (final channel in guide.channels) {
      final matched = matchedChannels[channel.id];
      if (matched != null) {
        enrichedChannels.add(
          channel.copyWith(
            iconUrl: matched.iconUrl ?? channel.iconUrl,
            aliases: [...channel.aliases, ...matched.aliases],
          ),
        );
      } else {
        enrichedChannels.add(channel);
      }
    }

    return guide.copyWith(channels: enrichedChannels);
  }

  List<MediaItem> mergeProgramsIntoCatalog(
    XMLTVGuide guide,
    List<MediaItem> existingItems,
  ) {
    final existingMap = <String, MediaItem>{};
    for (final item in existingItems) {
      existingMap[item.id] = item;
    }

    final merged = <MediaItem>[];

    for (final program in guide.programs) {
      final mediaItem = program.toMediaItem(guide.sourceId);
      final existing = existingMap[mediaItem.id];

      if (existing != null) {
        final enriched = _mergeProgramMetadata(existing, mediaItem);
        merged.add(enriched);
      } else {
        merged.add(mediaItem);
      }
    }

    return merged;
  }

  MediaItem _mergeProgramMetadata(MediaItem existing, MediaItem incoming) {
    final mergedMetadata = <String, dynamic>{
      ...existing.metadata,
      ...incoming.metadata,
    };

    final mergedGenres = <String>{
      ...existing.genres,
      ...incoming.genres,
    }.toList();

    final mergedCast = <String>{
      ...existing.metadata['cast'] is List
          ? List<String>.from(existing.metadata['cast'] as List)
          : <String>[],
      ...incoming.metadata['cast'] is List
          ? List<String>.from(incoming.metadata['cast'] as List)
          : <String>[],
    }.toList();

    final mergedDirectors = <String>{
      ...existing.metadata['directors'] is List
          ? List<String>.from(existing.metadata['directors'] as List)
          : <String>[],
      ...incoming.metadata['directors'] is List
          ? List<String>.from(incoming.metadata['directors'] as List)
          : <String>[],
    }.toList();

    return existing.copyWith(
      title: incoming.title.isNotEmpty ? incoming.title : existing.title,
      subtitle: incoming.subtitle ?? existing.subtitle,
      description: incoming.description ?? existing.description,
      poster: incoming.poster ?? existing.poster,
      genres: mergedGenres,
      rating: incoming.rating ?? existing.rating,
      language: incoming.language ?? existing.language,
      country: incoming.country ?? existing.country,
      metadata: mergedMetadata
        ..['cast'] = mergedCast
        ..['directors'] = mergedDirectors,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, String> buildChannelAliasMap(
    List<XMLTVChannel> xmltvChannels,
    List<MediaItem> existingChannels,
  ) {
    final aliasMap = <String, String>{};

    for (final xmltvChannel in xmltvChannels) {
      for (final existing in existingChannels) {
        if (_isMatch(xmltvChannel, existing)) {
          aliasMap[xmltvChannel.id] = existing.id;
          break;
        }
      }
    }

    return aliasMap;
  }

  bool _isMatch(XMLTVChannel xmltvChannel, MediaItem existing) {
    if (xmltvChannel.id == existing.id) return true;
    if (xmltvChannel.displayName == existing.title) return true;
    if (xmltvChannel.aliases.contains(existing.title)) return true;
    if (existing.metadata['tvgId'] == xmltvChannel.id) return true;

    final existingTvgName = existing.metadata['tvgName'] as String?;
    if (existingTvgName != null && existingTvgName == xmltvChannel.displayName) {
      return true;
    }

    final existingAliases = existing.metadata['aliases'] as List?;
    if (existingAliases != null) {
      for (final alias in existingAliases) {
        if (xmltvChannel.aliases.contains(alias)) return true;
        if (alias == xmltvChannel.displayName) return true;
      }
    }

    return false;
  }
}