import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/media_item.dart';

class CanonicalMediaItem {
  final String id;
  final String canonicalId;
  final String title;
  final String? originalTitle;
  final String? sortTitle;
  final String? description;
  final String? tagline;
  final String? poster;
  final String? backdrop;
  final String? logo;
  final String? thumbnail;
  final List<String> genres;
  final String? language;
  final String? country;
  final double? rating;
  final int? runtime;
  final DateTime? releaseDate;
  final List<String> cast;
  final List<String> crew;
  final String? studio;
  final MediaType mediaType;
  final Map<String, String> providerOwnership;
  final Set<String> metadataSources;
  final Set<String> artworkSources;
  final List<String> trailers;
  final List<String> links;
  final Map<String, dynamic> extra;
  /// The primary playable stream URL for this item.
  ///
  /// Preserved through the MediaItem → CanonicalMediaItem → MediaItem
  /// round-trip so that [StreamEngine._extractSourceUrl] can locate the
  /// stream without requiring a provider session (M3U channels, for example).
  final String? streamUrl;
  final bool favorite;
  final bool hidden;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CanonicalMediaItem({
    required this.id,
    required this.canonicalId,
    required this.title,
    this.originalTitle,
    this.sortTitle,
    this.description,
    this.tagline,
    this.poster,
    this.backdrop,
    this.logo,
    this.thumbnail,
    this.genres = const [],
    this.language,
    this.country,
    this.rating,
    this.runtime,
    this.releaseDate,
    this.cast = const [],
    this.crew = const [],
    this.studio,
    required this.mediaType,
    this.providerOwnership = const {},
    this.metadataSources = const {},
    this.artworkSources = const {},
    this.trailers = const [],
    this.links = const [],
    this.extra = const {},
    this.streamUrl,
    this.favorite = false,
    this.hidden = false,
    required this.createdAt,
    required this.updatedAt,
  });

  CanonicalMediaItem copyWith({
    String? id,
    String? canonicalId,
    String? title,
    String? originalTitle,
    String? sortTitle,
    String? description,
    String? tagline,
    String? poster,
    String? backdrop,
    String? logo,
    String? thumbnail,
    List<String>? genres,
    String? language,
    String? country,
    double? rating,
    int? runtime,
    DateTime? releaseDate,
    List<String>? cast,
    List<String>? crew,
    String? studio,
    MediaType? mediaType,
    Map<String, String>? providerOwnership,
    Set<String>? metadataSources,
    Set<String>? artworkSources,
    List<String>? trailers,
    List<String>? links,
    Map<String, dynamic>? extra,
    String? streamUrl,
    bool? favorite,
    bool? hidden,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CanonicalMediaItem(
      id: id ?? this.id,
      canonicalId: canonicalId ?? this.canonicalId,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      sortTitle: sortTitle ?? this.sortTitle,
      description: description ?? this.description,
      tagline: tagline ?? this.tagline,
      poster: poster ?? this.poster,
      backdrop: backdrop ?? this.backdrop,
      logo: logo ?? this.logo,
      thumbnail: thumbnail ?? this.thumbnail,
      genres: genres ?? this.genres,
      language: language ?? this.language,
      country: country ?? this.country,
      rating: rating ?? this.rating,
      runtime: runtime ?? this.runtime,
      releaseDate: releaseDate ?? this.releaseDate,
      cast: cast ?? this.cast,
      crew: crew ?? this.crew,
      studio: studio ?? this.studio,
      mediaType: mediaType ?? this.mediaType,
      providerOwnership: providerOwnership ?? this.providerOwnership,
      metadataSources: metadataSources ?? this.metadataSources,
      artworkSources: artworkSources ?? this.artworkSources,
      trailers: trailers ?? this.trailers,
      links: links ?? this.links,
      extra: extra ?? this.extra,
      streamUrl: streamUrl ?? this.streamUrl,
      favorite: favorite ?? this.favorite,
      hidden: hidden ?? this.hidden,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  MediaItem toMediaItem() {
    final primaryProviderType = providerOwnership.keys.isNotEmpty
        ? MediaSourceType.values.firstWhere(
            (e) => e.name == providerOwnership.keys.first,
            orElse: () => MediaSourceType.custom,
          )
        : MediaSourceType.custom;

    return MediaItem(
      id: id,
      providerId: providerOwnership.values.firstOrNull ?? 'unknown',
      providerType: primaryProviderType,
      mediaType: mediaType,
      title: title,
      subtitle: tagline,
      description: description,
      poster: poster,
      backdrop: backdrop,
      thumbnail: thumbnail,
      genres: genres,
      language: language,
      country: country,
      rating: rating,
      metadata: {
        'canonicalId': canonicalId,
        'originalTitle': originalTitle ?? '',
        'sortTitle': sortTitle ?? '',
        'runtime': runtime ?? 0,
        'releaseDate': releaseDate?.toIso8601String() ?? '',
        'cast': cast,
        'crew': crew,
        'studio': studio ?? '',
        'providerOwnership': Map<String, dynamic>.from(providerOwnership),
        'metadataSources': metadataSources.toList(),
        'artworkSources': artworkSources.toList(),
        'trailers': trailers,
        'links': links,
        // Surface the stream URL so StreamEngine._extractSourceUrl can locate
        // the source without requiring a provider session lookup.
        if (streamUrl != null && streamUrl!.isNotEmpty) 'streamUrl': streamUrl!,
        ...extra,
      },
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory CanonicalMediaItem.fromMediaItem(MediaItem item) {
    final metadata = item.metadata;
    final ownership = <String, String>{};
    if (metadata['providerOwnership'] is Map) {
      final map = metadata['providerOwnership'] as Map;
      for (final entry in map.entries) {
        ownership[entry.key.toString()] = entry.value.toString();
      }
    }
    if (item.providerId.isNotEmpty) {
      ownership[item.providerType.name] = item.providerId;
    }

    final sources = <String>{};
    if (metadata['metadataSources'] is List) {
      for (final s in metadata['metadataSources'] as List) {
        sources.add(s.toString());
      }
    }

    final artworkSources = <String>{};
    if (metadata['artworkSources'] is List) {
      for (final s in metadata['artworkSources'] as List) {
        artworkSources.add(s.toString());
      }
    }

    return CanonicalMediaItem(
      id: item.id,
      canonicalId: metadata['canonicalId']?.toString() ?? item.id,
      title: item.title,
      originalTitle: metadata['originalTitle']?.toString(),
      sortTitle: metadata['sortTitle']?.toString(),
      description: item.description,
      tagline: item.subtitle,
      poster: item.poster,
      backdrop: item.backdrop,
      logo: item.thumbnail,
      thumbnail: item.thumbnail,
      genres: item.genres,
      language: item.language,
      country: item.country,
      rating: item.rating,
      runtime: metadata['runtime'] is int ? (metadata['runtime'] as int) : null,
      releaseDate: metadata['releaseDate'] != null ? DateTime.tryParse(metadata['releaseDate'].toString()) : null,
      cast: metadata['cast'] is List ? List<String>.from(metadata['cast'] as List) : const [],
      crew: metadata['crew'] is List ? List<String>.from(metadata['crew'] as List) : const [],
      studio: metadata['studio']?.toString(),
      mediaType: item.mediaType,
      providerOwnership: ownership,
      metadataSources: sources,
      artworkSources: artworkSources,
      trailers: metadata['trailers'] is List ? List<String>.from(metadata['trailers'] as List) : const [],
      links: metadata['links'] is List ? List<String>.from(metadata['links'] as List) : const [],
      // Preserve the stream URL so it survives the round-trip back to MediaItem.
      streamUrl: metadata['streamUrl']?.toString(),
      extra: Map<String, dynamic>.from(metadata),
      favorite: item.favorite,
      hidden: item.hidden,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }
}