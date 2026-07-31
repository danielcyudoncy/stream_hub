import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import '../../../data/models/category.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';

class FavoritesController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;
  final FavoriteRepository? favoriteRepository;

  FavoritesController({
    required this.mediaEngine,
    required this.mediaLibrary,
    required this.catalogRepository,
    this.favoriteRepository,
  });

  final RxList<MediaItem> favoriteChannels = <MediaItem>[].obs;
  final RxList<MediaItem> recentlyFavorited = <MediaItem>[].obs;
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
      final favItems = await favoriteRepository?.getAll() ?? [];
      final allItems = await catalogRepository.getAllItems();
      final channelItems = allItems
          .where((item) => item.mediaType == MediaType.channel)
          .toList();

      final favIds = favItems.map((f) => f.id).toSet();
      favoriteChannels.assignAll(
        channelItems.where((item) => favIds.contains(item.id)).toList(),
      );

      if (favoriteChannels.isNotEmpty) {
        favoriteChannels.sort(
            (a, b) => b.updatedAt.compareTo(a.updatedAt));
      }

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
      recentlyFavorited.assignAll(sorted.take(20));
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleFavorite(MediaItem item) async {
    if (favoriteRepository == null) return;
    if (item.favorite) {
      await favoriteRepository!.remove(item.id);
    } else {
      await favoriteRepository!.add(item);
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
        favoriteChannels.sort((a, b) => a.providerType.displayName
            .compareTo(b.providerType.displayName));
        break;
      case 'country':
        favoriteChannels.sort(
            (a, b) => (a.country ?? '').compareTo(b.country ?? ''));
        break;
    }
    favoriteChannels.refresh();
  }

  @override
  void refresh() {
    _loadFavorites();
  }
}
