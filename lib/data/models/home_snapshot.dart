import '../models/media_item.dart';
import '../../core/media/enums/media_type.dart';
import '../../core/media/enums/media_source_type.dart';

class HomeSnapshot {
  final List<MediaItem> featuredHeroItems;
  final List<MediaItem> continueWatching;
  final List<MediaItem> liveChannels;
  final List<MediaItem> movies;
  final List<MediaItem> series;
  final List<MediaItem> favorites;
  final List<MediaItem> recentlyAdded;
  final List<MediaItem> recentlyPlayed;
  final int providerCount;
  final DateTime cachedAt;

  const HomeSnapshot({
    required this.featuredHeroItems,
    required this.continueWatching,
    required this.liveChannels,
    required this.movies,
    required this.series,
    required this.favorites,
    required this.recentlyAdded,
    required this.recentlyPlayed,
    required this.providerCount,
    required this.cachedAt,
  });

  bool get isEmpty =>
      featuredHeroItems.isEmpty &&
      liveChannels.isEmpty &&
      movies.isEmpty &&
      series.isEmpty;

  bool isStale({Duration maxAge = const Duration(hours: 1)}) {
    return DateTime.now().difference(cachedAt) > maxAge;
  }

  Map<String, dynamic> toJson() {
    return {
      'featuredHeroItems': featuredHeroItems.map(_mediaItemToJson).toList(),
      'continueWatching': continueWatching.map(_mediaItemToJson).toList(),
      'liveChannels': liveChannels.map(_mediaItemToJson).toList(),
      'movies': movies.map(_mediaItemToJson).toList(),
      'series': series.map(_mediaItemToJson).toList(),
      'favorites': favorites.map(_mediaItemToJson).toList(),
      'recentlyAdded': recentlyAdded.map(_mediaItemToJson).toList(),
      'recentlyPlayed': recentlyPlayed.map(_mediaItemToJson).toList(),
      'providerCount': providerCount,
      'cachedAt': cachedAt.toIso8601String(),
    };
  }

  factory HomeSnapshot.fromJson(Map<String, dynamic> json) {
    return HomeSnapshot(
      featuredHeroItems: _parseMediaItems(json['featuredHeroItems']),
      continueWatching: _parseMediaItems(json['continueWatching']),
      liveChannels: _parseMediaItems(json['liveChannels']),
      movies: _parseMediaItems(json['movies']),
      series: _parseMediaItems(json['series']),
      favorites: _parseMediaItems(json['favorites']),
      recentlyAdded: _parseMediaItems(json['recentlyAdded']),
      recentlyPlayed: _parseMediaItems(json['recentlyPlayed']),
      providerCount: json['providerCount'] as int? ?? 0,
      cachedAt: DateTime.tryParse(json['cachedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  static List<MediaItem> _parseMediaItems(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => _mediaItemFromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  static Map<String, dynamic> _mediaItemToJson(MediaItem item) {
    return {
      'id': item.id,
      'providerId': item.providerId,
      'providerType': item.providerType.name,
      'mediaType': item.mediaType.name,
      'title': item.title,
      'subtitle': item.subtitle,
      'description': item.description,
      'poster': item.poster,
      'backdrop': item.backdrop,
      'thumbnail': item.thumbnail,
      'genres': item.genres,
      'language': item.language,
      'country': item.country,
      'rating': item.rating,
      'favorite': item.favorite,
      'hidden': item.hidden,
      'metadata': item.metadata,
      'createdAt': item.createdAt.toIso8601String(),
      'updatedAt': item.updatedAt.toIso8601String(),
    };
  }

  static MediaItem _mediaItemFromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String? ?? '',
      providerId: json['providerId'] as String? ?? '',
      providerType: _parseMediaSourceType(json['providerType'] as String?),
      mediaType: _parseMediaType(json['mediaType'] as String?),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      poster: json['poster'] as String?,
      backdrop: json['backdrop'] as String?,
      thumbnail: json['thumbnail'] as String?,
      genres: (json['genres'] as List?)?.cast<String>() ?? const [],
      language: json['language'] as String?,
      country: json['country'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      favorite: json['favorite'] as bool? ?? false,
      hidden: json['hidden'] as bool? ?? false,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

MediaType _parseMediaType(String? value) {
  if (value == null) return MediaType.channel;
  for (final type in MediaType.values) {
    if (type.name == value) return type;
  }
  return MediaType.channel;
}

MediaSourceType _parseMediaSourceType(String? value) {
  if (value == null) return MediaSourceType.m3u;
  for (final type in MediaSourceType.values) {
    if (type.name == value) return type;
  }
  return MediaSourceType.m3u;
}
