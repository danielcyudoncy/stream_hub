import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/metadata_models.dart';
import 'package:stream_hub/data/providers/metadata/metadata_provider.dart';

class TVMazeMetadataProvider implements MetadataProvider {
  @override
  final String id;
  @override
  final MetadataSourceType sourceType = MetadataSourceType.tvmaze;
  @override
  bool isEnabled = true;

  final LoggingService logger;

  TVMazeMetadataProvider({required this.id, LoggingService? logger})
      : logger = logger ?? LoggingService();

  @override
  Future<void> initialize() async {
    logger.info('TVMaze metadata provider initialized: $id', tag: 'TVMazeMetadataProvider');
  }

  @override
  Future<void> refresh() async {
    logger.info('TVMaze metadata provider refreshed: $id', tag: 'TVMazeMetadataProvider');
  }

  @override
  Future<MediaItem?> search(String query) async {
    logger.info('TVMaze metadata search: $query', tag: 'TVMazeMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem?> lookup(String externalId) async {
    logger.info('TVMaze metadata lookup: $externalId', tag: 'TVMazeMetadataProvider');
    return null;
  }

  @override
  Future<MediaItem> enrich(MediaItem item) async {
    logger.info('TVMaze metadata enrich: ${item.id}', tag: 'TVMazeMetadataProvider');
    return item;
  }

  @override
  Future<bool> validate() async {
    logger.info('TVMaze metadata provider validated', tag: 'TVMazeMetadataProvider');
    return true;
  }

  @override
  Future<void> dispose() async {
    logger.info('TVMaze metadata provider disposed: $id', tag: 'TVMazeMetadataProvider');
  }
}