import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import '../../../data/models/category.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import '../../../data/services/database_service.dart';
import '../../../data/services/catalog_refresh_coordinator.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';
import 'live_tv_controller.dart';
import '../../movies/movies_controller.dart';
import '../../series/series_controller.dart';

enum CategorySortOption {
  nameAsc,
  nameDesc,
  countDesc,
  countAsc,
  visibleFirst,
  hiddenFirst;

  String get label {
    switch (this) {
      case CategorySortOption.nameAsc:
        return 'Name (A-Z)';
      case CategorySortOption.nameDesc:
        return 'Name (Z-A)';
      case CategorySortOption.countDesc:
        return 'Count: High to Low';
      case CategorySortOption.countAsc:
        return 'Count: Low to High';
      case CategorySortOption.visibleFirst:
        return 'Visible First';
      case CategorySortOption.hiddenFirst:
        return 'Hidden First';
    }
  }

  IconData get icon {
    switch (this) {
      case CategorySortOption.nameAsc:
      case CategorySortOption.nameDesc:
        return Icons.sort_by_alpha_rounded;
      case CategorySortOption.countDesc:
        return Icons.arrow_downward_rounded;
      case CategorySortOption.countAsc:
        return Icons.arrow_upward_rounded;
      case CategorySortOption.visibleFirst:
        return Icons.visibility_rounded;
      case CategorySortOption.hiddenFirst:
        return Icons.visibility_off_rounded;
    }
  }
}

class CategoryController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;
  final FavoriteRepository? favoriteRepository;

  StreamSubscription? _catalogSubscription;
  StreamSubscription? _favoriteSubscription;

  CategoryController({
    required this.mediaEngine,
    required this.mediaLibrary,
    required this.catalogRepository,
    this.favoriteRepository,
  });

  final RxList<Category> categories = <Category>[].obs;
  final RxList<MediaItem> selectedCategoryChannels = <MediaItem>[].obs;
  final RxString selectedCategoryId = ''.obs;
  final RxString searchQuery = ''.obs;
  final RxString filterTab = 'all'.obs; // 'all', 'visible', 'hidden'
  final Rx<MediaType> selectedMediaType = MediaType.channel.obs;
  final Rx<CategorySortOption> sortOption = CategorySortOption.nameAsc.obs;
  final RxSet<String> hiddenCategories = <String>{}.obs;
  final RxSet<String> hiddenChannels = <String>{}.obs;
  final RxBool isLoading = false.obs;

  List<Category> get filteredCategories {
    final query = searchQuery.value.trim().toLowerCase();
    final list = categories.where((c) {
      if (query.isNotEmpty && !c.name.toLowerCase().contains(query)) {
        return false;
      }
      final hidden = isCategoryHidden(c.id);
      if (filterTab.value == 'visible') {
        return !hidden;
      }
      if (filterTab.value == 'hidden') {
        return hidden;
      }
      return true;
    }).toList();

    _applySort(list);
    return list;
  }

  int get visibleCategoriesCount =>
      categories.where((c) => !isCategoryHidden(c.id)).length;

  int get hiddenCategoriesCount =>
      categories.where((c) => isCategoryHidden(c.id)).length;

  int get totalItemsCount {
    var count = 0;
    for (final c in categories) {
      count += c.channelCount;
    }
    return count;
  }

  void clearSelection() {
    selectedCategoryId.value = '';
    selectedCategoryChannels.clear();
  }

  bool isCategoryHidden(String idOrName) {
    final cat = categories.firstWhereOrNull(
      (c) => c.id == idOrName || c.name.toLowerCase() == idOrName.toLowerCase(),
    );
    if (hiddenCategories.contains(idOrName)) return true;
    if (cat != null) {
      if (hiddenCategories.contains(cat.id)) return true;
      if (hiddenCategories.contains(cat.name)) return true;
      if (hiddenCategories.contains(cat.name.toLowerCase().replaceAll(' ', '_'))) {
        return true;
      }
      if (hiddenCategories.contains(cat.name.trim())) return true;
    }
    return false;
  }

  void toggleCategoryVisibility(String categoryId) {
    final cat = categories.firstWhereOrNull((c) => c.id == categoryId);
    final currentlyHidden = isCategoryHidden(categoryId);

    if (currentlyHidden) {
      hiddenCategories.remove(categoryId);
      if (cat != null) {
        hiddenCategories.remove(cat.id);
        hiddenCategories.remove(cat.name);
        hiddenCategories.remove(cat.name.toLowerCase().replaceAll(' ', '_'));
        hiddenCategories.remove(cat.name.trim());
      }
    } else {
      hiddenCategories.add(categoryId);
      if (cat != null) {
        hiddenCategories.add(cat.id);
        hiddenCategories.add(cat.name);
        hiddenCategories.add(cat.name.toLowerCase().replaceAll(' ', '_'));
      }
    }
    _saveHiddenState();
    _notifyOtherControllers();
    categories.refresh();
  }

  void hideAll() {
    for (final c in categories) {
      hiddenCategories.add(c.id);
      hiddenCategories.add(c.name);
      hiddenCategories.add(c.name.toLowerCase().replaceAll(' ', '_'));
    }
    _saveHiddenState();
    _notifyOtherControllers();
    categories.refresh();
  }

  void showAll() {
    for (final c in categories) {
      hiddenCategories.remove(c.id);
      hiddenCategories.remove(c.name);
      hiddenCategories.remove(c.name.toLowerCase().replaceAll(' ', '_'));
      hiddenCategories.remove(c.name.trim());
    }
    _saveHiddenState();
    _notifyOtherControllers();
    categories.refresh();
  }

  bool isChannelHidden(String channelId) =>
      hiddenChannels.contains(channelId);

  void toggleChannelVisibility(String channelId) {
    if (hiddenChannels.contains(channelId)) {
      hiddenChannels.remove(channelId);
    } else {
      hiddenChannels.add(channelId);
    }
    _saveHiddenState();
    _notifyOtherControllers();
  }

  void setMediaType(MediaType type) {
    if (selectedMediaType.value == type) return;
    selectedMediaType.value = type;
    clearSelection();
    _loadCategories();
  }

  void setSortOption(CategorySortOption option) {
    sortOption.value = option;
    _applySort(categories);
    categories.refresh();
  }

  void _applySort(List<Category> list) {
    switch (sortOption.value) {
      case CategorySortOption.nameAsc:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case CategorySortOption.nameDesc:
        list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case CategorySortOption.countDesc:
        list.sort((a, b) {
          final cmp = b.channelCount.compareTo(a.channelCount);
          return cmp != 0 ? cmp : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case CategorySortOption.countAsc:
        list.sort((a, b) {
          final cmp = a.channelCount.compareTo(b.channelCount);
          return cmp != 0 ? cmp : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case CategorySortOption.visibleFirst:
        list.sort((a, b) {
          final aHidden = isCategoryHidden(a.id);
          final bHidden = isCategoryHidden(b.id);
          if (aHidden != bHidden) {
            return aHidden ? 1 : -1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case CategorySortOption.hiddenFirst:
        list.sort((a, b) {
          final aHidden = isCategoryHidden(a.id);
          final bHidden = isCategoryHidden(b.id);
          if (aHidden != bHidden) {
            return aHidden ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
    }
  }

  void _loadHiddenState() {
    try {
      if (Get.isRegistered<DatabaseService>()) {
        final db = Get.find<DatabaseService>();
        final savedCategories = db.settingsBox.get('hidden_categories');
        if (savedCategories is List) {
          hiddenCategories.assignAll(savedCategories.cast<String>());
        }
        final savedChannels = db.settingsBox.get('hidden_channels');
        if (savedChannels is List) {
          hiddenChannels.assignAll(savedChannels.cast<String>());
        }
      }
    } catch (_) {}
  }

  void _saveHiddenState() {
    try {
      if (Get.isRegistered<DatabaseService>()) {
        final db = Get.find<DatabaseService>();
        db.settingsBox.put('hidden_categories', hiddenCategories.toList());
        db.settingsBox.put('hidden_channels', hiddenChannels.toList());
      }
    } catch (_) {}
  }

  void _notifyOtherControllers() {
    if (Get.isRegistered<LiveTVController>()) {
      Get.find<LiveTVController>().refresh();
    }
    if (Get.isRegistered<MoviesController>()) {
      Get.find<MoviesController>().refresh();
    }
    if (Get.isRegistered<SeriesController>()) {
      Get.find<SeriesController>().refresh();
    }
  }

  @override
  void onInit() {
    super.onInit();
    _loadHiddenState();
    _loadCategories();
    _subscribeToCatalogUpdates();
    if (favoriteRepository != null) {
      _favoriteSubscription = favoriteRepository!.watchUpdates().listen((_) {
        if (selectedCategoryId.value.isNotEmpty) {
          selectCategory(selectedCategoryId.value);
        }
      });
    }
  }

  void _subscribeToCatalogUpdates() {
    if (Get.isRegistered<CatalogRefreshCoordinator>()) {
      final coordinator = Get.find<CatalogRefreshCoordinator>();
      _catalogSubscription = coordinator.refreshSignal.listen((_) {
        coordinator.runCoalesced(_loadCategories);
      });
    } else {
      _catalogSubscription = catalogRepository.watchUpdates().listen((_) {
        _loadCategories();
      });
    }
  }

  @override
  void onClose() {
    _catalogSubscription?.cancel();
    _favoriteSubscription?.cancel();
    super.onClose();
  }

  /// Ensures categories are loaded whenever page is opened or revisited
  Future<void> ensureCategoriesLoaded({bool force = false}) async {
    if (force || categories.isEmpty) {
      await _loadCategories();
    }
  }

  Set<String> _extractItemCategories(MediaItem item) {
    final result = <String>{};

    final catName = item.metadata['category_name']?.toString().trim();
    if (catName != null && catName.isNotEmpty) result.add(catName);

    final catNameAlt = item.metadata['categoryName']?.toString().trim();
    if (catNameAlt != null && catNameAlt.isNotEmpty) result.add(catNameAlt);

    final catMeta = item.metadata['category']?.toString().trim();
    if (catMeta != null && catMeta.isNotEmpty) result.add(catMeta);

    final groupTitle = item.metadata['groupTitle']?.toString().trim();
    if (groupTitle != null && groupTitle.isNotEmpty) result.add(groupTitle);

    final groupTitleAlt = item.metadata['group-title']?.toString().trim();
    if (groupTitleAlt != null && groupTitleAlt.isNotEmpty) result.add(groupTitleAlt);

    final genreMeta = item.metadata['genre']?.toString().trim();
    if (genreMeta != null && genreMeta.isNotEmpty) result.add(genreMeta);

    final catsMeta = item.metadata['categories'];
    if (catsMeta is List) {
      for (final c in catsMeta) {
        final str = c?.toString().trim();
        if (str != null && str.isNotEmpty) result.add(str);
      }
    }

    for (final g in item.genres) {
      final str = g.trim();
      if (str.isNotEmpty) result.add(str);
    }

    return result;
  }

  Future<void> _loadCategories() async {
    isLoading.value = true;
    try {
      final currentType = selectedMediaType.value;

      // 1. Fetch media items for current type
      List<MediaItem> mediaItems = await catalogRepository.getByType(currentType);
      if (mediaItems.isEmpty) {
        switch (currentType) {
          case MediaType.channel:
            mediaItems = mediaLibrary.getLiveTV();
            break;
          case MediaType.movie:
            mediaItems = mediaLibrary.getMovies();
            break;
          case MediaType.series:
            mediaItems = mediaLibrary.getSeries();
            break;
          default:
            mediaItems = mediaLibrary.getByType(currentType);
            break;
        }
      }

      // If still empty and channel was requested, also try all catalog items
      if (mediaItems.isEmpty && currentType == MediaType.channel) {
        final all = await catalogRepository.getAllItems();
        mediaItems = all.where((i) => i.mediaType == MediaType.channel).toList();
      }

      // 2. Fetch collection items from catalog & fallback to library
      List<MediaItem> rawCollections =
          await catalogRepository.getByType(MediaType.collection);
      if (rawCollections.isEmpty) {
        rawCollections = mediaLibrary.getCollections();
      }

      final relevantCollections = rawCollections.where((c) {
        if (currentType == MediaType.channel) {
          return c.id.startsWith('xtream-live-cat-') ||
              c.metadata['type'] == 'live' ||
              c.metadata['type'] == 'channel' ||
              (!c.id.startsWith('xtream-vod-cat-') &&
                  !c.id.startsWith('xtream-series-cat-') &&
                  c.metadata['type'] != 'movie' &&
                  c.metadata['type'] != 'series' &&
                  c.metadata['isVod'] != true);
        } else if (currentType == MediaType.movie) {
          return c.id.startsWith('xtream-vod-cat-') ||
              c.metadata['type'] == 'movie' ||
              c.metadata['type'] == 'vod' ||
              c.metadata['isVod'] == true;
        } else if (currentType == MediaType.series) {
          return c.id.startsWith('xtream-series-cat-') ||
              c.metadata['type'] == 'series';
        }
        return true;
      }).toList();

      // 3. Index items by category name and genreId
      final itemsByCategoryName = <String, List<MediaItem>>{};
      final itemsByGenreId = <String, List<MediaItem>>{};
      final uncategorizedItems = <MediaItem>[];

      for (final item in mediaItems) {
        final genreId = (item.metadata['genreId'] ??
                item.metadata['category_id'] ??
                item.metadata['categoryId'])
            ?.toString()
            .trim() ??
            '';
        if (genreId.isNotEmpty) {
          itemsByGenreId.putIfAbsent(genreId, () => []).add(item);
        }

        final catNames = _extractItemCategories(item);
        if (catNames.isEmpty) {
          uncategorizedItems.add(item);
        } else {
          for (final name in catNames) {
            itemsByCategoryName.putIfAbsent(name, () => []).add(item);
          }
        }
      }

      final categoryMap = <String, Category>{};

      // 4. Populate from collections
      for (final col in relevantCollections) {
        final name = col.title.trim();
        if (name.isEmpty) continue;
        final genreId = col.metadata['genreId']?.toString() ??
            col.metadata['category_id']?.toString() ??
            col.id;

        final matchingIds = <String>{};
        if (itemsByCategoryName.containsKey(name)) {
          matchingIds.addAll(itemsByCategoryName[name]!.map((e) => e.id));
        } else {
          for (final entry in itemsByCategoryName.entries) {
            if (entry.key.toLowerCase() == name.toLowerCase()) {
              matchingIds.addAll(entry.value.map((e) => e.id));
            }
          }
        }

        if (genreId.isNotEmpty && itemsByGenreId.containsKey(genreId)) {
          matchingIds.addAll(itemsByGenreId[genreId]!.map((e) => e.id));
        }

        final id = col.id.isNotEmpty
            ? col.id
            : name.toLowerCase().replaceAll(' ', '_');

        categoryMap[name] = Category(
          id: id,
          name: name,
          channelIds: matchingIds.toList(),
          updatedAt: col.updatedAt,
          createdAt: col.createdAt,
        );
      }

      // 5. Populate from discovered categories on items
      for (final entry in itemsByCategoryName.entries) {
        final name = entry.key;
        String? existingKey;
        for (final k in categoryMap.keys) {
          if (k.toLowerCase() == name.toLowerCase()) {
            existingKey = k;
            break;
          }
        }

        if (existingKey == null) {
          categoryMap[name] = Category(
            id: name.toLowerCase().replaceAll(' ', '_'),
            name: name,
            channelIds: entry.value.map((e) => e.id).toList(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        } else {
          final existing = categoryMap[existingKey]!;
          final mergedIds = <String>{
            ...existing.channelIds,
            ...entry.value.map((e) => e.id),
          }.toList();
          if (mergedIds.length != existing.channelIds.length) {
            categoryMap[existingKey] = existing.copyWith(channelIds: mergedIds);
          }
        }
      }

      // 6. Add Uncategorized if present and no categories
      if (uncategorizedItems.isNotEmpty && categoryMap.isEmpty) {
        categoryMap['Uncategorized'] = Category(
          id: 'uncategorized',
          name: 'Uncategorized',
          channelIds: uncategorizedItems.map((e) => e.id).toList(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      final sortedList = categoryMap.values.toList();
      _applySort(sortedList);
      categories.assignAll(sortedList);

      if (selectedCategoryId.value.isNotEmpty) {
        if (categories.any((c) => c.id == selectedCategoryId.value)) {
          selectCategory(selectedCategoryId.value);
        } else {
          clearSelection();
        }
      }
    } catch (e, stack) {
      debugPrint('CategoryController error loading categories: $e\n$stack');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> selectCategory(String categoryId) async {
    selectedCategoryId.value = categoryId;
    final category = categories.firstWhereOrNull((c) => c.id == categoryId);

    if (category != null && category.id.isNotEmpty) {
      final favList = await favoriteRepository?.getAll() ?? [];
      final favIds = favList.map((e) => e.id).toSet();

      List<MediaItem> allItems =
          await catalogRepository.getByType(selectedMediaType.value);
      if (allItems.isEmpty) {
        allItems = mediaLibrary.getByType(selectedMediaType.value);
      }

      final matched = allItems.where((item) {
        if (category.channelIds.contains(item.id)) return true;
        final cats = _extractItemCategories(item);
        if (cats.any((c) => c.toLowerCase() == category.name.toLowerCase())) {
          return true;
        }
        final genreId = (item.metadata['genreId'] ??
                item.metadata['category_id'] ??
                item.metadata['categoryId'])
            ?.toString();
        if (genreId != null && genreId == category.id) return true;
        return false;
      }).map((item) => item.copyWith(favorite: favIds.contains(item.id))).toList();

      selectedCategoryChannels.assignAll(matched);
    } else {
      selectedCategoryChannels.clear();
    }
  }

  Future<void> toggleFavorite(MediaItem item) async {
    if (favoriteRepository == null) return;
    final isFav = item.favorite;
    final updated = item.copyWith(favorite: !isFav);
    if (isFav) {
      await favoriteRepository!.remove(item.id);
    } else {
      await favoriteRepository!.add(updated);
    }
    final idx = selectedCategoryChannels.indexWhere((c) => c.id == item.id);
    if (idx != -1) {
      selectedCategoryChannels[idx] = updated;
    }
  }

  @override
  void refresh() {
    _loadCategories();
  }
}
