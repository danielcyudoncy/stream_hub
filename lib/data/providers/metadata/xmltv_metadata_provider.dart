import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/metadata_models.dart';
import 'package:stream_hub/data/providers/metadata/metadata_provider.dart';

class XMLTVMetadataProvider implements MetadataProvider {
  @override
  final String id;
  @override
  final MetadataSourceType sourceType = MetadataSourceType.xmltv;
  @override
  bool isEnabled = true;

  final LoggingService logger;

  XMLTVMetadataProvider({required this.id, LoggingService? logger})
      : logger = logger ?? LoggingService();

  @override
  Future<void> initialize() async {
    logger.info('XMLTV metadata provider initialized: $id', tag: 'XMLTVMetadataProvider');
  }

  @override
  Future<void> refresh() async {
    logger.info('XMLTV metadata provider refreshed: $id', tag: 'XMLTVMetadataProvider');
  }

  @override
  Future<MediaItem?> search(String query) async {
    logger.info('XMLTV metadata search: $query', tag: 'XMLTVMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem?> lookup(String externalId) async {
    logger.info('XMLTV metadata lookup: $externalId', tag: 'XMLTVMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem> enrich(MediaItem item) async {
    logger.info('XMLTV metadata enrich: ${item.id}', tag: 'XMLTVMetadataProvider');
    return item;
  }

  @override
  Future<bool> validate() async {
    logger.info('XMLTV metadata provider validated', tag: 'XMLTVMetadataProvider');
    return true;
  }

  @override
  Future<void> dispose() async {
    logger.info('XMLTV metadata provider disposed: $id', tag: 'XMLTVMetadataProvider');
  }
}