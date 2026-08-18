import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/modules/series/series_controller.dart';

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
  Stream<List<MediaItem>> get liveTVStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get moviesStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get seriesStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get favoritesStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get downloadsStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get historyStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get recentStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get recommendedStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get searchStream =>
      const Stream<List<MediaItem>>.empty();

  @override
  Stream<List<MediaItem>> get collectionsStream =>
      const Stream<List<MediaItem>>.empty();

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCatalogRepository catalogRepository;
  late _FakeMediaLibrary mediaLibrary;
  late _FakeMediaEngine mediaEngine;

  setUp(() {
    catalogRepository = _FakeCatalogRepository();
    mediaLibrary = _FakeMediaLibrary();
    mediaEngine = _FakeMediaEngine();
  });

  MediaItem seriesItem({
    required String id,
    required String title,
    String providerId = 'default',
    MediaSourceType providerType = MediaSourceType.xtream,
  }) {
    return MediaItem(
      id: id,
      title: title,
      providerId: providerId,
      providerType: providerType,
      mediaType: MediaType.series,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  test('filters series by selected provider id or display name', () async {
    catalogRepository.items.addAll([
      seriesItem(id: 's1', title: 'Breaking Bad', providerId: 'prov-1', providerType: MediaSourceType.xtream),
      seriesItem(id: 's2', title: 'Planet Earth', providerId: 'prov-2', providerType: MediaSourceType.m3u),
    ]);

    final controller = SeriesController(
      mediaEngine: mediaEngine,
      mediaLibrary: mediaLibrary,
      catalogRepository: catalogRepository,
    );

    await controller.reloadSeries();

    expect(controller.series, hasLength(2));

    controller.setProvider('prov-1');
    expect(controller.series, hasLength(1));
    expect(controller.series.first.id, 's1');

    controller.setProvider('prov-2');
    expect(controller.series, hasLength(1));
    expect(controller.series.first.id, 's2');

    controller.setProvider('');
    expect(controller.series, hasLength(2));
  });
}
