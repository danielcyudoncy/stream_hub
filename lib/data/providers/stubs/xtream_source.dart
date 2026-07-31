import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_state.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/events/media_event_bus.dart';
import 'package:stream_hub/core/media/media_source.dart';
import 'package:stream_hub/data/models/media_health.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/media_statistics.dart';

class XtreamSource implements MediaSource {
  final String _id;
  final String _serverUrl;
  final String _username;
  final String _password;
  final LoggingService _logger;
  final HttpClient _client = HttpClient();

  MediaSourceState _state = MediaSourceState.created;

  List<MediaItem> _cachedChannels = [];
  List<MediaItem> _cachedCategories = [];
  DateTime _lastSync = DateTime.now();

  @override
  String get id => _id;

  @override
  MediaSourceType get type => MediaSourceType.xtream;

  @override
  MediaSourceState get state => _state;

  @override
  MediaEventBus? get eventBus => null;

  final StreamController<List<MediaItem>> _categoriesController =
      StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _channelsController =
      StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _moviesController =
      StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _seriesController =
      StreamController<List<MediaItem>>.broadcast();
  final StreamController<List<MediaItem>> _programsController =
      StreamController<List<MediaItem>>.broadcast();

  XtreamSource({required String id, Map<String, dynamic>? config, LoggingService? logger})
      : _id = id,
        _serverUrl = (config?['sourceUrl'] as String? ?? '').replaceAll(RegExp(r'/+$'), ''),
        _username = config?['username'] as String? ?? '',
        _password = config?['password'] as String? ?? '',
        _logger = logger ?? Get.find<LoggingService>();

  @override
  Future<void> initialize() async {
    _state = MediaSourceState.ready;
  }

  @override
  Future<void> connect() async {
    _state = MediaSourceState.connected;
  }

  @override
  Future<void> disconnect() async {
    _state = MediaSourceState.offline;
  }

  @override
  Future<void> dispose() async {
    _client.close(force: true);
    await _categoriesController.close();
    await _channelsController.close();
    await _moviesController.close();
    await _seriesController.close();
    await _programsController.close();
  }

  @override
  Future<void> refresh() async {
    await sync();
  }

  @override
  Future<MediaSyncResult> sync() async {
    _state = MediaSourceState.syncing;
    final syncStartedAt = DateTime.now();

    try {
      final channels = await _fetchLiveChannels(syncStartedAt);
      final categories = await _fetchLiveCategories(syncStartedAt);

      _cachedChannels = channels;
      _cachedCategories = categories;
      _lastSync = DateTime.now();

      _channelsController.add(_cachedChannels);
      _categoriesController.add(_cachedCategories);

      _state = MediaSourceState.ready;
      _logger.info(
        'Xtream sync complete: ${channels.length} channels, ${categories.length} categories',
        tag: 'XtreamSource',
      );

      return MediaSyncResult(
        sourceId: _id,
        success: true,
        added: channels.length,
        completedAt: _lastSync,
      );
    } catch (e) {
      _state = MediaSourceState.error;
      _logger.error('Xtream sync failed', tag: 'XtreamSource', error: e);
      return MediaSyncResult(
        sourceId: _id,
        success: false,
        error: e.toString(),
        completedAt: DateTime.now(),
      );
    }
  }

  Future<List<MediaItem>> _fetchLiveChannels(DateTime createdAt) async {
    final uri = Uri.parse(
      '$_serverUrl/player_api.php?username=$_username&password=$_password&action=live',
    );

    final jsonStr = await _getJson(uri);
    if (jsonStr == null) {
      throw Exception('Xtream API returned non-200 status for live channels');
    }

    final decoded = json.decode(jsonStr);
    if (decoded is! Map || decoded['data'] is! List) return [];

    final data = decoded['data'] as List;
    final channels = <MediaItem>[];

    for (final item in data) {
      if (item is! Map) continue;
      final streamId = item['stream_id'];
      final name = item['name'] as String? ?? 'Unknown';
      if (streamId == null) continue;

      final categoryId = item['category_id']?.toString() ?? '';
      final streamIcon = item['stream_icon'] as String? ?? '';
      final epgChannelId = item['epg_channel_id'] as String? ?? '';

      final streamExt = 'm3u8';
      final streamUrl =
          '$_serverUrl/live/$_username/$_password/${streamId.toString()}.$streamExt';

      final metadata = <String, dynamic>{
        'streamUrl': streamUrl,
        'streamId': streamId,
        'categoryId': categoryId,
        'epgChannelId': epgChannelId,
        'streamIcon': streamIcon,
        'tvArchive': item['tv_archive'],
        'tvArchiveDuration': item['tv_archive_duration'],
      };

      channels.add(MediaItem(
        id: 'xtream-live-$streamId',
        providerId: _id,
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.channel,
        title: name,
        poster: streamIcon.isNotEmpty ? streamIcon : null,
        genres: categoryId.isNotEmpty ? [categoryId] : [],
        metadata: metadata,
        createdAt: createdAt,
        updatedAt: createdAt,
      ));
    }

    return channels;
  }

  Future<List<MediaItem>> _fetchLiveCategories(DateTime createdAt) async {
    final uri = Uri.parse(
      '$_serverUrl/player_api.php?username=$_username&password=$_password&action=get_live_categories',
    );

    final jsonStr = await _getJson(uri);
    if (jsonStr == null) {
      throw Exception('Xtream API returned non-200 status for live categories');
    }

    final decoded = json.decode(jsonStr);
    if (decoded is! Map || decoded['data'] is! List) return [];

    final data = decoded['data'] as List;
    final categories = <MediaItem>[];

    for (final item in data) {
      if (item is! Map) continue;
      final categoryId = item['category_id']?.toString() ?? '';
      final categoryName = item['category_name'] as String? ?? '';
      if (categoryId.isEmpty || categoryName.isEmpty) continue;

      categories.add(MediaItem(
        id: 'xtream-cat-$categoryId',
        providerId: _id,
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.collection,
        title: categoryName,
        metadata: {
          'categoryId': categoryId,
          'parentId': item['parent_id'],
        },
        createdAt: createdAt,
        updatedAt: createdAt,
      ));
    }

    return categories;
  }

  Future<String?> _getJson(Uri uri) async {
    final request = await _client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'StreamHubPro/1.0');

    final response = await request.close();
    if (response.statusCode != 200) {
      _logger.warning(
        'Xtream API returned ${response.statusCode} for $uri',
        tag: 'XtreamSource',
      );
      return null;
    }

    final bytes = await response.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
    return utf8.decode(bytes);
  }

  @override
  Future<bool> validate() async {
    try {
      final uri = Uri.parse(
        '$_serverUrl/player_api.php?username=$_username&password=$_password',
      );
      final request = await _client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'StreamHubPro/1.0');

      final response = await request.close();
      if (response.statusCode != 200) return false;

      final bytes = await response.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
      final body = utf8.decode(bytes);
      final decoded = json.decode(body);
      if (decoded is! Map) return false;
      final userInfo = decoded['user_info'] as Map?;
      return userInfo != null && userInfo['auth'] == 1;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<MediaHealth> health() async {
    try {
      final uri = Uri.parse(
        '$_serverUrl/player_api.php?username=$_username&password=$_password',
      );
      final stopwatch = Stopwatch()..start();
      final request = await _client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      stopwatch.stop();

      final isConnected = response.statusCode == 200;
      return MediaHealth(
        isConnected: isConnected,
        latencyMs: stopwatch.elapsedMilliseconds,
        isAuthenticated: isConnected,
        lastSync: _lastSync,
        errors: isConnected ? [] : ['HTTP ${response.statusCode}'],
      );
    } catch (e) {
      return MediaHealth(
        isConnected: false,
        errors: [e.toString()],
      );
    }
  }

  @override
  Future<MediaStatistics> statistics() async {
    return MediaStatistics(
      totalItems: _cachedChannels.length + _cachedCategories.length,
      channels: _cachedChannels.length,
      categories: _cachedCategories.length,
      lastSync: _lastSync,
    );
  }

  @override
  Stream<List<MediaItem>> get categoriesStream => _categoriesController.stream;

  @override
  Stream<List<MediaItem>> get channelsStream => _channelsController.stream;

  @override
  Stream<List<MediaItem>> get moviesStream => _moviesController.stream;

  @override
  Stream<List<MediaItem>> get seriesStream => _seriesController.stream;

  @override
  Stream<List<MediaItem>> get programsStream => _programsController.stream;

  @override
  Future<List<MediaItem>> getCategories() async => _cachedCategories;

  @override
  Future<List<MediaItem>> getChannels() async => _cachedChannels;

  @override
  Future<List<MediaItem>> getMovies() async => [];

  @override
  Future<List<MediaItem>> getSeries() async => [];

  @override
  Future<List<MediaItem>> getPrograms() async => [];
}
