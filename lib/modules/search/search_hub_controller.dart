import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/history_repository.dart';

class SearchHubController extends GetxController {
  final CatalogRepository? _catalogRepository;
  final HistoryRepository? _historyRepository;

  final TextEditingController textController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  final RxString searchQuery = ''.obs;
  final RxBool isLoading = false.obs;
  final RxString selectedFilter = 'All'.obs;

  final RxList<MediaItem> allResults = <MediaItem>[].obs;
  final RxList<MediaItem> movieResults = <MediaItem>[].obs;
  final RxList<MediaItem> seriesResults = <MediaItem>[].obs;
  final RxList<MediaItem> channelResults = <MediaItem>[].obs;

  final RxList<String> recentSearches = <String>[].obs;
  final RxList<String> trendingSearches = <String>[].obs;
  final RxList<String> suggestions = <String>[].obs;

  Timer? _debounceTimer;

  SearchHubController({
    CatalogRepository? catalogRepository,
    HistoryRepository? historyRepository,
  })  : _catalogRepository = catalogRepository,
        _historyRepository = historyRepository;

  @override
  void onInit() {
    super.onInit();
    _loadSearchData();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    textController.dispose();
    searchFocusNode.dispose();
    super.onClose();
  }

  void _loadSearchData() {
    trendingSearches.assignAll([
      'Action',
      'Comedy',
      'Drama',
      'Sci-Fi',
      'Sports',
      'News',
      'Documentary',
      'Animation',
      'Thriller',
    ]);

    suggestions.assignAll([
      'Movies',
      'Series',
      'Live Sports',
      '4K Ultra HD',
      'Kids',
      'Trending Now',
    ]);
  }

  void onSearchChanged(String query) {
    _debounceTimer?.cancel();
    searchQuery.value = query;
    if (query.trim().isEmpty) {
      allResults.clear();
      movieResults.clear();
      seriesResults.clear();
      channelResults.clear();
      isLoading.value = false;
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      performSearch(query);
    });
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
  }

  void selectQuery(String query) {
    textController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    searchQuery.value = query;
    performSearch(query);
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    searchFocusNode.unfocus();
    textController.value = TextEditingValue.empty;
    searchQuery.value = '';
    allResults.clear();
    movieResults.clear();
    seriesResults.clear();
    channelResults.clear();
    isLoading.value = false;
  }

  Future<void> performSearch(String rawQuery) async {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) {
      allResults.clear();
      movieResults.clear();
      seriesResults.clear();
      channelResults.clear();
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    try {
      addRecentSearch(rawQuery.trim());
      _historyRepository?.recordSearch(rawQuery.trim());

      final repo = _catalogRepository ??
          (Get.isRegistered<CatalogRepository>()
              ? Get.find<CatalogRepository>()
              : null);

      if (repo == null) {
        isLoading.value = false;
        return;
      }

      final allItems = await repo.getAllItems();
      final matched = <MediaItem>[];

      for (final item in allItems) {
        final title = item.title.toLowerCase();
        final subtitle = item.subtitle?.toLowerCase() ?? '';
        final desc = item.description?.toLowerCase() ?? '';
        final inGenres = item.genres.any((g) => g.toLowerCase().contains(query));

        if (title.contains(query) ||
            subtitle.contains(query) ||
            inGenres ||
            desc.contains(query)) {
          matched.add(item);
          if (matched.length >= 200) break;
        }
      }

      allResults.assignAll(matched);
      movieResults.assignAll(
        matched.where((item) => item.mediaType == MediaType.movie).toList(),
      );
      seriesResults.assignAll(
        matched.where((item) => item.mediaType == MediaType.series).toList(),
      );
      channelResults.assignAll(
        matched
            .where((item) =>
                item.mediaType == MediaType.channel ||
                item.mediaType == MediaType.liveEvent ||
                item.mediaType == MediaType.program)
            .toList(),
      );
    } catch (_) {
      allResults.clear();
      movieResults.clear();
      seriesResults.clear();
      channelResults.clear();
    } finally {
      isLoading.value = false;
    }
  }

  List<MediaItem> get displayedResults {
    switch (selectedFilter.value) {
      case 'Movies':
        return movieResults;
      case 'Series':
        return seriesResults;
      case 'Live TV':
        return channelResults;
      case 'All':
      default:
        return allResults;
    }
  }

  void openItem(MediaItem item) {
    if (item.mediaType == MediaType.series) {
      Get.toNamed(
        AppRoutes.seriesDetails,
        arguments: {'item': item},
      );
    } else {
      Get.toNamed(
        AppRoutes.fullscreenPlayer,
        arguments: {
          'items': [item],
          'currentId': item.id,
        },
      );
    }
  }

  void addRecentSearch(String query) {
    if (query.trim().isEmpty) return;
    recentSearches.remove(query.trim());
    recentSearches.insert(0, query.trim());
    if (recentSearches.length > 10) {
      recentSearches.removeLast();
    }
  }

  void removeRecentSearch(String query) {
    recentSearches.remove(query);
  }

  void clearRecentSearches() {
    recentSearches.clear();
  }
}