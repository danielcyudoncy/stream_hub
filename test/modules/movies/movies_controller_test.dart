import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
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
import 'package:stream_hub/modules/movies/movies_controller.dart';

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

MediaItem movie({
  required String id,
  required String title,
  List<String> genres = const [],
  double? rating,
  DateTime? createdAt,
  DateTime? updatedAt,
  Map<String, dynamic> metadata = const {},
}) {
  final now = DateTime(2026, 8, 13);
  return MediaItem(
    id: id,
    providerId: 'provider-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.movie,
    title: title,
    genres: genres,
    rating: rating,
    metadata: metadata,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

void main() {
  late _FakeCatalogRepository catalogRepository;

  MoviesController buildController() {
    return MoviesController(
      mediaEngine: _FakeMediaEngine(),
      mediaLibrary: _FakeMediaLibrary(),
      catalogRepository: catalogRepository,
    );
  }

  Future<void> pumpLoad(MoviesController controller) async {
    controller.onInit();
    while (controller.isLoading.value) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  setUp(() {
    Get.reset();
    Get.put(LoggingService());
    catalogRepository = _FakeCatalogRepository();
  });

  tearDown(() {
    Get.reset();
  });

  test('builds a 3-item featured carousel from rated movies first', () async {
    catalogRepository.items.addAll([
      movie(id: 'm1', title: 'One', rating: 7.1),
      movie(
        id: 'm2',
        title: 'Two',
        rating: 8.4,
        updatedAt: DateTime(2026, 8, 12),
      ),
      movie(
        id: 'm3',
        title: 'Three',
        rating: 9.2,
        updatedAt: DateTime(2026, 8, 11),
      ),
      movie(id: 'm4', title: 'Four', rating: 6.8),
    ]);

    final controller = buildController();
    await pumpLoad(controller);

    expect(controller.featuredMovies.length, 3);
    expect(controller.featuredMovies.map((item) => item.id), [
      'm3',
      'm2',
      'm1',
    ]);
  });

  test('backfills metadata rows when no direct genre matches exist', () async {
    catalogRepository.items.addAll([
      movie(id: 'm1', title: 'One', rating: 8.0),
      movie(id: 'm2', title: 'Two', rating: 7.5),
      movie(id: 'm3', title: 'Three', rating: 7.0),
      movie(id: 'm4', title: 'Four', rating: 6.5),
    ]);

    final controller = buildController();
    await pumpLoad(controller);

    expect(controller.mysteryThrillerMovies, isNotEmpty);
    expect(controller.romanticComedyMovies, isNotEmpty);
    expect(controller.topRatedMovies, isNotEmpty);
  });

  test(
    'uses recent movies for new this week and backfills when needed',
    () async {
      final now = DateTime(2026, 8, 13);
      catalogRepository.items.addAll([
        movie(
          id: 'm1',
          title: 'Fresh',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        movie(
          id: 'm2',
          title: 'Older One',
          createdAt: now.subtract(const Duration(days: 20)),
        ),
        movie(
          id: 'm3',
          title: 'Older Two',
          createdAt: now.subtract(const Duration(days: 30)),
        ),
      ]);

      final controller = buildController();
      await pumpLoad(controller);

      expect(controller.newThisWeekMovies, isNotEmpty);
      expect(controller.newThisWeekMovies.first.id, 'm1');
    },
  );

  test('marks a movie playable when metadata contains a stream url', () {
    final controller = buildController();
    final item = movie(
      id: 'm1',
      title: 'Playable',
      metadata: {'streamUrl': 'http://example.com/movie.m3u8'},
    );

    expect(controller.canOpenMovie(item), isTrue);
  });

  test('marks a movie unavailable when stream metadata is missing', () {
    final controller = buildController();
    final item = movie(id: 'm1', title: 'Unavailable');

    expect(controller.canOpenMovie(item), isFalse);
  });
}
