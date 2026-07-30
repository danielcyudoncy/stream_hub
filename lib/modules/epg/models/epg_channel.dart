import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/media_item.dart';

class EPGChannel extends MediaItem {
  final String? number;
  final String? streamUrl;
  final bool isLive;
  final String? currentProgramId;
  final String? logoUrl;
  final String? providerBadge;
  final bool isFavorite;

  const EPGChannel({
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
    this.number,
    this.streamUrl,
    this.isLive = true,
    this.currentProgramId,
    this.logoUrl,
    this.providerBadge,
    this.isFavorite = false,
  });

  @override
  EPGChannel copyWith({
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
    String? number,
    String? streamUrl,
    bool? isLive,
    String? currentProgramId,
    String? logoUrl,
    String? providerBadge,
    bool? isFavorite,
  }) {
    return EPGChannel(
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
      number: number ?? this.number,
      streamUrl: streamUrl ?? this.streamUrl,
      isLive: isLive ?? this.isLive,
      currentProgramId: currentProgramId ?? this.currentProgramId,
      logoUrl: logoUrl ?? this.logoUrl,
      providerBadge: providerBadge ?? this.providerBadge,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}