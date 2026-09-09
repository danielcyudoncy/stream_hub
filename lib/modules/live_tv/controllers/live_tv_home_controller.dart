import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import '../../../data/models/category.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/channel.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import '../../../data/services/catalog_refresh_coordinator.dart';
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
    _subscribeToCatalogUpdates();
  }

  void _subscribeToCatalogUpdates() {
    if (Get.isRegistered<CatalogRefreshCoordinator>()) {
      final coordinator = Get.find<CatalogRefreshCoordinator>();
      _catalogSubscription = coordinator.refreshSignal.listen((_) {
        coordinator.runCoalesced(_loadHomeData);
      });
    } else {
      _catalogSubscription = catalogRepository.watchUpdates().listen((_) {
        _loadHomeData();
      });
    }
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

      final channelItems = await catalogRepository.getByType(
        MediaType.channel,
      );
      final marked = favIds.isNotEmpty
          ? channelItems
              .map((item) => item.copyWith(favorite: favIds.contains(item.id)))
              .toList()
          : channelItems;

      final sorted = marked.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      recentlyAdded.assignAll(sorted);

      favoriteChannels.assignAll(
        sorted.where((item) => item.favorite).toList(),
      );

      liveNow.assignAll(
        sorted.where((item) => item is Channel && item.isLive).toList(),
      );

      recentlyViewed.assignAll(sorted);

      categories.assignAll(_buildCategories(sorted));

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
