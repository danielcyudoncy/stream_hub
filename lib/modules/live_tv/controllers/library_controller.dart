import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/channel.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';

class LibraryController extends GetxController {
  final MediaEngine _mediaEngine;
  final MediaLibrary _mediaLibrary;
  final CatalogRepository _catalogRepository;

  LibraryController({
    required MediaEngine mediaEngine,
    required MediaLibrary mediaLibrary,
    required CatalogRepository catalogRepository,
  })  : _mediaEngine = mediaEngine,
        _mediaLibrary = mediaLibrary,
        _catalogRepository = catalogRepository;

  final RxList<MediaItem> allItems = <MediaItem>[].obs;
  final RxList<MediaItem> channels = <MediaItem>[].obs;
  final RxList<MediaItem> movies = <MediaItem>[].obs;
  final RxList<MediaItem> series = <MediaItem>[].obs;
  final RxList<MediaItem> liveTV = <MediaItem>[].obs;
  final RxList<MediaItem> recentlyAdded = <MediaItem>[].obs;
  final RxList<MediaItem> favorites = <MediaItem>[].obs;
  final RxList<MediaItem> history = <MediaItem>[].obs;
  final RxString selectedFilter = 'all'.obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    isLoading.value = true;
    try {
      final allItems = await _catalogRepository.getAllItems();
      this.allItems.assignAll(allItems);

      channels.assignAll(
        allItems
            .where((item) => item.mediaType == MediaType.channel)
            .toList(),
      );
      movies.assignAll(
        allItems.where((item) => item.mediaType == MediaType.movie).toList(),
      );
      series.assignAll(
        allItems
            .where((item) => item.mediaType == MediaType.series)
            .toList(),
      );
      liveTV.assignAll(
        allItems
            .where(
              (item) =>
                  (item is Channel ? (item as Channel).isLive : false) &&
                  item.mediaType == MediaType.channel,
            )
            .toList(),
      );

      final sorted = List<MediaItem>.from(allItems)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      recentlyAdded.assignAll(sorted.take(50));

      favorites.assignAll(
        allItems.where((item) => item.favorite).toList(),
      );

      history.assignAll([]);
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
  }

  List<MediaItem> getFilteredItems() {
    switch (selectedFilter.value) {
      case 'channels':
        return channels;
      case 'movies':
        return movies;
      case 'series':
        return series;
      case 'live':
        return liveTV;
      case 'favorites':
        return favorites;
      case 'recent':
        return recentlyAdded;
      default:
        return allItems;
    }
  }

  void refresh() {
    _loadLibrary();
  }

  @override
  void onClose() {
    super.onClose();
  }
}