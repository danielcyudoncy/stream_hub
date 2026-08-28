import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/prepared_download.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/data/models/channel.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/modules/live_tv/controllers/multi_view_controller.dart';
import 'package:stream_hub/modules/live_tv/models/multi_view_layout_mode.dart';

class _FakeCatalogRepository implements CatalogRepository {
  final List<MediaItem> items = [];

  @override
  Future<List<MediaItem>> getAllItems() async => List.of(items);

  @override
  Future<List<MediaItem>> getByType(MediaType type) async =>
      List.of(items.where((item) => item.mediaType == type));

  @override
  Future<void> upsertItems(List<MediaItem> newItems) async {}

  @override
  Future<MediaItem?> getItem(String id) async => null;

  @override
  Future<void> deleteItem(String id) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<List<MediaSyncResult>> syncAll() => throw UnimplementedError();

  @override
  Future<MediaSyncResult> syncSource(String sourceId) =>
      throw UnimplementedError();

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<MediaItem>> watchUpdates() => const Stream.empty();

  @override
  Future<void> enrichWithXMLTV(XMLTVGuide guide) async {}

  @override
  Future<void> mergeXMLTVMetadata(XMLTVGuide guide) async {}
}

class _FakeMediaEngine implements MediaEngine {
  @override
  MediaCatalog get catalog => throw UnimplementedError();

  @override
  MediaLibrary get library => throw UnimplementedError();

  @override
  MediaSourceManager get sourceManager => throw UnimplementedError();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> refreshCatalog() async {}

  @override
  Future<List<MediaSyncResult>> syncAllSources() async => [];

  @override
  Future<void> syncSource(String sourceId) async {}

  @override
  Future<List<MediaItem>> search(String query) async => [];

  @override
  Future<List<MediaItem>> searchChannels(String query) async => [];

  @override
  Future<List<MediaItem>> searchMovies(String query) async => [];

  @override
  Future<List<MediaItem>> searchSeries(String query) async => [];

  @override
  Future<List<MediaItem>> searchPrograms(String query) async => [];

  @override
  Future<List<MediaItem>> searchProviders(String query) async => [];

  @override
  Stream<MediaItem> get catalogUpdates => const Stream<MediaItem>.empty();

  @override
  Future<void> enrichMetadata(List<MediaItem> items) async {}

  @override
  Future<void> ingestItems(List<MediaItem> items) async {}
}

class _FakeMediaLibrary implements MediaLibrary {
  @override
  Stream<List<MediaItem>> get liveTVStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get moviesStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get seriesStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get favoritesStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get downloadsStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get historyStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get recentStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get recommendedStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get searchStream => const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get collectionsStream => const Stream<List<MediaItem>>.empty();

  @override
  List<MediaItem> getLiveTV() => [];

  @override
  List<MediaItem> getMovies() => [];

  @override
  List<MediaItem> getSeries() => [];

  @override
  List<MediaItem> getFavorites() => [];

  @override
  List<MediaItem> getDownloads() => [];

  @override
  List<MediaItem> getHistory() => [];

  @override
  List<MediaItem> getRecent() => [];

  @override
  List<MediaItem> getRecommended() => [];

  @override
  List<MediaItem> getCollections() => [];

  @override
  List<MediaItem> search(String query) => [];

  @override
  List<MediaItem> getByType(MediaType type) => [];

  @override
  void addToFavorites(MediaItem item) {}

  @override
  void removeFromFavorites(String itemId) {}

  @override
  void addToHistory(MediaItem item) {}

  @override
  void clearHistory() {}
}

class _FakeStreamRepository implements StreamRepository {
  @override
  Future<PlayableSession> resolvePlayback({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
    bool useCache = true,
    bool validate = true,
  }) async {
    return PlayableSession(
      sessionId: 'session_$mediaItemId',
      mediaItemId: mediaItemId,
      providerId: providerId ?? 'provider',
      providerType: providerType,
      streamUrl: fallbackUrl ?? 'https://example.com/live/stream.m3u8',
      streamType: StreamType.hls,
    );
  }

  @override
  Future<PlayableSession> resolveStream({
    required String mediaItemId,
    required String url,
    required ProviderSession providerSession,
    Map<String, dynamic> itemMetadata = const {},
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<PreparedDownload> prepareDownload({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
    bool validate = true,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> validate(PlayableSession session) async => true;

  @override
  Future<PlayableSession> selectWorking(PlayableSession session) async =>
      session;

  @override
  Future<void> startBackgroundTasks() async {}

  @override
  Future<void> stopBackgroundTasks() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCatalogRepository catalogRepo;
  late MediaEngine mediaEngine;
  late MediaLibrary mediaLibrary;
  late MultiViewController controller;

  final testChannel1 = Channel(
    id: 'ch-1',
    providerId: 'p-1',
    providerType: MediaSourceType.m3u,
    title: 'ESPN HD',
    mediaType: MediaType.channel,
    streamUrl: 'https://example.com/espn.m3u8',
    metadata: {'category': 'Sports'},
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final testChannel2 = Channel(
    id: 'ch-2',
    providerId: 'p-1',
    providerType: MediaSourceType.m3u,
    title: 'BBC One',
    mediaType: MediaType.channel,
    streamUrl: 'https://example.com/bbc.m3u8',
    metadata: {'category': 'News'},
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() {
    Get.testMode = true;
    catalogRepo = _FakeCatalogRepository();
    catalogRepo.items.addAll([testChannel1, testChannel2]);

    Get.put<StreamRepository>(_FakeStreamRepository());

    mediaEngine = _FakeMediaEngine();
    mediaLibrary = _FakeMediaLibrary();

    controller = MultiViewController(
      catalogRepository: catalogRepo,
      mediaEngine: mediaEngine,
      mediaLibrary: mediaLibrary,
    );
  });

  tearDown(() {
    Get.reset();
  });

  test('MultiViewController initializes with quad layout and loads channels and categories', () async {
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.layoutMode.value, MultiViewLayoutMode.quad);
    expect(controller.allChannels.length, 2);
    expect(controller.categories, containsAll(['All Channels', 'Sports', 'News']));
    expect(controller.providers, contains('p-1'));
    expect(controller.activeAudioSlot.value, 0);
  });

  test('MultiViewController assigns channel to slot and changes audio focus', () async {
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await controller.setChannelForSlot(0, testChannel1);
    await controller.setChannelForSlot(1, testChannel2);

    expect(controller.slots[0].value?.title, 'ESPN HD');
    expect(controller.slots[1].value?.title, 'BBC One');

    controller.setActiveAudioSlot(1);
    expect(controller.activeAudioSlot.value, 1);
  });

  test('MultiViewController clears slot correctly', () async {
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await controller.setChannelForSlot(0, testChannel1);
    expect(controller.slots[0].value, isNotNull);

    controller.clearSlot(0);
    expect(controller.slots[0].value, isNull);
  });

  test('MultiViewController switches layout mode and cleans out-of-bounds slots', () async {
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await controller.setChannelForSlot(0, testChannel1);
    await controller.setChannelForSlot(1, testChannel2);
    await controller.setChannelForSlot(2, testChannel1);
    await controller.setChannelForSlot(3, testChannel2);

    controller.setActiveAudioSlot(3);
    controller.setLayoutMode(MultiViewLayoutMode.dualHorizontal);

    expect(controller.layoutMode.value, MultiViewLayoutMode.dualHorizontal);
    expect(controller.slots[2].value, isNull);
    expect(controller.slots[3].value, isNull);
    expect(controller.activeAudioSlot.value, 0);
  });
}
