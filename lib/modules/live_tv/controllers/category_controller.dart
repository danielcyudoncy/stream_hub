import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import '../../../data/models/category.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';

class CategoryController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;
  StreamSubscription? _catalogSubscription;

  CategoryController({
    required this.mediaEngine,
    required this.mediaLibrary,
    required this.catalogRepository,
  });

  final RxList<Category> categories = <Category>[].obs;
  final RxList<MediaItem> selectedCategoryChannels = <MediaItem>[].obs;
  final RxString selectedCategoryId = ''.obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadCategories();
    _catalogSubscription = catalogRepository.watchUpdates().listen((_) => refresh());
  }

  @override
  void onClose() {
    _catalogSubscription?.cancel();
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
        selectCategory(categories.first.id);
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
      final allItems = await catalogRepository.getAllItems();
      selectedCategoryChannels.assignAll(
        allItems.where((item) => item.genres.contains(category.name)).toList(),
      );
    } else {
      selectedCategoryChannels.clear();
    }
  }

  @override
  void refresh() {
    _loadCategories();
  }
}
