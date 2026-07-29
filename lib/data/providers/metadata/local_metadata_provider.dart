import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/metadata_models.dart';
import 'package:stream_hub/data/providers/metadata/metadata_provider.dart';

class LocalMetadataProvider implements MetadataProvider {
  @override
  final String id;
  @override
  final MetadataSourceType sourceType = MetadataSourceType.local;
  @override
  bool isEnabled = true;

  final LoggingService logger;

  LocalMetadataProvider({required this.id, LoggingService? logger})
      : logger = logger ?? LoggingService();

  @override
  Future<void> initialize() async {
    logger.info('Local metadata provider initialized: $id', tag: 'LocalMetadataProvider');
  }

  @override
  Future<void> refresh() async {
    logger.info('Local metadata provider refreshed: $id', tag: 'LocalMetadataProvider');
  }

  @override
  Future<MediaItem?> search(String query) async {
    logger.info('Local metadata search: $query', tag: 'LocalMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem?> lookup(String externalId) async {
    logger.info('Local metadata lookup: $externalId', tag: 'LocalMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem> enrich(MediaItem item) async {
    logger.info('Local metadata enrich: ${item.id}', tag: 'LocalMetadataProvider');
    return item;
  }

  @override
  Future<bool> validate() async {
    logger.info('Local metadata provider validated', tag: 'LocalMetadataProvider');
    return true;
  }

  @override
  Future<void> dispose() async {
    logger.info('Local metadata provider disposed: $id', tag: 'LocalMetadataProvider');
  }
}