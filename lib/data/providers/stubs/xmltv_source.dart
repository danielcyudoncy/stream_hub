import 'package:stream_hub/core/media/enums/media_source_state.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/events/media_event_bus.dart';
import 'package:stream_hub/core/media/media_source.dart';
import 'package:stream_hub/data/models/media_health.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/media_statistics.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/providers/xmltv/xmltv_media_source.dart';

class XMLTVSource implements MediaSource {
  final XMLTVMediaSource _delegate;

  @override
  String get id => _delegate.id;

  @override
  MediaSourceType get type => MediaSourceType.xmltv;

  @override
  MediaSourceState get state => _delegate.state;

  @override
  MediaEventBus? get eventBus => _delegate.eventBus;

  XMLTVSource({
    required String id,
    Map<String, dynamic>? config,
  }) : _delegate = XMLTVMediaSource(
          id: id,
          config: XMLTVConfig(
            sourceUrl: config?['sourceUrl'] as String? ?? '',
            localPath: config?['localPath'] as String?,
            username: config?['username'] as String?,
            password: config?['password'] as String?,
            headers: Map<String, String>.from(config?['headers'] as Map? ?? {}),
            timeout: Duration(seconds: config?['timeout'] as int? ?? 60),
            maxRetries: config?['maxRetries'] as int? ?? 3,
            retryDelay: Duration(seconds: config?['retryDelay'] as int? ?? 2),
            followRedirects: config?['followRedirects'] as bool? ?? true,
            maxRedirects: config?['maxRedirects'] as int? ?? 5,
            compressGz: config?['compressGz'] as bool? ?? true,
            guideVersion: config?['guideVersion'] as String?,
          ),
        );

  @override
  Future<void> initialize() async => _delegate.initialize();

  @override
  Future<void> connect() async => _delegate.connect();

  @override
  Future<void> disconnect() async => _delegate.disconnect();

  @override
  Future<void> dispose() async => _delegate.dispose();

  @override
  Future<void> refresh() async => _delegate.refresh();

  @override
  Future<MediaSyncResult> sync() async => _delegate.sync();

  @override
  Future<bool> validate() async => _delegate.validate();

  @override
  Future<MediaHealth> health() async => _delegate.health();

  @override
  Future<MediaStatistics> statistics() async => _delegate.statistics();

  @override
  Stream<List<MediaItem>> get categoriesStream => _delegate.categoriesStream;

  @override
  Stream<List<MediaItem>> get channelsStream => _delegate.channelsStream;

  @override
  Stream<List<MediaItem>> get moviesStream => _delegate.moviesStream;

  @override
  Stream<List<MediaItem>> get seriesStream => _delegate.seriesStream;

  @override
  Stream<List<MediaItem>> get programsStream => _delegate.programsStream;

  @override
  Future<List<MediaItem>> getCategories() async => _delegate.getCategories();

  @override
  Future<List<MediaItem>> getChannels() async => _delegate.getChannels();

  @override
  Future<List<MediaItem>> getMovies() async => _delegate.getMovies();

  @override
  Future<List<MediaItem>> getSeries() async => _delegate.getSeries();

  @override
  Future<List<MediaItem>> getPrograms() async => _delegate.getPrograms();
}