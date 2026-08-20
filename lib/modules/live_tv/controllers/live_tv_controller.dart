import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/stream_resolver.dart';
import 'package:stream_hub/core/media/stream_resolvers/m3u_stream_resolver.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/channel.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';

class LiveTVController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;
  final FavoriteRepository? favoriteRepository;
  final StreamResolver streamResolver;
  StreamSubscription? _catalogSubscription;

  LiveTVController({
    required this.mediaEngine,
    required this.mediaLibrary,
    required this.catalogRepository,
    this.favoriteRepository,
    StreamResolver? streamResolver,
  }) : streamResolver = streamResolver ?? M3UStreamResolver();

  final List<MediaItem> _allChannels = <MediaItem>[];
  final List<MediaItem> _allCategories = <MediaItem>[];

  final RxList<MediaItem> channels = <MediaItem>[].obs;
  final RxList<MediaItem> filteredChannels = <MediaItem>[].obs;
  final RxList<MediaItem> favorites = <MediaItem>[].obs;
  final RxList<String> categories = <String>[].obs;
  final RxList<String> providers = <String>[].obs;
  final RxList<String> languages = <String>[].obs;
  final RxList<String> countries = <String>[].obs;
  final RxList<String> resolutions = <String>[].obs;

  final RxString selectedView = 'grid'.obs;
  final RxString selectedCategory = 'All Channels'.obs;
  final RxString selectedProvider = ''.obs;
  final RxString selectedLanguage = ''.obs;
  final RxString selectedCountry = ''.obs;
  final RxString selectedResolution = ''.obs;
  final RxString selectedSort = 'alphabetical'.obs;
  final RxString searchQuery = ''.obs;
  final RxBool showFavoritesOnly = false.obs;
  final RxBool showRecentlyAdded = false.obs;
  final RxBool isLoading = true.obs;
  final Rxn<MediaItem> featuredChannel = Rxn<MediaItem>();

  StreamSubscription? _favoriteSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadLiveTVData();
    _catalogSubscription = catalogRepository.watchUpdates().listen((_) => refresh());
    if (favoriteRepository != null) {
      _favoriteSubscription = favoriteRepository!.watchUpdates().listen((_) => _syncFavoritesFromRepo());
    }
  }

  Future<void> _syncFavoritesFromRepo() async {
    final favList = await favoriteRepository?.getAll() ?? [];
    final favIds = favList.map((f) => f.id).toSet();

    for (var i = 0; i < _allChannels.length; i++) {
      final item = _allChannels[i];
      final isFav = favIds.contains(item.id);
      if (item.favorite != isFav) {
        _allChannels[i] = item.copyWith(favorite: isFav);
      }
    }

    _updateCategoriesAndFilters(favIds);
  }

  @override
  void onClose() {
    _catalogSubscription?.cancel();
    _favoriteSubscription?.cancel();
    super.onClose();
  }

  Future<void> _loadLiveTVData() async {
    isLoading.value = true;
    try {
      final allItems = await catalogRepository.getAllItems();
      final liveChannels = allItems
          .where((item) => item.mediaType == MediaType.channel)
          .toList();

      final favList = await favoriteRepository?.getAll() ?? [];
      final favIds = favList.map((f) => f.id).toSet();

      final mappedChannels = liveChannels.map((item) {
        if (favIds.contains(item.id) || item.favorite) {
          return item.copyWith(favorite: true);
        }
        return item;
      }).toList();

      _allChannels
        ..clear()
        ..addAll(mappedChannels);

      final allCategories = await catalogRepository.getByType(MediaType.collection);
      _allCategories
        ..clear()
        ..addAll(allCategories);

      final providerSet = <String>{};
      for (final item in _allChannels) {
        if (item.providerId.isNotEmpty) {
          providerSet.add(item.providerId);
        }
        if (item.providerType.displayName.isNotEmpty) {
          providerSet.add(item.providerType.displayName);
        }
      }
      providers.assignAll(providerSet.toList()..sort());

      _updateCategoriesAndFilters(favIds);
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }

  void _updateCategoriesAndFilters([Set<String>? favIds]) {
    final activeChannels = selectedProvider.value.isEmpty
        ? List<MediaItem>.from(_allChannels)
        : _allChannels.where((item) {
            return item.providerId == selectedProvider.value ||
                item.providerType.displayName == selectedProvider.value ||
                item.providerType.name == selectedProvider.value;
          }).toList();

    channels.assignAll(activeChannels);

    if (activeChannels.isNotEmpty) {
      final currentFeatured = featuredChannel.value;
      if (currentFeatured == null ||
          !activeChannels.any((c) => c.id == currentFeatured.id)) {
        final liveCandidate =
            activeChannels.firstWhereOrNull((c) => c is Channel && c.isLive);
        featuredChannel.value = liveCandidate ?? activeChannels.first;
      }
    } else {
      featuredChannel.value = null;
    }

    final effectiveFavIds = favIds ??
        (favoriteRepository != null
            ? (favorites.map((f) => f.id).toSet())
            : <String>{});

    favorites.assignAll(
      activeChannels
          .where((item) =>
              effectiveFavIds.contains(item.id) || item.favorite)
          .toList(),
    );

    final languageSet = <String>{};
    final countrySet = <String>{};
    final resolutionSet = <String>{};
    final categorySet = <String>{};

    for (final item in activeChannels) {
      if (item.language != null && item.language!.isNotEmpty) {
        languageSet.add(item.language!);
      }
      if (item.country != null && item.country!.isNotEmpty) {
        countrySet.add(item.country!);
      }
      final res = item.metadata['resolution'] as String?;
      if (res != null && res.isNotEmpty) {
        resolutionSet.add(res);
      }
      for (final genre in item.genres) {
        if (genre.trim().isNotEmpty) categorySet.add(genre.trim());
      }
      final genreMeta = item.metadata['genre']?.toString();
      if (genreMeta != null && genreMeta.trim().isNotEmpty) {
        categorySet.add(genreMeta.trim());
      }
      final catMeta = item.metadata['category_name']?.toString();
      if (catMeta != null && catMeta.trim().isNotEmpty) {
        categorySet.add(catMeta.trim());
      }
    }

    for (final cat in _allCategories) {
      final isLive = cat.metadata['type'] == 'live' || cat.metadata['type'] == null;
      final matchesProvider = selectedProvider.value.isEmpty ||
          cat.providerId == selectedProvider.value ||
          cat.providerType.displayName == selectedProvider.value ||
          cat.providerType.name == selectedProvider.value;
      if (isLive && matchesProvider && cat.title.trim().isNotEmpty) {
        categorySet.add(cat.title.trim());
      }
    }

    final sortedCategories = categorySet.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    categories.assignAll(['All Channels', ...sortedCategories]);

    if (!categories.contains(selectedCategory.value)) {
      selectedCategory.value = 'All Channels';
    }

    languages.assignAll(languageSet.toList()..sort());
    countries.assignAll(countrySet.toList()..sort());
    resolutions.assignAll(resolutionSet.toList()..sort());

    _applyFilters();
  }

  void setView(String view) {
    selectedView.value = view;
  }

  void setCategory(String category) {
    selectedCategory.value = category;
    _applyFilters();
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
    _applyFilters();
  }

  void setFeaturedChannel(MediaItem channel) {
    featuredChannel.value = channel;
  }

  void setProvider(String provider) {
    if (selectedProvider.value == provider) return;
    selectedProvider.value = provider;
    selectedCategory.value = 'All Channels';
    _updateCategoriesAndFilters();
  }

  void setLanguage(String language) {
    selectedLanguage.value = language;
    _applyFilters();
  }

  void setCountry(String country) {
    selectedCountry.value = country;
    _applyFilters();
  }

  void setResolution(String resolution) {
    selectedResolution.value = resolution;
    _applyFilters();
  }

  void setSort(String sort) {
    selectedSort.value = sort;
    _applyFilters();
  }

  void setFavoritesOnly(bool value) {
    showFavoritesOnly.value = value;
    _applyFilters();
  }

  void setRecentlyAdded(bool value) {
    showRecentlyAdded.value = value;
    _applyFilters();
  }

  void _applyFilters() {
    var result = List<MediaItem>.from(channels);

    if (searchQuery.value.trim().isNotEmpty) {
      final q = searchQuery.value.trim().toLowerCase();
      result = result.where((item) {
        final titleMatch = item.title.toLowerCase().contains(q);
        final subtitleMatch = item.subtitle != null && item.subtitle!.toLowerCase().contains(q);
        final genreMatch = item.genres.any((g) => g.toLowerCase().contains(q));
        final numberMatch = item is Channel && item.number != null && item.number!.toLowerCase().contains(q);
        return titleMatch || subtitleMatch || genreMatch || numberMatch;
      }).toList();
    }

    if (selectedCategory.value != 'All Channels') {
      result = result
          .where((item) =>
              item.genres.contains(selectedCategory.value) ||
              item.metadata['genre'] == selectedCategory.value ||
              item.metadata['category_name'] == selectedCategory.value)
          .toList();
    }

    if (selectedProvider.value.isNotEmpty) {
      result = result
          .where((item) =>
              item.providerId == selectedProvider.value ||
              item.providerType.displayName == selectedProvider.value)
          .toList();
    }

    if (selectedLanguage.value.isNotEmpty) {
      result = result
          .where((item) => item.language == selectedLanguage.value)
          .toList();
    }

    if (selectedCountry.value.isNotEmpty) {
      result = result
          .where((item) => item.country == selectedCountry.value)
          .toList();
    }

    if (selectedResolution.value.isNotEmpty) {
      result = result
          .where((item) =>
              item.metadata['resolution'] == selectedResolution.value)
          .toList();
    }

    if (showFavoritesOnly.value) {
      final favIds = favorites.map((f) => f.id).toSet();
      result = result.where((item) => favIds.contains(item.id)).toList();
    }

    if (showRecentlyAdded.value) {
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    switch (selectedSort.value) {
      case 'alphabetical':
        result.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'recentlyAdded':
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'provider':
        result.sort((a, b) => a.providerType.displayName
            .compareTo(b.providerType.displayName));
        break;
      case 'country':
        result.sort((a, b) => (a.country ?? '').compareTo(b.country ?? ''));
        break;
    }

    filteredChannels.assignAll(result);
  }

  void openChannel(MediaItem channel) {
    final itemsToPass = filteredChannels.isNotEmpty
        ? filteredChannels.toList()
        : (channels.isNotEmpty ? channels.toList() : [channel]);
    Get.toNamed(
      AppRoutes.fullscreenPlayer,
      arguments: {
        'items': itemsToPass,
        'currentId': channel.id,
      },
    );
  }

  Future<void> toggleFavorite(MediaItem item) async {
    final isFav = favorites.any((f) => f.id == item.id) || item.favorite;
    final updatedItem = item.copyWith(favorite: !isFav);

    if (isFav) {
      favorites.removeWhere((f) => f.id == item.id);
      await favoriteRepository?.remove(item.id);
    } else {
      favorites.add(updatedItem);
      await favoriteRepository?.add(updatedItem);
    }

    // Update in channels and filteredChannels in-place without triggering full reload
    final channelIdx = channels.indexWhere((c) => c.id == item.id);
    if (channelIdx != -1) {
      channels[channelIdx] = updatedItem;
    }

    final filteredIdx = filteredChannels.indexWhere((c) => c.id == item.id);
    if (filteredIdx != -1) {
      filteredChannels[filteredIdx] = updatedItem;
    }

    if (featuredChannel.value?.id == item.id) {
      featuredChannel.value = updatedItem;
    }

    if (showFavoritesOnly.value) {
      _applyFilters();
    }
  }

  @override
  void refresh() {
    _loadLiveTVData();
  }
}
