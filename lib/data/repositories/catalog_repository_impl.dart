import 'package:stream_hub/core/media/enums/media_type.dart';

import 'dart:async';

import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/core/logging/logging_service.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  final MediaCatalog _catalog;
  final MediaSourceManager _sourceManager;
  final LoggingService _logger;
  final StreamController<void> _updateController =
      StreamController<void>.broadcast();
  Timer? _debounceTimer;

  CatalogRepositoryImpl(this._catalog, this._sourceManager, this._logger);

  void _notifyUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (!_updateController.isClosed) {
        _updateController.add(null);
      }
    });
  }

  @override
  Future<List<MediaItem>> getAllItems() async {
    return _catalog.getAll();
  }

  @override
  Future<List<MediaItem>> getByType(MediaType type) async {
    return _catalog.getByType(type);
  }

  @override
  Future<MediaItem?> getItem(String id) async {
    return _catalog.getById(id);
  }

  @override
  Future<void> upsertItems(List<MediaItem> items) async {
    _catalog.upsertAll(items);
    _notifyUpdate();
    _logger.info(
      'Upserted ${items.length} items into catalog',
      tag: 'CatalogRepository',
    );
  }

  @override
  Future<void> deleteItem(String id) async {
    _catalog.remove(id);
    _notifyUpdate();
  }

  @override
  Future<void> clear() async {
    _catalog.clear();
    _notifyUpdate();
  }

  @override
  Future<List<MediaSyncResult>> syncAll() async {
    return await _sourceManager.syncAll();
  }

  @override
  Future<MediaSyncResult> syncSource(String sourceId) async {
    final source = _sourceManager.lookup(sourceId);
    if (source == null) {
      return MediaSyncResult(
        sourceId: sourceId,
        success: false,
        error: 'Source not found',
        completedAt: DateTime.now(),
      );
    }
    final result = await source.sync();
    if (result.success) {
      final items = <MediaItem>[];
      final errors = <String>[];
      try {
        final channels = await source.getChannels();
        items.addAll(channels);
        _logger.info(
          'Ingested ${channels.length} channels from source $sourceId',
          tag: 'CatalogRepository',
        );
      } catch (e) {
        errors.add('channels: $e');
        _logger.warning(
          'Failed to ingest channels from source $sourceId: $e',
          tag: 'CatalogRepository',
          error: e,
        );
      }
      try {
        final categories = await source.getCategories();
        items.addAll(categories);
        _logger.info(
          'Ingested ${categories.length} categories from source $sourceId',
          tag: 'CatalogRepository',
        );
      } catch (e) {
        errors.add('categories: $e');
        _logger.warning(
          'Failed to ingest categories from source $sourceId: $e',
          tag: 'CatalogRepository',
          error: e,
        );
      }
      try {
        final movies = await source.getMovies();
        items.addAll(movies);
        _logger.info(
          'Ingested ${movies.length} movies from source $sourceId',
          tag: 'CatalogRepository',
        );
      } catch (e) {
        errors.add('movies: $e');
        _logger.warning(
          'Failed to ingest movies from source $sourceId: $e',
          tag: 'CatalogRepository',
          error: e,
        );
      }
      try {
        final series = await source.getSeries();
        items.addAll(series);
        _logger.info(
          'Ingested ${series.length} series from source $sourceId',
          tag: 'CatalogRepository',
        );
      } catch (e) {
        errors.add('series: $e');
        _logger.warning(
          'Failed to ingest series from source $sourceId: $e',
          tag: 'CatalogRepository',
          error: e,
        );
      }
      try {
        final programs = await source.getPrograms();
        items.addAll(programs);
        _logger.info(
          'Ingested ${programs.length} programs from source $sourceId',
          tag: 'CatalogRepository',
        );
      } catch (e) {
        errors.add('programs: $e');
        _logger.warning(
          'Failed to ingest programs from source $sourceId: $e',
          tag: 'CatalogRepository',
          error: e,
        );
      }
      _catalog.upsertAll(items);
      _notifyUpdate();
      if (errors.isNotEmpty) {
        _logger.warning(
          'Source $sourceId ingested ${items.length} items with ${errors.length} partial failures: ${errors.join(', ')}',
          tag: 'CatalogRepository',
        );
      } else {
        _logger.info(
          'Ingested ${items.length} items from source $sourceId',
          tag: 'CatalogRepository',
        );
      }
    }
    return result;
  }

  @override
  Future<void> refresh() async {
    await _sourceManager.refreshAll();
  }

  @override
  Stream<List<MediaItem>> watchUpdates() async* {
    await for (final _ in _updateController.stream) {
      yield _catalog.getAll();
    }
  }

  @override
  Future<void> enrichWithXMLTV(XMLTVGuide guide) async {
    for (final channel in guide.channels) {
      final existing = _catalog.getById(
        'xmltv-channel-${guide.sourceId}-${channel.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
      );
      if (existing != null) {
        final enriched = existing.copyWith(
          poster: channel.iconUrl ?? existing.poster,
          thumbnail: channel.iconUrl ?? existing.thumbnail,
          language: channel.language ?? existing.language,
          country: channel.country ?? existing.country,
          metadata: {
            ...existing.metadata,
            'tvgId': channel.id,
            'displayName': channel.displayName,
            'iconUrl': channel.iconUrl ?? '',
            'aliases': channel.aliases,
          },
          updatedAt: DateTime.now(),
        );
        _catalog.upsert(enriched);
      }
    }

    _logger.info(
      'Enriched catalog with ${guide.channels.length} XMLTV channels',
      tag: 'CatalogRepository',
    );
  }

  @override
  Future<void> mergeXMLTVMetadata(XMLTVGuide guide) async {
    for (final program in guide.programs) {
      final mediaItem = program.toMediaItem(guide.sourceId);
      final existing = _catalog.getById(mediaItem.id);

      if (existing != null) {
        final merged = _mergeMediaItem(existing, mediaItem);
        _catalog.upsert(merged);
      } else {
        _catalog.upsert(mediaItem);
      }
    }

    _logger.info(
      'Merged ${guide.programs.length} XMLTV programs into catalog',
      tag: 'CatalogRepository',
    );
  }

  MediaItem _mergeMediaItem(MediaItem existing, MediaItem incoming) {
    final mergedMetadata = <String, dynamic>{
      ...existing.metadata,
      ...incoming.metadata,
    };

    final mergedGenres = <String>{
      ...existing.genres,
      ...incoming.genres,
    }.toList();

    return existing.copyWith(
      title: incoming.title.isNotEmpty ? incoming.title : existing.title,
      subtitle: incoming.subtitle ?? existing.subtitle,
      description: incoming.description ?? existing.description,
      poster: incoming.poster ?? existing.poster,
      genres: mergedGenres,
      rating: incoming.rating ?? existing.rating,
      language: incoming.language ?? existing.language,
      country: incoming.country ?? existing.country,
      metadata: mergedMetadata,
      updatedAt: DateTime.now(),
    );
  }
}
