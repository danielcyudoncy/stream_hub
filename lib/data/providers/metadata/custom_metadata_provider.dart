import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/metadata_models.dart';
import 'package:stream_hub/data/providers/metadata/metadata_provider.dart';

class CustomMetadataProvider implements MetadataProvider {
  @override
  final String id;
  @override
  final MetadataSourceType sourceType = MetadataSourceType.custom;
  @override
  bool isEnabled = true;

  final LoggingService logger;
  final Map<String, dynamic> configuration;

  CustomMetadataProvider({required this.id, this.configuration = const {}, LoggingService? logger})
      : logger = logger ?? LoggingService();

  @override
  Future<void> initialize() async {
    logger.info('Custom metadata provider initialized: $id', tag: 'CustomMetadataProvider');
  }

  @override
  Future<void> refresh() async {
    logger.info('Custom metadata provider refreshed: $id', tag: 'CustomMetadataProvider');
  }

  @override
  Future<MediaItem?> search(String query) async {
    logger.info('Custom metadata search: $query', tag: 'CustomMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem?> lookup(String externalId) async {
    logger.info('Custom metadata lookup: $externalId', tag: 'CustomMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem> enrich(MediaItem item) async {
    logger.info('Custom metadata enrich: ${item.id}', tag: 'CustomMetadataProvider');
    return item;
  }

  @override
  Future<bool> validate() async {
    logger.info('Custom metadata provider validated', tag: 'CustomMetadataProvider');
    return true;
  }

  @override
  Future<void> dispose() async {
    logger.info('Custom metadata provider disposed: $id', tag: 'CustomMetadataProvider');
  }
}