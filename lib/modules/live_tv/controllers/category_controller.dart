import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import '../../../data/models/category.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import '../../../data/services/database_service.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';
import 'live_tv_controller.dart';

class CategoryController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;
  final FavoriteRepository? favoriteRepository;
  StreamSubscription? _catalogSubscription;

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
  final RxSet<String> hiddenCategories = <String>{}.obs;
  final RxSet<String> hiddenChannels = <String>{}.obs;
  final RxBool isLoading = true.obs;

  List<Category> get filteredCategories {
    final query = searchQuery.value.trim().toLowerCase();
    return categories.where((c) {
      if (query.isNotEmpty && !c.name.toLowerCase().contains(query)) {
        return false;
      }
      if (filterTab.value == 'visible') {
        return !hiddenCategories.contains(c.id);
      }
      if (filterTab.value == 'hidden') {
        return hiddenCategories.contains(c.id);
      }
      return true;
    }).toList();
  }

  int get visibleCategoriesCount =>
      categories.where((c) => !hiddenCategories.contains(c.id)).length;

  int get hiddenCategoriesCount =>
      categories.where((c) => hiddenCategories.contains(c.id)).length;

  void clearSelection() {
    selectedCategoryId.value = '';
    selectedCategoryChannels.clear();
  }

  bool isCategoryHidden(String categoryId) =>
      hiddenCategories.contains(categoryId);

  void toggleCategoryVisibility(String categoryId) {
    final cat = categories.firstWhereOrNull((c) => c.id == categoryId);
    if (hiddenCategories.contains(categoryId)) {
      hiddenCategories.remove(categoryId);
      if (cat != null) {
        hiddenCategories.remove(cat.name);
        hiddenCategories.remove(cat.name.toLowerCase().replaceAll(' ', '_'));
      }
    } else {
      hiddenCategories.add(categoryId);
      if (cat != null) {
        hiddenCategories.add(cat.name);
        hiddenCategories.add(cat.name.toLowerCase().replaceAll(' ', '_'));
      }
    }
    _saveHiddenState();
    if (Get.isRegistered<LiveTVController>()) {
      Get.find<LiveTVController>().refresh();
    }
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
    if (Get.isRegistered<LiveTVController>()) {
      Get.find<LiveTVController>().refresh();
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

  StreamSubscription? _favoriteSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadHiddenState();
    _loadCategories();
    _catalogSubscription =
        catalogRepository.watchUpdates().listen((_) => refresh());
    if (favoriteRepository != null) {
      _favoriteSubscription = favoriteRepository!.watchUpdates().listen((_) {
        if (selectedCategoryId.value.isNotEmpty) {
          selectCategory(selectedCategoryId.value);
        }
      });
    }
  }

  @override
  void onClose() {
    _catalogSubscription?.cancel();
    _favoriteSubscription?.cancel();
    super.onClose();
  }

  Future<void> _loadCategories() async {
    isLoading.value = true;
    try {
      final allItems = await catalogRepository.getAllItems();
      final channelItems = allItems
          .where((item) => item.mediaType == MediaType.channel)
          .toList();

      final categoryItems = allItems
          .where((item) =>
              item.mediaType == MediaType.collection &&
              (item.metadata['type'] == 'live' ||
                  item.metadata['type'] == null))
          .toList();

      // Index channels by genre name, genreId, and category title
      final channelsByGenreName = <String, List<MediaItem>>{};
      final channelsByGenreId = <String, List<MediaItem>>{};

      for (final item in channelItems) {
        final genreId = item.metadata['genreId']?.toString() ?? '';
        if (genreId.isNotEmpty) {
          channelsByGenreId.putIfAbsent(genreId, () => []).add(item);
        }
        for (final genre in item.genres) {
          if (genre.isNotEmpty) {
            channelsByGenreName.putIfAbsent(genre, () => []).add(item);
          }
        }
      }

      final categoryMap = <String, Category>{};

      // 1. Add all collection items from catalog (e.g. all 114 categories)
      for (final catItem in categoryItems) {
        final genreId = catItem.metadata['genreId']?.toString() ?? catItem.id;
        final name = catItem.title;
        if (name.isEmpty) continue;

        final matching = <String>{};
        if (channelsByGenreName.containsKey(name)) {
          matching.addAll(channelsByGenreName[name]!.map((e) => e.id));
        }
        if (genreId.isNotEmpty && channelsByGenreId.containsKey(genreId)) {
          matching.addAll(channelsByGenreId[genreId]!.map((e) => e.id));
        }

        final id = catItem.id.isNotEmpty
            ? catItem.id
            : name.toLowerCase().replaceAll(' ', '_');

        categoryMap[name] = Category(
          id: id,
          name: name,
          channelIds: matching.toList(),
          updatedAt: catItem.updatedAt,
          createdAt: catItem.createdAt,
        );
      }

      // 2. Add any additional genres found on channels
      for (final entry in channelsByGenreName.entries) {
        if (!categoryMap.containsKey(entry.key)) {
          categoryMap[entry.key] = Category(
            id: entry.key.toLowerCase().replaceAll(' ', '_'),
            name: entry.key,
            channelIds: entry.value.map((item) => item.id).toList(),
            updatedAt: DateTime.now(),
            createdAt: DateTime.now(),
          );
        }
      }

      final sortedCategories = categoryMap.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      categories.assignAll(sortedCategories);

      if (selectedCategoryId.value.isNotEmpty) {
        if (categories.any((c) => c.id == selectedCategoryId.value)) {
          selectCategory(selectedCategoryId.value);
        } else {
          clearSelection();
        }
      }
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> selectCategory(String categoryId) async {
    selectedCategoryId.value = categoryId;
    final category = categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => Category(
        id: '',
        name: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (category.id.isNotEmpty) {
      final favList = await favoriteRepository?.getAll() ?? [];
      final favIds = favList.map((e) => e.id).toSet();

      final allItems = await catalogRepository.getAllItems();
      selectedCategoryChannels.assignAll(
        allItems
            .where((item) =>
                item.mediaType == MediaType.channel &&
                (item.genres.contains(category.name) ||
                    item.metadata['genreId']?.toString() == category.id ||
                    item.metadata['genre']?.toString() == category.name ||
                    category.channelIds.contains(item.id)))
            .map((item) => item.copyWith(favorite: favIds.contains(item.id)))
            .toList(),
      );
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
