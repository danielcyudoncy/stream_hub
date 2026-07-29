import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/canonical_media_item.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/metadata_models.dart';
import 'package:stream_hub/data/providers/metadata/metadata_provider.dart';

class MetadataEngine {
  final LoggingService logger;
  final List<MetadataProvider> providers;

  MetadataEngine({LoggingService? logger, List<MetadataProvider>? providers})
      : logger = logger ?? LoggingService(),
        providers = providers ?? [];

  Future<CanonicalMediaItem> enrich(MediaItem item) async {
    CanonicalMediaItem canonical = CanonicalMediaItem.fromMediaItem(item);

    for (final provider in providers) {
      if (!provider.isEnabled) continue;

      try {
        final enriched = await provider.enrich(item);
        canonical = _mergeProviderResult(canonical, enriched, provider.sourceType);
      } catch (e) {
        logger.warning(
          'Metadata provider ${provider.sourceType.displayName} failed for item ${item.id}',
          tag: 'MetadataEngine',
          error: e,
        );
      }
    }

    return canonical;
  }

  Future<List<CanonicalMediaItem>> enrichAll(List<MediaItem> items) async {
    final result = <CanonicalMediaItem>[];
    for (final item in items) {
      result.add(await enrich(item));
    }
    return result;
  }

  CanonicalMediaItem _mergeProviderResult(
    CanonicalMediaItem base,
    MediaItem incoming,
    MetadataSourceType sourceType,
  ) {
    final updatedSources = Set<String>.from(base.metadataSources)..add(sourceType.name);
    final updatedOwnership = Map<String, String>.from(base.providerOwnership);
    if (incoming.providerId.isNotEmpty) {
      updatedOwnership[incoming.providerType.name] = incoming.providerId;
    }

    final artworkSources = Set<String>.from(base.artworkSources);
    if (incoming.poster != null && incoming.poster!.isNotEmpty) {
      artworkSources.add('${sourceType.name}_poster');
    }
    if (incoming.backdrop != null && incoming.backdrop!.isNotEmpty) {
      artworkSources.add('${sourceType.name}_backdrop');
    }

    return base.copyWith(
      title: base.title.isEmpty ? incoming.title : base.title,
      originalTitle: base.originalTitle ?? incoming.metadata['originalTitle']?.toString(),
      description: base.description ?? incoming.description,
      tagline: base.tagline ?? incoming.subtitle,
      poster: base.poster ?? incoming.poster,
      backdrop: base.backdrop ?? incoming.backdrop,
      thumbnail: base.thumbnail ?? incoming.thumbnail,
      genres: _mergeLists(base.genres, incoming.genres),
      language: base.language ?? incoming.language,
      country: base.country ?? incoming.country,
      rating: base.rating ?? incoming.rating,
      cast: _mergeLists(base.cast, incoming.metadata['cast'] is List ? List<String>.from(incoming.metadata['cast'] as List) : const []),
      crew: _mergeLists(base.crew, incoming.metadata['crew'] is List ? List<String>.from(incoming.metadata['crew'] as List) : const []),
      studio: base.studio ?? incoming.metadata['studio']?.toString(),
      providerOwnership: updatedOwnership,
      metadataSources: updatedSources,
      artworkSources: artworkSources,
      updatedAt: DateTime.now(),
    );
  }

  List<String> _mergeLists(List<String> a, List<String> b) {
    final result = <String>{...a, ...b};
    return result.toList();
  }
}