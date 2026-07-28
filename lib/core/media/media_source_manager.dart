import 'dart:async';

import 'package:stream_hub/core/media/enums/media_source_state.dart';
import 'package:stream_hub/core/media/media_source.dart';
import 'package:stream_hub/core/media/media_source_registry.dart';
import 'package:stream_hub/data/models/media_health.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/media_statistics.dart';

class MediaSourceManager implements MediaSourceRegistry {
  final Map<String, MediaSource> _sources = {};
  final Map<String, Timer> _healthTimers = {};

  @override
  void register(MediaSource source) {
    _sources[source.id] = source;
  }

  @override
  void unregister(String sourceId) {
    _sources.remove(sourceId);
    _healthTimers[sourceId]?.cancel();
    _healthTimers.remove(sourceId);
  }

  @override
  MediaSource? lookup(String sourceId) {
    return _sources[sourceId];
  }

  @override
  List<MediaSource> getAll() {
    return _sources.values.toList();
  }

  @override
  List<MediaSource> getEnabled() {
    return _sources.values.where((s) => s.state != MediaSourceState.disabled && s.state != MediaSourceState.disposed).toList();
  }

  Future<void> initializeAll() async {
    for (final source in _sources.values) {
      await source.initialize();
    }
  }

  Future<void> connectAll() async {
    for (final source in _sources.values) {
      await source.connect();
    }
  }

  Future<void> disconnectAll() async {
    for (final source in _sources.values) {
      await source.disconnect();
    }
  }

  Future<void> disposeAll() async {
    for (final source in _sources.values) {
      await source.dispose();
    }
    _sources.clear();
    for (final timer in _healthTimers.values) {
      timer.cancel();
    }
    _healthTimers.clear();
  }

  Future<List<MediaSyncResult>> syncAll() async {
    final results = <MediaSyncResult>[];
    for (final source in _sources.values) {
      if (source.state == MediaSourceState.disabled || source.state == MediaSourceState.disposed) continue;
      try {
        final result = await source.sync();
        results.add(result);
      } catch (e) {
        results.add(MediaSyncResult(
          sourceId: source.id,
          success: false,
          error: e.toString(),
          completedAt: DateTime.now(),
        ));
      }
    }
    return results;
  }

  Future<void> refreshAll() async {
    for (final source in _sources.values) {
      if (source.state == MediaSourceState.disabled || source.state == MediaSourceState.disposed) continue;
      await source.refresh();
    }
  }

  Future<List<MediaHealth>> healthCheckAll() async {
    final results = <MediaHealth>[];
    for (final source in _sources.values) {
      try {
        final health = await source.health();
        results.add(health);
      } catch (_) {
        results.add(const MediaHealth(isConnected: false));
      }
    }
    return results;
  }

  Future<List<MediaStatistics>> statisticsAll() async {
    final results = <MediaStatistics>[];
    for (final source in _sources.values) {
      try {
        final stats = await source.statistics();
        results.add(stats);
      } catch (_) {
        results.add(MediaStatistics(lastSync: DateTime.now()));
      }
    }
    return results;
  }

  MediaSource? getActiveSource() {
    final connected = _sources.values.where((s) => s.state == MediaSourceState.connected).toList();
    if (connected.isEmpty) return null;
    return connected.first;
  }

  List<MediaItem> search(String query) {
    final results = <MediaItem>[];
    for (final source in _sources.values) {
      if (source.state != MediaSourceState.connected) continue;
    }
    return results;
  }
}
