import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/metadata_models.dart';
import 'package:stream_hub/data/providers/metadata/metadata_provider.dart';

class FanartMetadataProvider implements MetadataProvider {
  @override
  final String id;
  @override
  final MetadataSourceType sourceType = MetadataSourceType.fanart;
  @override
  bool isEnabled = true;

  final LoggingService logger;

  FanartMetadataProvider({required this.id, LoggingService? logger})
      : logger = logger ?? LoggingService();

  @override
  Future<void> initialize() async {
    logger.info('Fanart metadata provider initialized: $id', tag: 'FanartMetadataProvider');
  }

  @override
  Future<void> refresh() async {
    logger.info('Fanart metadata provider refreshed: $id', tag: 'FanartMetadataProvider');
  }

  @override
  Future<MediaItem?> search(String query) async {
    logger.info('Fanart metadata search: $query', tag: 'FanartMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem?> lookup(String externalId) async {
    logger.info('Fanart metadata lookup: $externalId', tag: 'FanartMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem> enrich(MediaItem item) async {
    logger.info('Fanart metadata enrich: ${item.id}', tag: 'FanartMetadataProvider');
    return item;
  }

  @override
  Future<bool> validate() async {
    logger.info('Fanart metadata provider validated', tag: 'FanartMetadataProvider');
    return true;
  }

  @override
  Future<void> dispose() async {
    logger.info('Fanart metadata provider disposed: $id', tag: 'FanartMetadataProvider');
  }
}