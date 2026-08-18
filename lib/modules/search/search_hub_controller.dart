import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/curated_genre.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/provider_repository.dart';
import '../provider_manager/models/provider_model.dart';

class SearchHubController extends GetxController {
  final CatalogRepository? _catalogRepository;
  final HistoryRepository? _historyRepository;
  final ProviderRepository? _providerRepository;

  final TextEditingController textController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  final RxString searchQuery = ''.obs;
  final RxBool isLoading = false.obs;
  final RxString selectedFilter = 'All'.obs;

  final RxList<ProviderModel> availableProviders = <ProviderModel>[].obs;
  final RxString selectedProviderId = 'all'.obs;
  final RxString selectedProviderName = 'All Providers'.obs;

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
    ProviderRepository? providerRepository,
  })  : _catalogRepository = catalogRepository,
        _historyRepository = historyRepository,
        _providerRepository = providerRepository;

  @override
  void onInit() {
    super.onInit();
    _loadSearchData();
    _loadProviders();
    _handleInitialArguments();
  }

  @override
  void onReady() {
    super.onReady();
    _loadProviders();
    _handleInitialArguments();
  }

  Future<void> _loadProviders() async {
    final repo = _providerRepository ??
        (Get.isRegistered<ProviderRepository>()
            ? Get.find<ProviderRepository>()
            : null);
    if (repo != null) {
      try {
        final providers = await repo.getAllProviders();
        availableProviders.assignAll(providers.where((p) => p.enabled).toList());
      } catch (_) {}
    }
  }

  void setProvider(String providerId, String providerName) {
    if (selectedProviderId.value == providerId) return;
    selectedProviderId.value = providerId;
    selectedProviderName.value = providerName;
    if (searchQuery.value.isNotEmpty) {
      performSearch(searchQuery.value);
    }
  }

  void _handleInitialArguments() {
    final args = Get.arguments;
    if (args is Map) {
      final initialQuery =
          args['query']?.toString() ?? args['genre']?.toString();
      if (initialQuery != null &&
          initialQuery.trim().isNotEmpty &&
          searchQuery.value != initialQuery.trim()) {
        selectQuery(initialQuery.trim());
      }
    } else if (args is String &&
        args.trim().isNotEmpty &&
        searchQuery.value != args.trim()) {
      selectQuery(args.trim());
    }
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
      'Sports',
      'Movies',
      'TV Series',
      'Documentary',
      'Kids & Family',
      'Music',
      'News',
      'Action',
      'Comedy',
      'Sci-Fi',
    ]);

    suggestions.assignAll([
      'Live Sports',
      'Premier League',
      'Discovery',
      'Cartoons',
      '4K Ultra HD',
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
    searchQuery.value = rawQuery.trim();
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

      final curatedGenre = CuratedGenre.findByQuery(query);
      final searchKeywords = curatedGenre != null
          ? <String>{
              query,
              ...curatedGenre.keywords.map((k) => k.toLowerCase()),
            }
          : <String>{query};

      for (final item in allItems) {
        if (selectedProviderId.value != 'all' &&
            item.providerId != selectedProviderId.value) {
          continue;
        }

        final title = item.title.toLowerCase();
        final subtitle = item.subtitle?.toLowerCase() ?? '';
        final desc = item.description?.toLowerCase() ?? '';
        final category =
            item.metadata['category_name']?.toString().toLowerCase() ??
            item.metadata['category']?.toString().toLowerCase() ??
            '';
        final genres = item.genres.map((g) => g.toLowerCase()).toList();

        var matches = false;
        for (final kw in searchKeywords) {
          if (title.contains(kw) ||
              subtitle.contains(kw) ||
              category.contains(kw) ||
              desc.contains(kw) ||
              genres.any((g) => g.contains(kw))) {
            matches = true;
            break;
          }
        }

        if (matches) {
          matched.add(item);
          if (matched.length >= 400) break;
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