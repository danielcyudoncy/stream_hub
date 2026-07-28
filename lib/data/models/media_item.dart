import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';

class MediaItem {
  final String id;
  final String providerId;
  final MediaSourceType providerType;
  final MediaType mediaType;
  final String title;
  final String? subtitle;
  final String? description;
  final String? poster;
  final String? backdrop;
  final String? thumbnail;
  final List<String> genres;
  final String? language;
  final String? country;
  final double? rating;
  final bool favorite;
  final bool hidden;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MediaItem({
    required this.id,
    required this.providerId,
    required this.providerType,
    required this.mediaType,
    required this.title,
    this.subtitle,
    this.description,
    this.poster,
    this.backdrop,
    this.thumbnail,
    this.genres = const [],
    this.language,
    this.country,
    this.rating,
    this.favorite = false,
    this.hidden = false,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  MediaItem copyWith({
    String? id,
    String? providerId,
    MediaSourceType? providerType,
    MediaType? mediaType,
    String? title,
    String? subtitle,
    String? description,
    String? poster,
    String? backdrop,
    String? thumbnail,
    List<String>? genres,
    String? language,
    String? country,
    double? rating,
    bool? favorite,
    bool? hidden,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaItem(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      providerType: providerType ?? this.providerType,
      mediaType: mediaType ?? this.mediaType,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      poster: poster ?? this.poster,
      backdrop: backdrop ?? this.backdrop,
      thumbnail: thumbnail ?? this.thumbnail,
      genres: genres ?? this.genres,
      language: language ?? this.language,
      country: country ?? this.country,
      rating: rating ?? this.rating,
      favorite: favorite ?? this.favorite,
      hidden: hidden ?? this.hidden,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
