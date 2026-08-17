import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import '../../../data/models/category.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/channel.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';

class LiveTVHomeController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;
  final FavoriteRepository? favoriteRepository;
  StreamSubscription? _catalogSubscription;

  LiveTVHomeController({
    required this.mediaEngine,
    required this.mediaLibrary,
    required this.catalogRepository,
    this.favoriteRepository,
  });

  final RxList<MediaItem> recentlyAdded = <MediaItem>[].obs;
  final RxList<MediaItem> favoriteChannels = <MediaItem>[].obs;
  final RxList<MediaItem> liveNow = <MediaItem>[].obs;
  final RxList<MediaItem> recentlyViewed = <MediaItem>[].obs;
  final RxList<Category> categories = <Category>[].obs;
  final RxList<MediaItem> continueWatching = <MediaItem>[].obs;

  final RxBool isLoading = false.obs;
  final RxString selectedProviderFilter = ''.obs;
  final RxString selectedCategoryFilter = ''.obs;
  final RxString selectedSort = 'alphabetical'.obs;

  @override
  void onInit() {
    super.onInit();
    _loadHomeData();
    _catalogSubscription = catalogRepository.watchUpdates().listen((_) => refresh());
  }

  @override
  void onClose() {
    _catalogSubscription?.cancel();
    super.onClose();
  }

  Future<void> _loadHomeData() async {
    isLoading.value = true;
    try {
      final favList = await favoriteRepository?.getAll() ?? [];
      final favIds = favList.map((e) => e.id).toSet();

      final allItems = await catalogRepository.getAllItems();
      final channelItems = allItems
          .where((item) => item.mediaType == MediaType.channel)
          .map((item) => item.copyWith(favorite: favIds.contains(item.id)))
          .toList();

      recentlyAdded.assignAll(
        channelItems.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      );

      favoriteChannels.assignAll(
        channelItems.where((item) => item.favorite).toList(),
      );

      liveNow.assignAll(
        channelItems
            .where((item) => item is Channel && item.isLive)
            .toList(),
      );

      recentlyViewed.assignAll(
        channelItems.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      );

      categories.assignAll(_buildCategories(channelItems));

      continueWatching.assignAll([]);
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }

  List<Category> _buildCategories(List<MediaItem> items) {
    final groupByCategory = <String, List<MediaItem>>{};
    for (final item in items) {
      for (final genre in item.genres) {
        groupByCategory.putIfAbsent(genre, () => []).add(item);
      }
    }
    return groupByCategory.entries.map((entry) {
      return Category(
        id: entry.key.toLowerCase().replaceAll(' ', '_'),
        name: entry.key,
        channelIds: entry.value.map((item) => item.id).toList(),
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
    }).toList();
  }

  void setProviderFilter(String providerType) {
    selectedProviderFilter.value = providerType;
  }

  void setCategoryFilter(String category) {
    selectedCategoryFilter.value = category;
  }

  void setSort(String sort) {
    selectedSort.value = sort;
  }

  List<MediaItem> getFilteredChannels() {
    var items = List<MediaItem>.from(recentlyAdded);
    if (selectedProviderFilter.value.isNotEmpty) {
      items = items
          .where((item) =>
              item.providerType.name == selectedProviderFilter.value)
          .toList();
    }
    if (selectedCategoryFilter.value.isNotEmpty) {
      items = items
          .where((item) => item.genres.contains(selectedCategoryFilter.value))
          .toList();
    }
    switch (selectedSort.value) {
      case 'alphabetical':
        items.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'recentlyAdded':
        items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case 'provider':
        items.sort((a, b) =>
            a.providerType.name.compareTo(b.providerType.name));
        break;
      case 'country':
        items.sort((a, b) =>
            (a.country ?? '').compareTo(b.country ?? ''));
        break;
    }
    return items;
  }

  Future<void> toggleFavorite(MediaItem item) async {
    if (favoriteRepository == null) {
      _loadHomeData();
      return;
    }
    if (item.favorite) {
      await favoriteRepository!.remove(item.id);
    } else {
      await favoriteRepository!.add(item.copyWith(favorite: true));
    }
    await _loadHomeData();
  }

  @override
  void refresh() {
    _loadHomeData();
  }
}
