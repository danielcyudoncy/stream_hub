import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/media_item.dart';

class Series extends MediaItem {
  final int? startYear;
  final int? endYear;
  final int? seasons;
  final List<String> episodeIds;

  const Series({
    required super.id,
    required super.providerId,
    required super.providerType,
    required super.title,
    required super.mediaType,
    super.subtitle,
    super.description,
    super.poster,
    super.backdrop,
    super.thumbnail,
    super.genres,
    super.language,
    super.country,
    super.rating,
    super.favorite,
    super.hidden,
    super.metadata,
    required super.createdAt,
    required super.updatedAt,
    this.startYear,
    this.endYear,
    this.seasons,
    this.episodeIds = const [],
  });

  @override
  Series copyWith({
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
    int? startYear,
    int? endYear,
    int? seasons,
    List<String>? episodeIds,
  }) {
    return Series(
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
      startYear: startYear ?? this.startYear,
      endYear: endYear ?? this.endYear,
      seasons: seasons ?? this.seasons,
      episodeIds: episodeIds ?? this.episodeIds,
    );
  }

  String? get formattedYearRange {
    if (startYear != null && endYear != null) {
      return startYear == endYear ? '$startYear' : '$startYear–$endYear';
    }
    if (startYear != null) return '$startYear';
    return releaseYear != null ? '$releaseYear' : null;
  }


  String get formattedSeasons {
    final count = seasons ?? int.tryParse(metadata['seasonsCount']?.toString() ?? '') ?? 1;
    return '$count ${count == 1 ? 'Season' : 'Seasons'}';
  }
}
