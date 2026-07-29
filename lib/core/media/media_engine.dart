import 'dart:async';

import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/metadata/media_library_impl.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';

abstract class MediaEngine {
  MediaCatalog get catalog;
  MediaLibrary get library;
  MediaSourceManager get sourceManager;

  Future<void> initialize();
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
  Future<void> refreshCatalog();
  Future<List<MediaSyncResult>> syncAllSources();
  Future<void> syncSource(String sourceId);
  Future<List<MediaItem>> search(String query);
  Future<List<MediaItem>> searchChannels(String query);
  Future<List<MediaItem>> searchMovies(String query);
  Future<List<MediaItem>> searchSeries(String query);
  Future<List<MediaItem>> searchPrograms(String query);
  Future<List<MediaItem>> searchProviders(String query);
  Stream<MediaItem> get catalogUpdates;
  Future<void> enrichMetadata(List<MediaItem> items);
  Future<void> ingestItems(List<MediaItem> items);
}

class DefaultMediaEngine implements MediaEngine {
  final MediaCatalog _catalog;
  final MediaLibrary _library;
  final MediaSourceManager _sourceManager;
  final CatalogRepository _catalogRepository;
  final StreamController<MediaItem> _catalogUpdatesController = StreamController<MediaItem>.broadcast();

  DefaultMediaEngine(
    this._catalog,
    this._library,
    this._sourceManager,
    this._catalogRepository,
  );

  @override
  MediaCatalog get catalog => _catalog;

  @override
  MediaLibrary get library => _library;

  @override
  MediaSourceManager get sourceManager => _sourceManager;

  @override
  Future<void> initialize() async {
    await _sourceManager.initializeAll();
  }

  @override
  Future<void> start() async {
    await _sourceManager.connectAll();
    await refreshCatalog();
  }

  @override
  Future<void> stop() async {
    await _sourceManager.disconnectAll();
  }

  @override
  Future<void> dispose() async {
    await _sourceManager.disposeAll();
    await _catalogUpdatesController.close();
  }

  @override
  Future<void> refreshCatalog() async {
    await _sourceManager.syncAll();
  }

  @override
  Future<List<MediaSyncResult>> syncAllSources() async {
    return await _sourceManager.syncAll();
  }

  @override
  Future<void> syncSource(String sourceId) async {
    final source = _sourceManager.lookup(sourceId);
    if (source != null) {
      await source.sync();
    }
  }

  @override
  Future<List<MediaItem>> search(String query) async {
    final items = _catalog.getAll();
    if (_library is MediaLibraryImpl) {
      return _library.searchEngine.search(query, items);
    }
    return [];
  }

  @override
  Future<List<MediaItem>> searchChannels(String query) async {
    final all = await search(query);
    return all.where((item) => item.mediaType == MediaType.channel).toList();
  }

  @override
  Future<List<MediaItem>> searchMovies(String query) async {
    final all = await search(query);
    return all.where((item) => item.mediaType == MediaType.movie).toList();
  }

  @override
  Future<List<MediaItem>> searchSeries(String query) async {
    final all = await search(query);
    return all.where((item) => item.mediaType == MediaType.series).toList();
  }

  @override
  Future<List<MediaItem>> searchPrograms(String query) async {
    final all = await search(query);
    return all.where((item) => item.mediaType == MediaType.program).toList();
  }

  @override
  Future<List<MediaItem>> searchProviders(String query) async {
    return [];
  }

  @override
  Stream<MediaItem> get catalogUpdates => _catalogUpdatesController.stream;

  @override
  Future<void> enrichMetadata(List<MediaItem> items) async {
    if (_library is MediaLibraryImpl) {
      await _library.enrichMetadata(items);
    }
  }

  @override
  Future<void> ingestItems(List<MediaItem> items) async {
    if (_library is MediaLibraryImpl) {
      await _library.ingest(items);
    }
    await _catalogRepository.upsertItems(items);
  }
}