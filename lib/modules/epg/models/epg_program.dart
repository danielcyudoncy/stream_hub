import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/media_item.dart';

class EPGProgram extends MediaItem {
  final String? channelId;
  final DateTime startTime;
  final DateTime endTime;
  final List<String>? categories;
  final String? episodeNum;
  final String? season;
  final String? episodeTitle;
  final List<String>? cast;
  final List<String>? directors;
  final bool isLive;
  final bool isNew;
  final bool isPremiere;
  final bool isPreviouslyShown;
  final String? videoQuality;
  final String? audioCodec;
  final List<String>? subtitleLanguages;

  const EPGProgram({
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
    this.channelId,
    required this.startTime,
    required this.endTime,
    this.categories,
    this.episodeNum,
    this.season,
    this.episodeTitle,
    this.cast,
    this.directors,
    this.isLive = false,
    this.isNew = false,
    this.isPremiere = false,
    this.isPreviouslyShown = false,
    this.videoQuality,
    this.audioCodec,
    this.subtitleLanguages,
  });

  @override
  EPGProgram copyWith({
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
    String? channelId,
    DateTime? startTime,
    DateTime? endTime,
    List<String>? categories,
    String? episodeNum,
    String? season,
    String? episodeTitle,
    List<String>? cast,
    List<String>? directors,
    bool? isLive,
    bool? isNew,
    bool? isPremiere,
    bool? isPreviouslyShown,
    String? videoQuality,
    String? audioCodec,
    List<String>? subtitleLanguages,
  }) {
    return EPGProgram(
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
      channelId: channelId ?? this.channelId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      categories: categories ?? this.categories,
      episodeNum: episodeNum ?? this.episodeNum,
      season: season ?? this.season,
      episodeTitle: episodeTitle ?? this.episodeTitle,
cast: cast ?? this.cast,
      directors: directors ?? this.directors,
      isLive: isLive ?? this.isLive,
      isNew: isNew ?? this.isNew,
      isPremiere: isPremiere ?? this.isPremiere,
      isPreviouslyShown: isPreviouslyShown ?? this.isPreviouslyShown,
      videoQuality: videoQuality ?? this.videoQuality,
      audioCodec: audioCodec ?? this.audioCodec,
      subtitleLanguages: subtitleLanguages ?? this.subtitleLanguages,
    );
  }

  Duration get duration => endTime.difference(startTime);

  bool get isCurrentlyPlaying {
    final now = DateTime.now();
    return !now.isBefore(startTime) && now.isBefore(endTime);
  }

  bool get hasEnded => DateTime.now().isAfter(endTime);

  Duration get remainingTime {
    if (isCurrentlyPlaying) {
      return endTime.difference(DateTime.now());
    }
    return Duration.zero;
  }

  double get progressPercent {
    if (!isCurrentlyPlaying) return 0.0;
    final now = DateTime.now();
    final totalDuration = endTime.difference(startTime).inMilliseconds;
    if (totalDuration <= 0) return 0.0;
    final elapsed = now.difference(startTime).inMilliseconds;
    return (elapsed / totalDuration).clamp(0.0, 1.0);
  }
}