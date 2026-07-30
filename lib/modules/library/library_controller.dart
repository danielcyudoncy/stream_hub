import 'package:get/get.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/favorite_repository.dart';

class LibraryController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;
  final HistoryRepository historyRepository;
  final FavoriteRepository favoriteRepository;

  LibraryController({
    required this.mediaEngine,
    required this.mediaLibrary,
    required this.catalogRepository,
    required this.historyRepository,
    required this.favoriteRepository,
  });

  final RxBool isLoading = true.obs;
  final RxInt movieCount = 0.obs;
  final RxInt seriesCount = 0.obs;
  final RxInt favoriteCount = 0.obs;
  final RxInt downloadCount = 0.obs;

  final RxList<MediaItem> movies = <MediaItem>[].obs;
  final RxList<MediaItem> series = <MediaItem>[].obs;
  final RxList<MediaItem> favorites = <MediaItem>[].obs;
  final RxList<MediaItem> continueWatching = <MediaItem>[].obs;
  final RxList<MediaItem> downloads = <MediaItem>[].obs;
  final RxList<MediaItem> history = <MediaItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadLibraryData();
  }

  Future<void> _loadLibraryData() async {
    isLoading.value = true;
    try {
      final allItems = await catalogRepository.getAllItems();

      final movieItems = allItems
          .where((item) => item.mediaType == MediaType.movie)
          .toList();
      final seriesItems = allItems
          .where((item) => item.mediaType == MediaType.series)
          .toList();

      movies.assignAll(
        movieItems.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      );
      series.assignAll(
        seriesItems.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      );

      favorites.assignAll(
        allItems.where((item) => item.favorite).toList(),
      );

      continueWatching.assignAll(
        allItems.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      );

      movieCount.value = movies.length;
      seriesCount.value = series.length;
      favoriteCount.value = favorites.length;

      final historyItems = await historyRepository.getRecent(limit: 20);
      history.assignAll(historyItems);
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<void> refresh() async {
    await _loadLibraryData();
  }
}