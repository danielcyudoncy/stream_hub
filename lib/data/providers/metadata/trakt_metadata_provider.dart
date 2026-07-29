import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/metadata_models.dart';
import 'package:stream_hub/data/providers/metadata/metadata_provider.dart';

class TraktMetadataProvider implements MetadataProvider {
  @override
  final String id;
  @override
  final MetadataSourceType sourceType = MetadataSourceType.trakt;
  @override
  bool isEnabled = true;

  final LoggingService logger;

  TraktMetadataProvider({required this.id, LoggingService? logger})
      : logger = logger ?? LoggingService();

  @override
  Future<void> initialize() async {
    logger.info('Trakt metadata provider initialized: $id', tag: 'TraktMetadataProvider');
  }

  @override
  Future<void> refresh() async {
    logger.info('Trakt metadata provider refreshed: $id', tag: 'TraktMetadataProvider');
  }

  @override
  Future<MediaItem?> search(String query) async {
    logger.info('Trakt metadata search: $query', tag: 'TraktMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem?> lookup(String externalId) async {
    logger.info('Trakt metadata lookup: $externalId', tag: 'TraktMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem> enrich(MediaItem item) async {
    logger.info('Trakt metadata enrich: ${item.id}', tag: 'TraktMetadataProvider');
    return item;
  }

  @override
  Future<bool> validate() async {
    logger.info('Trakt metadata provider validated', tag: 'TraktMetadataProvider');
    return true;
  }

  @override
  Future<void> dispose() async {
    logger.info('Trakt metadata provider disposed: $id', tag: 'TraktMetadataProvider');
  }
}