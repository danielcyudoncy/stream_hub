import 'dart:async';

import 'package:get/get.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../data/models/curated_genre.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import '../../../data/repositories/media_source_repository.dart';
import '../../../data/repositories/provider_repository.dart';

class HomeController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;
  final HistoryRepository historyRepository;
  final FavoriteRepository favoriteRepository;
  final MediaSourceRepository mediaSourceRepository;
  StreamSubscription? _catalogSubscription;

  HomeController({
    required this.mediaEngine,
    required this.mediaLibrary,
    required this.catalogRepository,
    required this.historyRepository,
    required this.favoriteRepository,
    required this.mediaSourceRepository,
  });

  final RxInt selectedIndex = 0.obs;
  final RxInt providerCount = 0.obs;
  final RxBool isLoading = true.obs;
  final RxBool hasProviders = false.obs;

  final RxList<MediaItem> featuredHeroItems = <MediaItem>[].obs;
  final RxList<MediaItem> continueWatching = <MediaItem>[].obs;
  final RxList<MediaItem> liveChannels = <MediaItem>[].obs;
  final RxList<MediaItem> movies = <MediaItem>[].obs;
  final RxList<MediaItem> series = <MediaItem>[].obs;
  final RxList<MediaItem> favorites = <MediaItem>[].obs;
  final RxList<MediaItem> recentlyAdded = <MediaItem>[].obs;
  final RxList<MediaItem> recentlyPlayed = <MediaItem>[].obs;
  final RxList<MediaItem> downloads = <MediaItem>[].obs;
  final RxList<CuratedGenre> availableGenres = CuratedGenre.defaultGenres.obs;

  StreamSubscription? _favoriteSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadHomeData();
    _catalogSubscription = catalogRepository.watchUpdates().listen((_) => refresh());
    _favoriteSubscription = favoriteRepository.watchUpdates().listen((_) => _syncFavorites());
  }

  Future<void> _syncFavorites() async {
    final favItems = await favoriteRepository.getAll();
    final favIds = favItems.map((f) => f.id).toSet();
    final allItems = await catalogRepository.getAllItems();
    favorites.assignAll(
      allItems.where((item) => favIds.contains(item.id) || item.favorite).toList(),
    );
  }

  @override
  void onClose() {
    _catalogSubscription?.cancel();
    _favoriteSubscription?.cancel();
    super.onClose();
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  bool get hasContent =>
      featuredHeroItems.isNotEmpty ||
      liveChannels.isNotEmpty ||
      movies.isNotEmpty ||
      series.isNotEmpty ||
      continueWatching.isNotEmpty ||
      favorites.isNotEmpty ||
      recentlyAdded.isNotEmpty;

  Future<void> preloadHomeData() async {
    await _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    if (!hasContent) {
      isLoading.value = true;
    }
    try {
      await _loadProviders();
      await _loadDashboardData();
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadProviders() async {
    final providers = await mediaSourceRepository.getAll();
    final providerRepo = Get.isRegistered<ProviderRepository>()
        ? Get.find<ProviderRepository>()
        : null;
    final storedProviders = providerRepo != null
        ? await providerRepo.getAllProviders()
        : [];
    final allItems = await catalogRepository.getAllItems();

    final count = providers.length > storedProviders.length
        ? providers.length
        : storedProviders.length;
    providerCount.value = count;
    hasProviders.value = count > 0 || allItems.isNotEmpty;
  }

  Future<void> _loadDashboardData() async {
    try {
      final allItems = await catalogRepository.getAllItems();

      final channelItems = allItems
          .where((item) => item.mediaType == MediaType.channel)
          .toList();

      final movieItems = allItems
          .where((item) => item.mediaType == MediaType.movie)
          .toList();

      final seriesItems = allItems
          .where((item) => item.mediaType == MediaType.series)
          .toList();

      liveChannels.assignAll(channelItems);

      final sortedMovies = movieItems.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      movies.assignAll(sortedMovies);

      final sortedSeries = seriesItems.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      series.assignAll(sortedSeries);

      final vodItems = [...movieItems, ...seriesItems];
      final recentlyAddedList = vodItems.isNotEmpty
          ? (vodItems..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
          : (allItems.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
      recentlyAdded.assignAll(recentlyAddedList.take(20));

      final favItems = await favoriteRepository.getAll();
      final favIds = favItems.map((f) => f.id).toSet();
      favorites.assignAll(
        allItems.where((item) => favIds.contains(item.id) || item.favorite).toList(),
      );

      final history = await historyRepository.getRecent(limit: 20);
      recentlyPlayed.assignAll(history);
      continueWatching.assignAll(history);

      availableGenres.assignAll(CuratedGenre.defaultGenres);

      // Select featured items for Hero Carousel (rated items first, then recent items)
      _computeFeaturedHero(sortedMovies, sortedSeries, allItems);
    } catch (e) {
      // Log error
    }
  }

  void _computeFeaturedHero(
    List<MediaItem> movieItems,
    List<MediaItem> seriesItems,
    List<MediaItem> allItems,
  ) {
    final candidates = <MediaItem>[...movieItems, ...seriesItems];
    if (candidates.isEmpty) {
      candidates.addAll(allItems);
    }

    if (candidates.isEmpty) {
      featuredHeroItems.clear();
      return;
    }

    // Prefer items with rating and backdrop/poster
    final ratedWithArtwork = candidates
        .where((item) =>
            item.rating != null &&
            item.rating! > 0 &&
            ((item.backdrop != null && item.backdrop!.isNotEmpty) ||
                (item.poster != null && item.poster!.isNotEmpty)))
        .toList()
      ..sort((a, b) {
        final ratingCmp = (b.rating ?? 0).compareTo(a.rating ?? 0);
        if (ratingCmp != 0) return ratingCmp;
        return b.updatedAt.compareTo(a.updatedAt);
      });

    final fallbackWithArtwork = candidates
        .where((item) =>
            (item.backdrop != null && item.backdrop!.isNotEmpty) ||
            (item.poster != null && item.poster!.isNotEmpty))
        .toList();

    final result = <MediaItem>[];
    final seen = <String>{};

    for (final item in [...ratedWithArtwork, ...fallbackWithArtwork, ...candidates]) {
      if (result.length >= 5) break;
      if (seen.add(item.id)) {
        result.add(item);
      }
    }

    featuredHeroItems.assignAll(result);
  }

  bool isItemFavorite(String itemId) {
    return favorites.any((item) => item.id == itemId);
  }

  Future<void> toggleFavorite(MediaItem item) async {
    final isFav = isItemFavorite(item.id);
    if (isFav) {
      await favoriteRepository.remove(item.id);
      favorites.removeWhere((i) => i.id == item.id);
    } else {
      await favoriteRepository.add(item);
      if (!favorites.any((i) => i.id == item.id)) {
        favorites.add(item.copyWith(favorite: true));
      }
    }
  }

  @override
  Future<void> refresh() async {
    await _loadHomeData();
  }
}
