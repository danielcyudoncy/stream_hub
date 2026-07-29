import 'package:stream_hub/core/logging/logging_service.dart';

class ArtworkService {
  final LoggingService logger;

  ArtworkService({LoggingService? logger}) : logger = logger ?? LoggingService();

  String? selectPoster(List<String?> candidates) {
    if (candidates.isEmpty) return null;
    final nonNull = candidates.whereType<String>().toList();
    if (nonNull.isEmpty) return null;
    return nonNull.first;
  }

  String? selectBackdrop(List<String?> candidates) {
    if (candidates.isEmpty) return null;
    final nonNull = candidates.whereType<String>().toList();
    if (nonNull.isEmpty) return null;
    return nonNull.first;
  }

  String? selectThumbnail(List<String?> candidates) {
    if (candidates.isEmpty) return null;
    final nonNull = candidates.whereType<String>().toList();
    if (nonNull.isEmpty) return null;
    return nonNull.first;
  }

  String? selectLogo(List<String?> candidates) {
    if (candidates.isEmpty) return null;
    final nonNull = candidates.whereType<String>().toList();
    if (nonNull.isEmpty) return null;
    return nonNull.first;
  }

  String? getFallbackImage(String? primary, List<String?> fallbacks) {
    if (primary != null && primary.isNotEmpty) return primary;
    for (final fallback in fallbacks) {
      if (fallback != null && fallback.isNotEmpty) return fallback;
    }
    return null;
  }

  Future<void> cacheArtwork(String url) async {
    logger.info('Caching artwork: $url', tag: 'ArtworkService');
  }

  Future<void> preloadArtwork(List<String> urls) async {
    for (final url in urls) {
      await cacheArtwork(url);
    }
  }
}