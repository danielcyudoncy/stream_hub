import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/metadata_models.dart';
import 'package:stream_hub/data/providers/metadata/metadata_provider.dart';

class ProviderNativeMetadataProvider implements MetadataProvider {
  @override
  final String id;
  @override
  final MetadataSourceType sourceType = MetadataSourceType.provider;
  @override
  bool isEnabled = true;

  final LoggingService logger;
  final String providerId;

  ProviderNativeMetadataProvider({required this.id, required this.providerId, LoggingService? logger})
      : logger = logger ?? LoggingService();

  @override
  Future<void> initialize() async {
    logger.info('Provider native metadata provider initialized: $id', tag: 'ProviderNativeMetadataProvider');
  }

  @override
  Future<void> refresh() async {
    logger.info('Provider native metadata provider refreshed: $id', tag: 'ProviderNativeMetadataProvider');
  }

  @override
  Future<MediaItem?> search(String query) async {
    logger.info('Provider native metadata search: $query', tag: 'ProviderNativeMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem?> lookup(String externalId) async {
    logger.info('Provider native metadata lookup: $externalId', tag: 'ProviderNativeMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem> enrich(MediaItem item) async {
    logger.info('Provider native metadata enrich: ${item.id}', tag: 'ProviderNativeMetadataProvider');
    return item;
  }

  @override
  Future<bool> validate() async {
    logger.info('Provider native metadata provider validated', tag: 'ProviderNativeMetadataProvider');
    return true;
  }

  @override
  Future<void> dispose() async {
    logger.info('Provider native metadata provider disposed: $id', tag: 'ProviderNativeMetadataProvider');
  }
}