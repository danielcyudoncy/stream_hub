import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import '../../../data/models/category.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';

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
  final RxBool isLoading = true.obs;

  StreamSubscription? _favoriteSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadCategories();
    _catalogSubscription = catalogRepository.watchUpdates().listen((_) => refresh());
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

      final groupByCategory = <String, List<MediaItem>>{};
      for (final item in channelItems) {
        for (final genre in item.genres) {
          groupByCategory.putIfAbsent(genre, () => []).add(item);
        }
      }

      categories.assignAll(
        groupByCategory.entries.map((entry) {
          return Category(
            id: entry.key.toLowerCase().replaceAll(' ', '_'),
            name: entry.key,
            channelIds: entry.value.map((item) => item.id).toList(),
            updatedAt: DateTime.now(),
            createdAt: DateTime.now(),
          );
        }).toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
      );

      if (categories.isNotEmpty) {
        if (selectedCategoryId.value.isEmpty ||
            !categories.any((c) => c.id == selectedCategoryId.value)) {
          selectCategory(categories.first.id);
        } else {
          selectCategory(selectedCategoryId.value);
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
            .where((item) => item.genres.contains(category.name))
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
