import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import '../../data/models/category.dart';
import '../../data/models/media_item.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../core/media/media_engine.dart';
import '../../core/media/media_library.dart';

class FavoritesController extends GetxController {
  final MediaEngine _mediaEngine;
  final MediaLibrary _mediaLibrary;
  final CatalogRepository _catalogRepository;

  FavoritesController({
    required MediaEngine mediaEngine,
    required MediaLibrary mediaLibrary,
    required CatalogRepository catalogRepository,
  })  : _mediaEngine = mediaEngine,
        _mediaLibrary = mediaLibrary,
        _catalogRepository = catalogRepository;

  final RxList<MediaItem> favoriteChannels = <MediaItem>[].obs;
  final RxList<MediaItem> recentlyViewed = <MediaItem>[].obs;
  final RxList<Category> favoriteCategories = <Category>[].obs;
  final RxBool isLoading = true.obs;
  final RxString sortBy = 'alphabetical'.obs;

  @override
  void onInit() {
    super.onInit();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    isLoading.value = true;
    try {
      final allItems = await _catalogRepository.getAllItems();
      final channelItems = allItems
          .where((item) => item.mediaType == MediaType.channel)
          .toList();

      favoriteChannels.assignAll(
        channelItems.where((item) => item.favorite).toList(),
      );
      favoriteChannels.sort(
          (a, b) => b.updatedAt.compareTo(a.updatedAt));

      final groupByCategory = <String, List<MediaItem>>{};
      for (final item in favoriteChannels) {
        for (final genre in item.genres) {
          groupByCategory.putIfAbsent(genre, () => []).add(item);
        }
      }

      favoriteCategories.assignAll(
        groupByCategory.entries.map((entry) {
          return Category(
            id: entry.key.toLowerCase().replaceAll(' ', '_'),
            name: entry.key,
            channelIds: entry.value.map((item) => item.id).toList(),
            isFavorite: true,
            updatedAt: DateTime.now(),
            createdAt: DateTime.now(),
          );
        }).toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
      );

      final sorted = List<MediaItem>.from(favoriteChannels)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      recentlyViewed.assignAll(sorted.take(20));
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }

  void toggleFavorite(MediaItem item) {
    if (item.favorite) {
      // Remove from favorites (placeholder - no active repository)
    } else {
      // Add to favorites (placeholder - no active repository)
    }
    _loadFavorites();
  }

  void setSort(String sort) {
    sortBy.value = sort;
    _sortFavorites();
  }

  void _sortFavorites() {
    switch (sortBy.value) {
      case 'alphabetical':
        favoriteChannels.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'recentlyAdded':
        favoriteChannels.sort(
            (a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'provider':
        favoriteChannels.sort((a, b) => (a.providerType?.displayName ?? '')
            .compareTo(b.providerType?.displayName ?? ''));
        break;
      case 'country':
        favoriteChannels.sort(
            (a, b) => (a.country ?? '').compareTo(b.country ?? ''));
        break;
    }
    favoriteChannels.refresh();
  }

  void refresh() {
    _loadFavorites();
  }

  @override
  void onClose() {
    super.onClose();
  }
}