import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/metadata_models.dart';
import 'package:stream_hub/data/providers/metadata/metadata_provider.dart';

class TMDBMetadataProvider implements MetadataProvider {
  @override
  final String id;
  @override
  final MetadataSourceType sourceType = MetadataSourceType.tmdb;
  @override
  bool isEnabled = true;

  final LoggingService logger;

  TMDBMetadataProvider({required this.id, LoggingService? logger})
      : logger = logger ?? LoggingService();

  @override
  Future<void> initialize() async {
    logger.info('TMDB metadata provider initialized: $id', tag: 'TMDBMetadataProvider');
  }

  @override
  Future<void> refresh() async {
    logger.info('TMDB metadata provider refreshed: $id', tag: 'TMDBMetadataProvider');
  }

  @override
  Future<MediaItem?> search(String query) async {
    logger.info('TMDB metadata search: $query', tag: 'TMDBMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem?> lookup(String externalId) async {
    logger.info('TMDB metadata lookup: $externalId', tag: 'TMDBMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem> enrich(MediaItem item) async {
    logger.info('TMDB metadata enrich: ${item.id}', tag: 'TMDBMetadataProvider');
    return item;
  }

  @override
  Future<bool> validate() async {
    logger.info('TMDB metadata provider validated', tag: 'TMDBMetadataProvider');
    return true;
  }

  @override
  Future<void> dispose() async {
    logger.info('TMDB metadata provider disposed: $id', tag: 'TMDBMetadataProvider');
  }
}