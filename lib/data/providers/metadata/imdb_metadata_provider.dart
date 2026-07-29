import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/metadata_models.dart';
import 'package:stream_hub/data/providers/metadata/metadata_provider.dart';

class IMDbMetadataProvider implements MetadataProvider {
  @override
  final String id;
  @override
  final MetadataSourceType sourceType = MetadataSourceType.imdb;
  @override
  bool isEnabled = true;

  final LoggingService logger;

  IMDbMetadataProvider({required this.id, LoggingService? logger})
      : logger = logger ?? LoggingService();

  @override
  Future<void> initialize() async {
    logger.info('IMDb metadata provider initialized: $id', tag: 'IMDbMetadataProvider');
  }

  @override
  Future<void> refresh() async {
    logger.info('IMDb metadata provider refreshed: $id', tag: 'IMDbMetadataProvider');
  }

  @override
  Future<MediaItem?> search(String query) async {
    logger.info('IMDb metadata search: $query', tag: 'IMDbMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem?> lookup(String externalId) async {
    logger.info('IMDb metadata lookup: $externalId', tag: 'IMDbMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem> enrich(MediaItem item) async {
    logger.info('IMDb metadata enrich: ${item.id}', tag: 'IMDbMetadataProvider');
    return item;
  }

  @override
  Future<bool> validate() async {
    logger.info('IMDb metadata provider validated', tag: 'IMDbMetadataProvider');
    return true;
  }

  @override
  Future<void> dispose() async {
    logger.info('IMDb metadata provider disposed: $id', tag: 'IMDbMetadataProvider');
  }
}