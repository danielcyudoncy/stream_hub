import 'package:get/get.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';

class SeriesController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;

  SeriesController({
    required this.mediaEngine,
    required this.mediaLibrary,
    required this.catalogRepository,
  });

  final RxBool isLoading = true.obs;
  final RxList<MediaItem> series = <MediaItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    isLoading.value = true;
    try {
      final allItems = await catalogRepository.getAllItems();
      final seriesItems = allItems
          .where((item) => item.mediaType == MediaType.series)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      series.assignAll(seriesItems);
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<void> refresh() async {
    await _loadSeries();
  }
}
