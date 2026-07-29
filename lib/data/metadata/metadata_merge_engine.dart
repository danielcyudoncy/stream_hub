import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/canonical_media_item.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/metadata_models.dart';

enum ConflictResolutionStrategy {
  highestQuality,
  newestMetadata,
  preferredProvider,
  manualPriority,
  firstAvailable;

  String get displayName {
    switch (this) {
      case ConflictResolutionStrategy.highestQuality:
        return 'Highest Quality';
      case ConflictResolutionStrategy.newestMetadata:
        return 'Newest Metadata';
      case ConflictResolutionStrategy.preferredProvider:
        return 'Preferred Provider';
      case ConflictResolutionStrategy.manualPriority:
        return 'Manual Priority';
      case ConflictResolutionStrategy.firstAvailable:
        return 'First Available';
    }
  }
}

class MetadataMergeEngine {
  final LoggingService logger;
  final ConflictResolutionStrategy defaultStrategy;

  MetadataMergeEngine({required this.logger, this.defaultStrategy = ConflictResolutionStrategy.newestMetadata});

  List<CanonicalMediaItem> mergeDuplicates(List<MediaItem> items) {
    if (items.isEmpty) {
      return [];
    }

    final grouped = <String, List<MediaItem>>{};
    for (final item in items) {
      final key = item.title.toLowerCase().trim();
      grouped.putIfAbsent(key, () => []).add(item);
    }

    final result = <CanonicalMediaItem>[];
    for (final entry in grouped.values) {
      if (entry.length == 1) {
        result.add(CanonicalMediaItem.fromMediaItem(entry.first));
      } else {
        final canonical = _mergeGroup(entry);
        result.add(canonical);
      }
    }

    return result;
  }

  CanonicalMediaItem _mergeGroup(List<MediaItem> items) {
    final canonical = CanonicalMediaItem.fromMediaItem(items.first);
    final others = items.sublist(1);

    for (final item in others) {
      _mergeItem(canonical, item);
    }

    return canonical;
  }

  void _mergeItem(CanonicalMediaItem base, MediaItem incoming) {
    final strategy = defaultStrategy;

    final mergedOwnership = Map<String, String>.from(base.providerOwnership);
    mergedOwnership[incoming.providerType.name] = incoming.providerId;

    final mergedSources = Set<String>.from(base.metadataSources)
      ..add(MetadataSourceType.provider.name);

    final title = _resolveConflict(
      base.title,
      incoming.title,
      strategy,
    );

    final description = _resolveConflict(
      base.description ?? '',
      incoming.description ?? '',
      strategy,
    );

    final poster = _resolveArtwork(base.poster, incoming.poster, strategy);
    final backdrop = _resolveArtwork(base.backdrop, incoming.backdrop, strategy);
    final thumbnail = _resolveArtwork(base.thumbnail, incoming.thumbnail, strategy);

    final mergedGenres = _mergeLists(base.genres, incoming.genres);
    final mergedCast = _mergeLists(base.cast, incoming.metadata['cast'] is List ? List<String>.from(incoming.metadata['cast'] as List) : const []);
    final mergedCrew = _mergeLists(base.crew, incoming.metadata['crew'] is List ? List<String>.from(incoming.metadata['crew'] as List) : const []);

    double? rating = base.rating;
    if (rating == null || strategy == ConflictResolutionStrategy.highestQuality) {
      rating = incoming.rating ?? rating;
    }

    final mergedExtra = Map<String, dynamic>.from(base.extra);
    mergedExtra.addAll(incoming.metadata);

    base.copyWith(
      title: title,
      description: description.isEmpty ? base.description : description,
      poster: poster,
      backdrop: backdrop,
      thumbnail: thumbnail,
      genres: mergedGenres,
      cast: mergedCast,
      crew: mergedCrew,
      rating: rating,
      providerOwnership: mergedOwnership,
      metadataSources: mergedSources,
      extra: mergedExtra,
      updatedAt: DateTime.now(),
    );
  }

  String _resolveConflict(String a, String b, ConflictResolutionStrategy strategy) {
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;

    switch (strategy) {
      case ConflictResolutionStrategy.newestMetadata:
        return b;
      case ConflictResolutionStrategy.firstAvailable:
        return a;
      default:
        return b.isNotEmpty ? b : a;
    }
  }

  String? _resolveArtwork(String? a, String? b, ConflictResolutionStrategy strategy) {
    if (a == null || a.isEmpty) return b;
    if (b == null || b.isEmpty) return a;

    switch (strategy) {
      case ConflictResolutionStrategy.highestQuality:
        return b;
      default:
        return b;
    }
  }

  List<String> _mergeLists(List<String> a, List<String> b) {
    final result = <String>{...a, ...b};
    return result.toList();
  }
}