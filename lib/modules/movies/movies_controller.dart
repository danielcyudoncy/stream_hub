import 'package:get/get.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';

class MoviesController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;

  MoviesController({
    required this.mediaEngine,
    required this.mediaLibrary,
    required this.catalogRepository,
  });

  final RxBool isLoading = true.obs;
  final RxList<MediaItem> movies = <MediaItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    isLoading.value = true;
    try {
      final allItems = await catalogRepository.getAllItems();
      final movieItems = allItems
          .where((item) => item.mediaType == MediaType.movie)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      movies.assignAll(movieItems);
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<void> refresh() async {
    await _loadMovies();
  }
}
