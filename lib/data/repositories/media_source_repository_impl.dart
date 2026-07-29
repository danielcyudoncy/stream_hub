import 'dart:async';

import 'package:stream_hub/core/media/media_source.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';
import 'package:stream_hub/core/media/enums/media_source_state.dart';
import 'package:stream_hub/data/models/media_health.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/media_statistics.dart';
import 'package:stream_hub/data/repositories/media_source_repository.dart';
import 'package:stream_hub/core/logging/logging_service.dart';

class MediaSourceRepositoryImpl implements MediaSourceRepository {
  final MediaSourceManager _sourceManager;
  final LoggingService _logger;

  MediaSourceRepositoryImpl(this._sourceManager, this._logger);

  @override
  Future<void> register(MediaSource source) async {
    try {
      _sourceManager.register(source);
      _logger.info('Registered media source: ${source.id}', tag: 'MediaSourceRepository');
    } catch (e) {
      _logger.error('Failed to register media source', tag: 'MediaSourceRepository', error: e);
      rethrow;
    }
  }

  @override
  Future<void> unregister(String sourceId) async {
    try {
      _sourceManager.unregister(sourceId);
      _logger.info('Unregistered media source: $sourceId', tag: 'MediaSourceRepository');
    } catch (e) {
      _logger.error('Failed to unregister media source', tag: 'MediaSourceRepository', error: e);
      rethrow;
    }
  }

  @override
  Future<MediaSource?> getById(String sourceId) async {
    return _sourceManager.lookup(sourceId);
  }

  @override
  Future<List<MediaSource>> getAll() async {
    return _sourceManager.getAll();
  }

  @override
  Future<List<MediaSource>> getEnabled() async {
    return _sourceManager.getEnabled();
  }

  @override
  Future<void> updateState(String sourceId, dynamic state) async {
    final source = _sourceManager.lookup(sourceId);
    if (source == null) {
      _logger.warning('Source not found for state update: $sourceId', tag: 'MediaSourceRepository');
      return;
    }

    if (state is MediaSourceState) {
      // Note: state is final on MediaSource, so we cannot directly update it.
      // In a full implementation, the source would expose a mutable state setter.
      _logger.info(
        'State update requested for $sourceId to ${state.displayName}',
        tag: 'MediaSourceRepository',
      );
    }
  }

  @override
  Future<void> delete(String sourceId) async {
    await unregister(sourceId);
  }

  @override
  Future<void> clear() async {
    final all = _sourceManager.getAll();
    for (final source in all) {
      await unregister(source.id);
    }
  }

  Future<List<MediaHealth>> healthCheckAll() async {
    return await _sourceManager.healthCheckAll();
  }

  Future<List<MediaStatistics>> statisticsAll() async {
    return await _sourceManager.statisticsAll();
  }

  Future<List<MediaSyncResult>> syncAll() async {
    return await _sourceManager.syncAll();
  }

  Future<void> syncSource(String sourceId) async {
    final source = _sourceManager.lookup(sourceId);
    if (source != null) {
      await source.sync();
    }
  }
}
