import 'dart:async';

import 'package:stream_hub/core/media/enums/media_source_state.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/events/media_event_bus.dart';
import 'package:stream_hub/data/models/media_health.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_statistics.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';

abstract class MediaSource {
  String get id;
  MediaSourceType get type;
  MediaSourceState get state;
  MediaEventBus? get eventBus;

  Future<void> initialize();
  Future<void> connect();
  Future<void> disconnect();
  Future<void> dispose();
  Future<void> refresh();
  Future<MediaSyncResult> sync();
  Future<bool> validate();
  Future<MediaHealth> health();
  Future<MediaStatistics> statistics();
  Stream<List<MediaItem>> get categoriesStream;
  Stream<List<MediaItem>> get channelsStream;
  Stream<List<MediaItem>> get moviesStream;
  Stream<List<MediaItem>> get seriesStream;
  Stream<List<MediaItem>> get programsStream;
  Future<List<MediaItem>> getCategories();
  Future<List<MediaItem>> getChannels();
  Future<List<MediaItem>> getMovies();
  Future<List<MediaItem>> getSeries();
  Future<List<MediaItem>> getPrograms();
}
