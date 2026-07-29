import 'dart:async';

import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  final MediaCatalog _catalog;
  final MediaSourceManager _sourceManager;
  final LoggingService _logger;

  CatalogRepositoryImpl(this._catalog, this._sourceManager, this._logger);

  @override
  Future<List<MediaItem>> getAllItems() async {
    return _catalog.getAll();
  }

  @override
  Future<MediaItem?> getItem(String id) async {
    return _catalog.getById(id);
  }

  @override
  Future<void> upsertItems(List<MediaItem> items) async {
    for (final item in items) {
      _catalog.upsert(item);
    }
    _logger.info('Upserted ${items.length} items into catalog', tag: 'CatalogRepository');
  }

  @override
  Future<void> deleteItem(String id) async {
    _catalog.remove(id);
  }

  @override
  Future<void> clear() async {
    _catalog.clear();
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
    return await source.sync();
  }

  @override
  Future<void> refresh() async {
    await _sourceManager.refreshAll();
  }

  @override
  Stream<List<MediaItem>> watchUpdates() async* {
    yield _catalog.getAll();
  }
}