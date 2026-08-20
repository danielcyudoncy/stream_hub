import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/data/models/media_item.dart';

/// Represents a season belonging to a series.
class Season {
  final String id;
  final String seriesId;
  final String providerId;
  final MediaSourceType providerType;
  final int seasonNumber;
  final String title;
  final String? description;
  final String? poster;
  final int episodeCount;
  final DateTime? airDate;
  final List<MediaItem> episodes;

  const Season({
    required this.id,
    required this.seriesId,
    required this.providerId,
    this.providerType = MediaSourceType.xtream,
    required this.seasonNumber,
    required this.title,
    this.description,
    this.poster,
    this.episodeCount = 0,
    this.airDate,
    this.episodes = const [],
  });

  Season copyWith({
    String? id,
    String? seriesId,
    String? providerId,
    MediaSourceType? providerType,
    int? seasonNumber,
    String? title,
    String? description,
    String? poster,
    int? episodeCount,
    DateTime? airDate,
    List<MediaItem>? episodes,
  }) {
    return Season(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      providerId: providerId ?? this.providerId,
      providerType: providerType ?? this.providerType,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      poster: poster ?? this.poster,
      episodeCount: episodeCount ?? this.episodeCount,
      airDate: airDate ?? this.airDate,
      episodes: episodes ?? this.episodes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'seriesId': seriesId,
      'providerId': providerId,
      'providerType': providerType.name,
      'seasonNumber': seasonNumber,
      'title': title,
      if (description != null) 'description': description,
      if (poster != null) 'poster': poster,
      'episodeCount': episodeCount,
      if (airDate != null) 'airDate': airDate!.toIso8601String(),
    };
  }

  factory Season.fromMap(Map<String, dynamic> map, {List<MediaItem> episodes = const []}) {
    return Season(
      id: map['id']?.toString() ?? '',
      seriesId: map['seriesId']?.toString() ?? '',
      providerId: map['providerId']?.toString() ?? '',
      providerType: MediaSourceType.values.firstWhere(
        (t) => t.name == map['providerType'],
        orElse: () => MediaSourceType.xtream,
      ),
      seasonNumber: int.tryParse(map['seasonNumber']?.toString() ?? '0') ?? 0,
      title: map['title']?.toString() ?? 'Season ${map['seasonNumber'] ?? ''}',
      description: map['description']?.toString(),
      poster: map['poster']?.toString(),
      episodeCount: int.tryParse(map['episodeCount']?.toString() ?? '0') ?? episodes.length,
      airDate: map['airDate'] != null ? DateTime.tryParse(map['airDate'].toString()) : null,
      episodes: episodes,
    );
  }
}
