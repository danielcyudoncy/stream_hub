import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/modules/series/series_genre_controller.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCatalogRepository catalogRepo;

  setUp(() {
    Get.testMode = true;
    catalogRepo = _FakeCatalogRepository();
  });

  tearDown(() {
    Get.reset();
  });

  MediaItem makeSeries({
    required String id,
    required String title,
    required List<String> genres,
    double rating = 8.0,
  }) {
    final now = DateTime.now();
    return MediaItem(
      id: id,
      providerId: 'prov-1',
      providerType: MediaSourceType.xtream,
      mediaType: MediaType.series,
      title: title,
      genres: genres,
      rating: rating,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('SeriesGenreController filters by genre and sorts', () async {
    catalogRepo.items.addAll([
      makeSeries(id: 's1', title: 'Dark', genres: ['Sci-Fi', 'Drama'], rating: 8.7),
      makeSeries(id: 's2', title: 'The Office', genres: ['Comedy'], rating: 8.9),
      makeSeries(id: 's3', title: 'Stranger Things', genres: ['Sci-Fi', 'Horror'], rating: 8.6),
    ]);

    final controller = SeriesGenreController(catalogRepository: catalogRepo);
    controller.genreName.value = 'Sci-Fi';
    await controller.loadGenreSeries();

    expect(controller.series.length, 2);
    expect(controller.series.first.title, 'Dark'); // 8.7 > 8.6

    controller.setSortBy('title');
    expect(controller.series.first.title, 'Dark');
    expect(controller.series.last.title, 'Stranger Things');
  });
}
