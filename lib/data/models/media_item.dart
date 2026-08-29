import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/utils/image_url_formatter.dart';
import 'package:stream_hub/data/models/cast_member.dart';

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

extension MediaItemVodExtensions on MediaItem {
  /// Resolves the release year from metadata or fields
  int? get releaseYear {
    final yearRaw = metadata['year'] ??
        metadata['release_year'] ??
        metadata['releaseYear'];
    if (yearRaw is int) return yearRaw;
    if (yearRaw is String) {
      final parsed = int.tryParse(yearRaw);
      if (parsed != null && parsed > 1800 && parsed < 2200) return parsed;
    }

    final releaseDateRaw = metadata['releaseDate'] ??
        metadata['release_date'] ??
        metadata['releasedate'] ??
        metadata['date'];
    if (releaseDateRaw != null) {
      final dt = DateTime.tryParse(releaseDateRaw.toString());
      if (dt != null) return dt.year;
    }
    return null;
  }

  /// Resolves the duration in minutes
  int? get durationMinutes {
    final runtime = metadata['runtime'] ??
        metadata['duration'] ??
        metadata['duration_minutes'] ??
        metadata['runtimeMinutes'];
    if (runtime is int && runtime > 0) return runtime;
    if (runtime is String) {
      final parsed = int.tryParse(runtime);
      if (parsed != null && parsed > 0) return parsed;
    }

    final secs = metadata['duration_secs'] ??
        metadata['duration_seconds'] ??
        metadata['stream_duration'];
    if (secs is int && secs > 0) return (secs / 60).round();
    if (secs is String) {
      final parsed = int.tryParse(secs);
      if (parsed != null && parsed > 0) return (parsed / 60).round();
    }
    return null;
  }

  /// Formatted duration string, e.g. "2h 15m" or "45m"
  String? get formattedDuration {
    final mins = durationMinutes;
    if (mins == null || mins <= 0) return null;
    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    if (hours > 0 && remainingMins > 0) {
      return '${hours}h ${remainingMins}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${remainingMins}m';
    }
  }

  /// Resolves director name(s)
  String? get director {
    final d = metadata['director'] ??
        metadata['directors'] ??
        metadata['director_name'] ??
        metadata['directed_by'] ??
        metadata['writer'];
    if (d is String && d.trim().isNotEmpty) return d.trim();
    if (d is List && d.isNotEmpty) {
      return d.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join(', ');
    }
    final crew = metadata['crew'];
    if (crew is List && crew.isNotEmpty) {
      for (final member in crew) {
        if (member is Map && (member['job'] == 'Director' || member['role'] == 'Director')) {
          final name = member['name']?.toString();
          if (name != null && name.isNotEmpty) return name;
        }
      }
    }
    return null;
  }

  /// Resolves list of CastMember items
  List<CastMember> get castMembers {
    final rawCast = metadata['cast'] ??
        metadata['actors'] ??
        metadata['cast_members'] ??
        metadata['stars'] ??
        metadata['starring'] ??
        metadata['actor'] ??
        metadata['credits'];
    if (rawCast is List && rawCast.isNotEmpty) {
      final members = <CastMember>[];
      for (final item in rawCast) {
        if (item is Map) {
          members.add(CastMember.fromMap(item));
        } else if (item is String && item.trim().isNotEmpty) {
          members.add(CastMember.fromString(item));
        }
      }
      return members;
    }
    if (rawCast is String && rawCast.trim().isNotEmpty) {
      return rawCast
          .split(RegExp(r'[,;/]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((s) => CastMember.fromString(s))
          .toList();
    }
    return const [];
  }

  /// Original title if different from title
  String? get originalTitle {
    final ot = metadata['originalTitle'] ?? metadata['original_title'];
    if (ot is String && ot.trim().isNotEmpty && ot != title) {
      return ot.trim();
    }
    return null;
  }

  /// Trailer or YouTube link
  String? get trailerUrl {
    final t = metadata['trailer'] ??
        metadata['youtube_trailer'] ??
        metadata['trailer_url'];
    if (t is String && t.trim().isNotEmpty) return t.trim();
    final trailers = metadata['trailers'];
    if (trailers is List && trailers.isNotEmpty) {
      return trailers.first.toString();
    }
    return null;
  }

  /// Formatted rating string, e.g. "8.4"
  String? get formattedRating {
    if (rating != null && rating! > 0) {
      return rating!.toStringAsFixed(1);
    }
    final rawRating = metadata['rating_5based'] ??
        metadata['rating'] ??
        metadata['rating_imdb'] ??
        metadata['rating_kinopoisk'] ??
        metadata['vote_average'] ??
        metadata['rate'];
    if (rawRating is num && rawRating > 0) {
      return rawRating.toDouble().toStringAsFixed(1);
    }
    if (rawRating is String && rawRating.isNotEmpty) {
      final cleaned = rawRating.replaceAll(RegExp(r'[^0-9.]'), '');
      final parsed = double.tryParse(cleaned);
      if (parsed != null && parsed > 0 && parsed <= 10) return parsed.toStringAsFixed(1);
    }
    return null;
  }

  /// Country of origin
  String? get resolvedCountry {
    if (country != null && country!.trim().isNotEmpty) return country!.trim();
    final c = metadata['country'] ??
        metadata['production_countries'] ??
        metadata['country_name'];
    if (c is String && c.trim().isNotEmpty) return c.trim();
    if (c is List && c.isNotEmpty) {
      final first = c.first;
      if (first is Map && first['name'] != null) {
        return first['name'].toString();
      }
      return first.toString();
    }
    return null;
  }

  /// Audio or spoken language
  String? get resolvedLanguage {
    if (language != null && language!.trim().isNotEmpty) return language!.trim();
    final l = metadata['language'] ??
        metadata['spoken_languages'] ??
        metadata['lang'];
    if (l is String && l.trim().isNotEmpty) return l.trim();
    if (l is List && l.isNotEmpty) {
      final first = l.first;
      if (first is Map && first['name'] != null) {
        return first['name'].toString();
      }
      return first.toString();
    }
    return null;
  }

  /// Formatted and fully resolved poster/cover URL from direct properties or metadata
  String? get resolvedPosterUrl {
    return ImageUrlFormatter.extractFromMediaItem(this);
  }

  /// Formatted and fully resolved backdrop/banner URL from direct properties or metadata
  String? get resolvedBackdropUrl {
    final formattedBackdrop = ImageUrlFormatter.format(backdrop, item: this);
    if (formattedBackdrop != null && formattedBackdrop.isNotEmpty) {
      return formattedBackdrop;
    }
    final bg = metadata['backdrop_path'] ??
        metadata['backdropPath'] ??
        metadata['backdrop'] ??
        metadata['cover_big'] ??
        metadata['movie_image'];
    final formattedBg = ImageUrlFormatter.format(bg, item: this);
    if (formattedBg != null && formattedBg.isNotEmpty) {
      return formattedBg;
    }
    return resolvedPosterUrl;
  }

  /// Whether video is 4K / UHD
  bool get is4k {
    final titleUpper = title.toUpperCase();
    final quality = metadata['quality']?.toString().toUpperCase() ?? '';
    return titleUpper.contains('4K') ||
        titleUpper.contains('UHD') ||
        quality.contains('4K') ||
        quality.contains('UHD');
  }

  /// Whether video is HD
  bool get isHd {
    if (is4k) return true;
    final titleUpper = title.toUpperCase();
    final quality = metadata['quality']?.toString().toUpperCase() ?? '';
    return titleUpper.contains('HD') ||
        titleUpper.contains('1080') ||
        titleUpper.contains('720') ||
        quality.contains('HD') ||
        quality.contains('1080');
  }
}

