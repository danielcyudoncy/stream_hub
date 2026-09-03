import 'package:stream_hub/data/models/dearbulut_dtos.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/models/free_tv_stream.dart';
import 'package:stream_hub/data/sources/free_tv_regions.dart';

/// Pure mapping layer translating upstream DTOs into normalized domain entities.
///
/// Keeps the Flutter application isolated from external schema variations.
class FreeTvMapper {
  static const Map<String, String> _knownCategoryDisplayNames = {
    'news': 'News',
    'sports': 'Sports',
    'entertainment': 'Entertainment',
    'kids': 'Kids',
    'documentary': 'Documentary',
    'movies': 'Movies',
    'music': 'Music',
    'general': 'General',
    'family': 'Family',
    'culture': 'Culture',
    'lifestyle': 'Lifestyle',
    'education': 'Education',
    'comedy': 'Comedy',
    'animation': 'Animation',
    'classic': 'Classic',
    'cooking': 'Cooking',
    'auto': 'Auto',
    'business': 'Business',
    'legislative': 'Legislative',
    'religious': 'Religious',
    'science': 'Science',
    'series': 'Series',
    'shop': 'Shopping',
    'travel': 'Travel',
    'weather': 'Weather',
    'relax': 'Relax',
    'outdoor': 'Outdoor',
  };

  static const Map<String, String> _knownLanguages = {
    'eng': 'English',
    'en': 'English',
    'fra': 'French',
    'fre': 'French',
    'deu': 'German',
    'ger': 'German',
    'spa': 'Spanish',
    'por': 'Portuguese',
    'ita': 'Italian',
    'ara': 'Arabic',
    'rus': 'Russian',
    'zho': 'Chinese',
    'chi': 'Chinese',
    'jpn': 'Japanese',
    'kor': 'Korean',
    'hin': 'Hindi',
    'hau': 'Hausa',
    'yor': 'Yoruba',
    'ibo': 'Igbo',
    'swa': 'Swahili',
    'zul': 'Zulu',
    'afr': 'Afrikaans',
    'tur': 'Turkish',
    'nld': 'Dutch',
    'dut': 'Dutch',
    'pol': 'Polish',
    'ukr': 'Ukrainian',
    'ell': 'Greek',
    'gre': 'Greek',
  };

  /// Maps a [DearbulutChannelDto] to a normalized [FreeTvChannel].
  FreeTvChannel fromDearbulutDto(
    DearbulutChannelDto dto, {
    Map<String, String>? countryNameLookup,
    bool isFavorite = false,
  }) {
    final rawCc = (dto.country ?? '').trim().toUpperCase();
    final countryCode = rawCc == 'UK' ? 'GB' : rawCc;
    final resolvedCountry = countryNameLookup?[countryCode] ??
        FreeTvRegions.countryNameForCode(countryCode) ??
        (dto.country?.isNotEmpty == true ? dto.country! : 'International');

    final region = FreeTvRegions.regionForCountryCode(countryCode);

    final normalizedCategories = dto.categories.map((c) {
      final key = c.trim().toLowerCase();
      return _knownCategoryDisplayNames[key] ?? _capitalize(key);
    }).where((c) => c.isNotEmpty).toList();

    final normalizedLanguages = dto.languages.map((l) {
      final key = l.trim().toLowerCase();
      return _knownLanguages[key] ?? _capitalize(key);
    }).where((l) => l.isNotEmpty).toList();

    final streams = dto.streams.map((s) => fromDearbulutStream(s)).toList();
    // Prioritize verified online streams and higher health scores so primary stream is working
    streams.sort((a, b) {
      if (a.isOnline != b.isOnline) {
        return a.isOnline ? -1 : 1;
      }
      final scoreA = a.healthScore ?? (a.isOnline ? 100.0 : 0.0);
      final scoreB = b.healthScore ?? (b.isOnline ? 100.0 : 0.0);
      return scoreB.compareTo(scoreA);
    });
    final streamUrls = streams.map((s) => s.url).where((u) => u.isNotEmpty).toList();

    final hasWorkingStream = dto.online ||
        streams.any((s) => s.isOnline);

    return FreeTvChannel(
      id: dto.id,
      name: dto.name.trim(),
      nativeName: dto.altNames.isNotEmpty ? dto.altNames.first.trim() : null,
      network: dto.network?.trim(),
      country: resolvedCountry,
      countryCode: countryCode,
      region: region,
      subdivision: dto.subdivision?.trim(),
      broadcastArea: dto.broadcastArea,
      languages: normalizedLanguages,
      categories: normalizedCategories,
      isNsfw: dto.isNsfw,
      website: dto.website?.trim(),
      logo: dto.logo?.trim(),
      streamUrls: streamUrls,
      streams: streams,
      source: 'dearbulut',
      isFavorite: isFavorite,
      isWorking: hasWorkingStream ? true : (dto.score == 0 ? null : false),
      qualityScore: dto.score.toInt(),
      qualityTier: FreeTvQualityTier.valid,
    );
  }

  /// Maps a [DearbulutStreamDto] to a domain [FreeTvStream].
  FreeTvStream fromDearbulutStream(DearbulutStreamDto dto) {
    final isOnline = dto.health?.status == 'online' ||
        (dto.health == null && dto.url.isNotEmpty);
    final healthScore = dto.health?.score;
    final bitrate = dto.health?.media?.bitrate;
    final height = dto.health?.media?.height;
    final quality = dto.quality ?? dto.health?.media?.resolution;

    return FreeTvStream(
      url: dto.url.trim(),
      quality: quality,
      label: dto.title ?? dto.feed,
      isOnline: isOnline,
      healthScore: healthScore,
      bitrate: bitrate,
      height: height,
      referrer: dto.referrer,
      userAgent: dto.userAgent,
    );
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    if (s.length == 1) return s.toUpperCase();
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }
}
