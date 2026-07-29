import 'dart:async';

import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_metadata.dart';
import 'package:stream_hub/data/repositories/media_repository.dart';

class MediaRepositoryImpl implements MediaRepository {
  final MediaCatalog _catalog;

  MediaRepositoryImpl(this._catalog);

  @override
  Future<List<MediaItem>> getAll() async {
    return _catalog.getAll();
  }

  @override
  Future<MediaItem?> getById(String id) async {
    return _catalog.getById(id);
  }

  @override
  Future<MediaItem> save(MediaItem item) async {
    _catalog.upsert(item);
    return item;
  }

  @override
  Future<void> delete(String id) async {
    _catalog.remove(id);
  }

  @override
  Future<List<MediaItem>> batchSave(List<MediaItem> items) async {
    for (final item in items) {
      _catalog.upsert(item);
    }
    return items;
  }

  @override
  Future<void> clear() async {
    _catalog.clear();
  }

  @override
  Future<MediaMetadata?> getMetadata(String itemId) async {
    final item = _catalog.getById(itemId);
    if (item == null) return null;
    return MediaMetadata(
      resolution: item.metadata['resolution'] as String?,
      codec: item.metadata['codec'] as String?,
      audio: item.metadata['audio'] as String?,
      runtime: item.metadata['runtime'] != null ? int.tryParse(item.metadata['runtime']!) : null,
    );
  }

  @override
  Future<void> saveMetadata(String itemId, MediaMetadata metadata) async {
    final item = _catalog.getById(itemId);
    if (item == null) return;
    final meta = <String, dynamic>{...item.metadata};
    if (metadata.resolution != null) meta['resolution'] = metadata.resolution;
    if (metadata.codec != null) meta['codec'] = metadata.codec;
    if (metadata.audio != null) meta['audio'] = metadata.audio;
    if (metadata.runtime != null) meta['runtime'] = metadata.runtime.toString();
    final updated = item.copyWith(metadata: meta);
    _catalog.upsert(updated);
  }

  @override
  Stream<List<MediaItem>> watchAll() async* {
    yield _catalog.getAll();
  }
}
