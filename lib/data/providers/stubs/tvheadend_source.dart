import 'package:stream_hub/core/media/enums/media_source_state.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/events/media_event_bus.dart';
import 'package:stream_hub/core/media/media_source.dart';
import 'package:stream_hub/data/models/media_health.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/media_statistics.dart';

class TVHeadendSource implements MediaSource {
  @override
  final String id;
  @override
  MediaSourceType get type => MediaSourceType.tvheadend;
  @override
  MediaSourceState get state => MediaSourceState.created;
  @override
  MediaEventBus? get eventBus => null;

  TVHeadendSource({required this.id, Map<String, dynamic>? config});

  @override
  Future<void> initialize() async {}
  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<MediaSyncResult> sync() async => MediaSyncResult(sourceId: '', success: true, completedAt: DateTime.now());
  @override
  Future<bool> validate() async => true;
  @override
  Future<MediaHealth> health() async => MediaHealth();
  @override
  Future<MediaStatistics> statistics() async => MediaStatistics(lastSync: DateTime.now());

  @override
  Stream<List<MediaItem>> get categoriesStream => const Stream.empty();
  @override
  Stream<List<MediaItem>> get channelsStream => const Stream.empty();
  @override
  Stream<List<MediaItem>> get moviesStream => const Stream.empty();
  @override
  Stream<List<MediaItem>> get seriesStream => const Stream.empty();
  @override
  Stream<List<MediaItem>> get programsStream => const Stream.empty();

  @override
  Future<List<MediaItem>> getCategories() async => [];
  @override
  Future<List<MediaItem>> getChannels() async => [];
  @override
  Future<List<MediaItem>> getMovies() async => [];
  @override
  Future<List<MediaItem>> getSeries() async => [];
  @override
  Future<List<MediaItem>> getPrograms() async => [];
}
