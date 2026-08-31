import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/media_item.dart';

/// Curated catalog tier assigned to a free channel by the quality layer.
enum FreeTvQualityTier {
  /// Highest-quality, broadly useful channels (News, Sports, entertainment,
  /// kids, documentaries, etc.) surfaced on the curated home.
  recommended,

  /// Valid channels that are not as broadly useful but pass eligibility.
  valid;

  static FreeTvQualityTier fromName(String? name) {
    return FreeTvQualityTier.values.firstWhere(
      (t) => t.name == name,
      orElse: () => FreeTvQualityTier.valid,
    );
  }
}

/// Represents a public free-to-air live TV channel built from the IPTV-org
/// catalog (M3U playlists).
class FreeTvChannel {
  final String id;
  final String name;
  final String? nativeName;
  final String? network;
  final String country;
  final String countryCode;
  final String? region;
  final String? subdivision;
  final String? city;
  final List<String> broadcastArea;
  final List<String> languages;
  final List<String> categories;
  final bool isNsfw;
  final String? website;
  final String? logo;
  final List<String> streamUrls;
  final bool isFavorite;
  final DateTime? lastWatched;

  /// Reachability state determined by a live stream probe.
  ///
  /// Tri-state:
  ///   - `true`  : at least one stream URL was reachable on the last probe.
  ///   - `false` : all stream URLs were unreachable on the last probe.
  ///   - `null`  : not yet probed (default).
  final bool? isWorking;

  /// Internal catalog-quality heuristic score (0–100). Not an official
  /// popularity metric.
  final int qualityScore;

  /// Curated tier assigned by the quality layer.
  final FreeTvQualityTier qualityTier;

  const FreeTvChannel({
    required this.id,
    required this.name,
    this.nativeName,
    this.network,
    required this.country,
    required this.countryCode,
    this.region,
    this.subdivision,
    this.city,
    this.broadcastArea = const [],
    this.languages = const [],
    this.categories = const [],
    this.isNsfw = false,
    this.website,
    this.logo,
    this.streamUrls = const [],
    this.isFavorite = false,
    this.lastWatched,
    this.isWorking,
    this.qualityScore = 0,
    this.qualityTier = FreeTvQualityTier.valid,
  });

  /// Primary stream URL to play first.
  String? get primaryStreamUrl =>
      streamUrls.isNotEmpty ? streamUrls.first : null;

  /// Returns true if this channel has at least one valid stream URL.
  bool get hasStream => streamUrls.isNotEmpty;

  FreeTvChannel copyWith({
    String? id,
    String? name,
    String? nativeName,
    String? network,
    String? country,
    String? countryCode,
    String? region,
    String? subdivision,
    String? city,
    List<String>? broadcastArea,
    List<String>? languages,
    List<String>? categories,
    bool? isNsfw,
    String? website,
    String? logo,
    List<String>? streamUrls,
    bool? isFavorite,
    DateTime? lastWatched,
    bool? isWorking,
    int? qualityScore,
    FreeTvQualityTier? qualityTier,
  }) {
    return FreeTvChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      nativeName: nativeName ?? this.nativeName,
      network: network ?? this.network,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      region: region ?? this.region,
      subdivision: subdivision ?? this.subdivision,
      city: city ?? this.city,
      broadcastArea: broadcastArea ?? this.broadcastArea,
      languages: languages ?? this.languages,
      categories: categories ?? this.categories,
      isNsfw: isNsfw ?? this.isNsfw,
      website: website ?? this.website,
      logo: logo ?? this.logo,
      streamUrls: streamUrls ?? this.streamUrls,
      isFavorite: isFavorite ?? this.isFavorite,
      lastWatched: lastWatched ?? this.lastWatched,
      isWorking: isWorking ?? this.isWorking,
      qualityScore: qualityScore ?? this.qualityScore,
      qualityTier: qualityTier ?? this.qualityTier,
    );
  }

  /// Converts this channel into a canonical [MediaItem] consumable by
  /// PlaybackEngine and PlayerController.
  MediaItem toMediaItem() {
    final now = DateTime.now();
    return MediaItem(
      id: 'free_tv_$id',
      providerId: 'free_live_tv',
      providerType: MediaSourceType.custom,
      mediaType: MediaType.channel,
      title: name,
      subtitle: country.isNotEmpty ? country : null,
      description: network != null && network!.isNotEmpty
          ? 'Network: $network'
          : null,
      poster: logo,
      backdrop: logo,
      thumbnail: logo,
      genres: categories,
      language: languages.isNotEmpty ? languages.first : null,
      country: country,
      favorite: isFavorite,
      metadata: {
        'channelId': id,
        'countryCode': countryCode,
        'region': region ?? '',
        'streamUrl': primaryStreamUrl ?? '',
        'streamUrls': streamUrls,
        'isFreeTv': true,
        'languages': languages,
        'categories': categories,
        'website': website ?? '',
        'city': city ?? '',
      },
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (nativeName != null) 'native_name': nativeName,
      if (network != null) 'network': network,
      'country': country,
      'country_code': countryCode,
      if (region != null) 'region': region,
      if (subdivision != null) 'subdivision': subdivision,
      if (city != null) 'city': city,
      'broadcast_area': broadcastArea,
      'languages': languages,
      'categories': categories,
      'is_nsfw': isNsfw,
      if (website != null) 'website': website,
      if (logo != null) 'logo': logo,
      'stream_urls': streamUrls,
      'is_favorite': isFavorite,
      'is_working': isWorking,
      'quality_score': qualityScore,
      'quality_tier': qualityTier.name,
      if (lastWatched != null)
        'last_watched': lastWatched!.toIso8601String(),
    };
  }

  factory FreeTvChannel.fromJson(
    Map<String, dynamic> json, {
    List<String>? streamUrls,
    String? countryName,
    bool? isFavorite,
  }) {
    final rawLanguages = json['languages'];
    final List<String> langs = rawLanguages is List
        ? rawLanguages.map((e) => e.toString()).toList()
        : (rawLanguages is String && rawLanguages.isNotEmpty
            ? [rawLanguages]
            : const []);

    final rawCategories = json['categories'];
    final List<String> cats = rawCategories is List
        ? rawCategories.map((e) => e.toString()).toList()
        : (rawCategories is String && rawCategories.isNotEmpty
            ? [rawCategories]
            : const []);

    final rawBroadcastArea = json['broadcast_area'];
    final List<String> broadcastArea = rawBroadcastArea is List
        ? rawBroadcastArea.map((e) => e.toString()).toList()
        : const [];

    final rawStreams = streamUrls ??
        (json['stream_urls'] is List
            ? (json['stream_urls'] as List).map((e) => e.toString()).toList()
            : (json['stream_url'] != null
                ? [json['stream_url'].toString()]
                : const <String>[]));

    final rawCountry = json['country']?.toString();
    final rawCountryCode = json['country_code']?.toString();
    final countryCode = (rawCountryCode ??
            (rawCountry != null && rawCountry.length <= 3 ? rawCountry : ''))
        .toUpperCase();
    final resolvedCountry = countryName ??
        (json['country_name'] ??
                (rawCountry != null && rawCountry.length > 3
                    ? rawCountry
                    : null) ??
                countryCode)
            .toString();

    DateTime? lastWatched;
    if (json['last_watched'] != null) {
      lastWatched = DateTime.tryParse(json['last_watched'].toString());
    }

    final region = json['region']?.toString();
    final qualityScore = (json['quality_score'] is num)
        ? (json['quality_score'] as num).toInt()
        : 0;
    final qualityTier = FreeTvQualityTier.fromName(
      json['quality_tier']?.toString(),
    );

    return FreeTvChannel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nativeName: json['native_name']?.toString(),
      network: json['network']?.toString(),
      country: resolvedCountry,
      countryCode: countryCode,
      region: region,
      subdivision: json['subdivision']?.toString(),
      city: json['city']?.toString(),
      broadcastArea: broadcastArea,
      languages: langs,
      categories: cats,
      isNsfw: json['is_nsfw'] == true || json['is_nsfw'] == 1,
      website: json['website']?.toString(),
      logo: json['logo']?.toString(),
      streamUrls: rawStreams
          .where((s) => s.trim().isNotEmpty && s.startsWith('http'))
          .toList(),
      isFavorite: isFavorite ?? json['is_favorite'] == true,
      lastWatched: lastWatched,
      isWorking: json['is_working'] is bool
          ? json['is_working'] as bool
          : null,
      qualityScore: qualityScore,
      qualityTier: qualityTier,
    );
  }
}
