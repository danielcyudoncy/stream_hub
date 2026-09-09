import 'dart:async';
import 'dart:developer' as developer;

import 'package:get/get.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../data/models/curated_genre.dart';
import '../../../data/models/home_snapshot.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/playback_session_model.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import '../../../data/repositories/media_source_repository.dart';
import '../../../data/repositories/provider_repository.dart';
import '../../../core/media/repositories/playback_repository.dart';
import '../../../data/services/catalog_refresh_coordinator.dart';
import '../../../data/services/home_snapshot_service.dart';

enum SectionLoadState { idle, loading, loaded, error }

class HomeController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;
  final HistoryRepository historyRepository;
  final FavoriteRepository favoriteRepository;
  final MediaSourceRepository mediaSourceRepository;
  final HomeSnapshotService _snapshotService;

  StreamSubscription? _catalogSubscription;
  StreamSubscription? _favoriteSubscription;
  Timer? _backgroundRefreshTimer;

  HomeController({
    required this.mediaEngine,
    required this.mediaLibrary,
    required this.catalogRepository,
    required this.historyRepository,
    required this.favoriteRepository,
    required this.mediaSourceRepository,
    required HomeSnapshotService snapshotService,
  }) : _snapshotService = snapshotService;

  final RxInt selectedIndex = 0.obs;
  final RxInt providerCount = 0.obs;
  final RxString selectedProviderId = ''.obs;
  final RxBool isLoading = true.obs;
  final RxBool hasProviders = false.obs;
  final RxBool _hasLoadedFromCache = false.obs;

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

  final Rx<SectionLoadState> heroState = SectionLoadState.idle.obs;
  final Rx<SectionLoadState> moviesState = SectionLoadState.idle.obs;
  final Rx<SectionLoadState> seriesState = SectionLoadState.idle.obs;
  final Rx<SectionLoadState> channelsState = SectionLoadState.idle.obs;
  final Rx<SectionLoadState> continueWatchingState = SectionLoadState.idle.obs;
  final Rx<SectionLoadState> favoritesState = SectionLoadState.idle.obs;
  final Rx<SectionLoadState> recentlyAddedState = SectionLoadState.idle.obs;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<ProviderRepository>()) {
      final providerRepo = Get.find<ProviderRepository>();
      selectedProviderId.value = providerRepo.activeProviderId.value;
      ever(providerRepo.activeProviderId, (id) {
        if (selectedProviderId.value != id) {
          selectedProviderId.value = id;
          refresh();
        }
      });
    }
    _initializeHome();
    _subscribeToCatalogUpdates();
    _favoriteSubscription = favoriteRepository.watchUpdates().listen((_) {
      _refreshFavoritesOnly(selectedProviderId.value);
    });
  }

  CatalogRefreshCoordinator? get _catalogCoordinator =>
      Get.isRegistered<CatalogRefreshCoordinator>()
          ? Get.find<CatalogRefreshCoordinator>()
          : null;

  void _subscribeToCatalogUpdates() {
    final coordinator = _catalogCoordinator;
    if (coordinator != null) {
      _catalogSubscription = coordinator.refreshSignal.listen((_) {
        coordinator.runCoalesced(_refreshSectionsInBackground);
      });
    } else {
      _catalogSubscription = catalogRepository.watchUpdates().listen((_) {
        _refreshSectionsInBackground();
      });
    }
  }

  @override
  void onClose() {
    _catalogSubscription?.cancel();
    _favoriteSubscription?.cancel();
    _backgroundRefreshTimer?.cancel();
    super.onClose();
  }

  Future<void> _initializeHome() async {
    isLoading.value = true;
    try {
      await _loadProviders();
      final snapshot = await _snapshotService.load();
      if (snapshot != null && !snapshot.isEmpty) {
        _applySnapshot(snapshot);
        _hasLoadedFromCache.value = true;
        isLoading.value = false;
        _log('[HOME] Rendering cached snapshot');
        _startBackgroundRefresh();
      } else {
        _log('[HOME] No cache, loading from network');
        await _loadAllFromNetwork();
      }
    } catch (e) {
      _log('[HOME] Init error: $e');
      isLoading.value = false;
    }
  }

  void _applySnapshot(HomeSnapshot snapshot) {
    featuredHeroItems.assignAll(snapshot.featuredHeroItems);
    continueWatching.assignAll(snapshot.continueWatching);
    liveChannels.assignAll(snapshot.liveChannels);
    movies.assignAll(snapshot.movies);
    series.assignAll(snapshot.series);
    favorites.assignAll(snapshot.favorites);
    recentlyAdded.assignAll(snapshot.recentlyAdded);
    recentlyPlayed.assignAll(snapshot.recentlyPlayed);
    providerCount.value = snapshot.providerCount;
    hasProviders.value = snapshot.providerCount > 0 || hasContent;
  }

  HomeSnapshot _buildSnapshot() {
    return HomeSnapshot(
      featuredHeroItems: featuredHeroItems.toList(),
      continueWatching: continueWatching.toList(),
      liveChannels: liveChannels.toList(),
      movies: movies.toList(),
      series: series.toList(),
      favorites: favorites.toList(),
      recentlyAdded: recentlyAdded.toList(),
      recentlyPlayed: recentlyPlayed.toList(),
      providerCount: providerCount.value,
      cachedAt: DateTime.now(),
    );
  }

  void _startBackgroundRefresh() {
    _backgroundRefreshTimer?.cancel();
    _backgroundRefreshTimer = Timer(const Duration(seconds: 2), () {
      _refreshSectionsInBackground();
    });
  }

  String? _providerOrNull(String providerId) =>
      providerId.isEmpty ? null : providerId;

  bool _matchesProvider(MediaItem item, String providerId) {
    if (providerId.isEmpty) return true;
    return item.providerId == providerId ||
        item.metadata['providerId'] == providerId ||
        item.metadata['provider_id'] == providerId;
  }

  void setSelectedProvider(String providerId) {
    if (selectedProviderId.value == providerId) return;
    selectedProviderId.value = providerId;
    if (Get.isRegistered<ProviderRepository>()) {
      final providerRepo = Get.find<ProviderRepository>();
      if (providerRepo.activeProviderId.value != providerId) {
        providerRepo.setActiveProviderId(providerId);
      }
    }
    refresh();
  }

  Future<void> _refreshSectionsInBackground() async {
    _log('[HOME] Background refresh started');
    try {
      if (hasContent && providerCount.value == 0) {
        _log('[HOME] No providers yet, skipping refresh');
        return;
      }
      await _refreshSections();
      final snapshot = _buildSnapshot();
      if (!snapshot.isEmpty) {
        await _snapshotService.save(snapshot);
        _log('[HOME] Background refresh complete, snapshot saved');
      } else {
        _log('[HOME] Background refresh produced empty snapshot, skipping save');
      }
    } catch (e) {
      _log('[HOME] Background refresh error: $e');
    }
  }

  Future<void> _loadAllFromNetwork() async {
    try {
      await _refreshSections(assignGenres: true);
      final snapshot = _buildSnapshot();
      if (!snapshot.isEmpty) {
        await _snapshotService.save(snapshot);
      }
    } catch (e) {
      _log('[HOME] Network load error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _refreshSections({bool assignGenres = false}) async {
    final providerId = selectedProviderId.value;
    await Future.wait([
      _refreshHeroSection(providerId),
      _refreshMoviesSection(providerId),
      _refreshSeriesSection(providerId),
      _refreshChannelsSection(providerId),
    ]);
    await _refreshContinueWatching(providerId);
    await _refreshFavoritesOnly(providerId);
    await _refreshRecentlyAdded(providerId);
    await _refreshRecentlyPlayed();
    if (assignGenres) {
      availableGenres.assignAll(CuratedGenre.defaultGenres);
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
    final count = providers.length > storedProviders.length
        ? providers.length
        : storedProviders.length;
    providerCount.value = count;
    hasProviders.value = count > 0 || hasContent;
  }

  Future<void> _refreshHeroSection(String providerId) async {
    heroState.value = SectionLoadState.loading;
    try {
      final provider = _providerOrNull(providerId);
      final moviePool = await catalogRepository.topByUpdatedAt(
        MediaType.movie,
        providerId: provider,
        limit: 64,
      );
      final seriesPool = await catalogRepository.topByUpdatedAt(
        MediaType.series,
        providerId: provider,
        limit: 64,
      );
      List<MediaItem> result;
      if (moviePool.isEmpty && seriesPool.isEmpty) {
        final channelPool = provider != null
            ? await catalogRepository.getByProviderAndType(
                provider,
                MediaType.channel,
              )
            : await catalogRepository.getByType(MediaType.channel);
        result = _computeFeaturedFromChannels(channelPool);
      } else {
        result = _computeFeaturedFromVod(moviePool, seriesPool);
      }
      if (result.isNotEmpty && !_areMediaListsEqual(featuredHeroItems, result)) {
        featuredHeroItems.assignAll(result);
      }
      heroState.value = SectionLoadState.loaded;
    } catch (e) {
      heroState.value = SectionLoadState.error;
    }
  }

  Future<void> _refreshMoviesSection(String providerId) async {
    moviesState.value = SectionLoadState.loading;
    try {
      final newItems = await catalogRepository.topByUpdatedAt(
        MediaType.movie,
        providerId: _providerOrNull(providerId),
        limit: 20,
      );
      if (newItems.isNotEmpty && !_areMediaListsEqual(movies, newItems)) {
        movies.assignAll(newItems);
      }
      moviesState.value = SectionLoadState.loaded;
    } catch (e) {
      moviesState.value = SectionLoadState.error;
    }
  }

  Future<void> _refreshSeriesSection(String providerId) async {
    seriesState.value = SectionLoadState.loading;
    try {
      final newItems = await catalogRepository.topByUpdatedAt(
        MediaType.series,
        providerId: _providerOrNull(providerId),
        limit: 20,
      );
      if (newItems.isNotEmpty && !_areMediaListsEqual(series, newItems)) {
        series.assignAll(newItems);
      }
      seriesState.value = SectionLoadState.loaded;
    } catch (e) {
      seriesState.value = SectionLoadState.error;
    }
  }

  Future<void> _refreshChannelsSection(String providerId) async {
    channelsState.value = SectionLoadState.loading;
    try {
      final channelItems = providerId.isNotEmpty
          ? await catalogRepository.getByProviderAndType(
              providerId,
              MediaType.channel,
            )
          : await catalogRepository.getByType(MediaType.channel);
      if (channelItems.isEmpty) {
        if (liveChannels.isEmpty) {
          channelsState.value = SectionLoadState.loaded;
        }
        return;
      }

      // 1. Get favorite channel IDs
      final favItems = await favoriteRepository.getAll();
      final favIds = favItems.map((f) => f.id).toSet();

      // 2. Get recently played channels
      final recentHistory = await historyRepository.getRecent(limit: 20);
      final recentIds = recentHistory
          .where((i) => i.mediaType == MediaType.channel)
          .map((i) => i.id)
          .toSet();

      // 3. Curate prioritized channels:
      // Favorites -> Recent -> Categorized/Diversified Channels
      final favoritesList = <MediaItem>[];
      final recentsList = <MediaItem>[];
      final othersList = <MediaItem>[];
      final seenIds = <String>{};

      for (final item in channelItems) {
        if (favIds.contains(item.id) || item.favorite) {
          if (seenIds.add(item.id)) favoritesList.add(item);
        } else if (recentIds.contains(item.id)) {
          if (seenIds.add(item.id)) recentsList.add(item);
        } else {
          othersList.add(item);
        }
      }

      // Diversify the remaining channels across distinct categories
      final diversified = <MediaItem>[];
      final seenGenres = <String, int>{};
      for (final item in othersList) {
        final genre = item.genres.isNotEmpty ? item.genres.first : 'General';
        final count = seenGenres[genre] ?? 0;
        if (count < 3) {
          seenGenres[genre] = count + 1;
          if (seenIds.add(item.id)) {
            diversified.add(item);
          }
        }
        if (favoritesList.length + recentsList.length + diversified.length >= 30) {
          break;
        }
      }

      for (final item in othersList) {
        if (favoritesList.length + recentsList.length + diversified.length >= 30) {
          break;
        }
        if (seenIds.add(item.id)) {
          diversified.add(item);
        }
      }

      final curated = [...favoritesList, ...recentsList, ...diversified];
      final newItems = curated.take(20).toList();

      if (newItems.isNotEmpty && !_areMediaListsEqual(liveChannels, newItems)) {
        liveChannels.assignAll(newItems);
      }
      channelsState.value = SectionLoadState.loaded;
    } catch (e) {
      channelsState.value = SectionLoadState.error;
    }
  }

  static bool _areMediaListsEqual(List<MediaItem> a, List<MediaItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  Future<void> _refreshContinueWatching(String providerId) async {
    continueWatchingState.value = SectionLoadState.loading;
    try {
      final history = await historyRepository.getRecent(limit: 20);
      if (Get.isRegistered<PlaybackRepository>()) {
        try {
          final sessions =
              await Get.find<PlaybackRepository>().getAllWatchSessions();
          final progressByItem = <String, PlaybackSessionModel>{};
          for (final session in sessions) {
            final pct = session.completionPercentage;
            if (pct <= 0.01 || pct >= 0.90) continue;
            if (!progressByItem.containsKey(session.itemId)) {
              progressByItem[session.itemId] = session;
            }
          }
          final inProgressItems = <MediaItem>[];
          for (final entry in progressByItem.entries) {
            final item = await catalogRepository.getItem(entry.key);
            if (item == null) continue;
            if (!_matchesProvider(item, providerId)) continue;
            inProgressItems.add(item);
          }
          inProgressItems.sort((a, b) {
            final sA = progressByItem[a.id]?.updatedAt ?? a.updatedAt;
            final sB = progressByItem[b.id]?.updatedAt ?? b.updatedAt;
            return sB.compareTo(sA);
          });
          if (inProgressItems.isNotEmpty) {
            if (!_areMediaListsEqual(continueWatching, inProgressItems)) {
              continueWatching.assignAll(inProgressItems);
            }
          } else {
            if (!_areMediaListsEqual(continueWatching, history)) {
              continueWatching.assignAll(history);
            }
          }
        } catch (_) {
          if (!_areMediaListsEqual(continueWatching, history)) {
            continueWatching.assignAll(history);
          }
        }
      } else {
        if (!_areMediaListsEqual(continueWatching, history)) {
          continueWatching.assignAll(history);
        }
      }
      continueWatchingState.value = SectionLoadState.loaded;
    } catch (e) {
      continueWatchingState.value = SectionLoadState.error;
    }
  }

  Future<void> _refreshFavoritesOnly(String providerId) async {
    favoritesState.value = SectionLoadState.loading;
    try {
      final favItems = await favoriteRepository.getAll();
      final newFavs = <MediaItem>[];
      for (final fav in favItems) {
        final item = await catalogRepository.getItem(fav.id);
        if (item == null) continue;
        if (!_matchesProvider(item, providerId)) continue;
        newFavs.add(item);
      }
      if (favItems.isNotEmpty && newFavs.isEmpty && favorites.isNotEmpty) {
        // Catalog not ready yet, preserve existing cached favorites
        favoritesState.value = SectionLoadState.loaded;
        return;
      }
      if (!_areMediaListsEqual(favorites, newFavs)) {
        favorites.assignAll(newFavs);
      }
      favoritesState.value = SectionLoadState.loaded;
    } catch (e) {
      favoritesState.value = SectionLoadState.error;
    }
  }

  Future<void> _refreshRecentlyAdded(String providerId) async {
    recentlyAddedState.value = SectionLoadState.loading;
    try {
      final provider = _providerOrNull(providerId);
      final movieItems = await catalogRepository.topByCreatedAt(
        MediaType.movie,
        providerId: provider,
        limit: 20,
      );
      final seriesItems = await catalogRepository.topByCreatedAt(
        MediaType.series,
        providerId: provider,
        limit: 20,
      );
      var vodItems = <MediaItem>[...movieItems, ...seriesItems];
      if (vodItems.isEmpty) {
        vodItems = await catalogRepository.topByCreatedAt(
          MediaType.channel,
          providerId: provider,
          limit: 20,
        );
      }
      final sorted = vodItems.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final newItems = sorted.take(20).toList();
      if (newItems.isNotEmpty && !_areMediaListsEqual(recentlyAdded, newItems)) {
        recentlyAdded.assignAll(newItems);
      }
      recentlyAddedState.value = SectionLoadState.loaded;
    } catch (e) {
      recentlyAddedState.value = SectionLoadState.error;
    }
  }

  Future<void> _refreshRecentlyPlayed() async {
    try {
      final history = await historyRepository.getRecent(limit: 20);
      if (history.isNotEmpty && !_areMediaListsEqual(recentlyPlayed, history)) {
        recentlyPlayed.assignAll(history);
      }
    } catch (e) {
      // Keep existing data
    }
  }

  List<MediaItem> _computeFeaturedFromVod(
    List<MediaItem> moviePool,
    List<MediaItem> seriesPool,
  ) {
    final vodCandidates = <MediaItem>[...moviePool, ...seriesPool];
    final ratedWithArtwork = vodCandidates
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

    final fallbackWithArtwork = vodCandidates
        .where((item) =>
            (item.backdrop != null && item.backdrop!.isNotEmpty) ||
            (item.poster != null && item.poster!.isNotEmpty))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final result = <MediaItem>[];
    final seen = <String>{};
    for (final item in [
      ...ratedWithArtwork,
      ...fallbackWithArtwork,
      ...vodCandidates,
    ]) {
      if (result.length >= 5) break;
      if (seen.add(item.id)) {
        result.add(item);
      }
    }
    return result;
  }

  List<MediaItem> _computeFeaturedFromChannels(
    List<MediaItem> channelCandidates,
  ) {
    if (channelCandidates.isEmpty) return const [];

    final withLogos = channelCandidates
        .where((item) =>
            (item.poster != null && item.poster!.isNotEmpty) ||
            (item.backdrop != null && item.backdrop!.isNotEmpty) ||
            (item.thumbnail != null && item.thumbnail!.isNotEmpty))
        .toList();

    final result = <MediaItem>[];
    final seenIds = <String>{};
    final seenGenres = <String, int>{};

    for (final item in (withLogos.isNotEmpty ? withLogos : channelCandidates)) {
      final genre = item.genres.isNotEmpty ? item.genres.first : 'General';
      final count = seenGenres[genre] ?? 0;
      if (count < 1 && seenIds.add(item.id)) {
        seenGenres[genre] = count + 1;
        result.add(item);
      }
      if (result.length >= 5) break;
    }

    for (final item in (withLogos.isNotEmpty ? withLogos : channelCandidates)) {
      if (result.length >= 5) break;
      if (seenIds.add(item.id)) {
        result.add(item);
      }
    }

    return result;
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  bool get hasContent =>
      featuredHeroItems.isNotEmpty ||
      liveChannels.isNotEmpty ||
      movies.isNotEmpty ||
      series.isNotEmpty ||
      continueWatching.isNotEmpty ||
      favorites.isNotEmpty ||
      recentlyAdded.isNotEmpty;

  bool get hasAnySectionLoading =>
      heroState.value == SectionLoadState.loading ||
      moviesState.value == SectionLoadState.loading ||
      seriesState.value == SectionLoadState.loading ||
      channelsState.value == SectionLoadState.loading;

  Future<void> preloadHomeData() async {
    await _initializeHome();
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
    _log('[HOME] Manual refresh triggered');
    isLoading.value = !hasContent;
    final coordinator = _catalogCoordinator;
    try {
      await _loadProviders();
      if (coordinator != null) {
        await coordinator.runCoalesced(_refreshSections);
      } else {
        await _refreshSections();
      }
      await _snapshotService.save(_buildSnapshot());
      _log('[HOME] Manual refresh complete');
    } catch (e) {
      _log('[HOME] Manual refresh error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _log(String message) {
    developer.log(message, name: 'StreamHubPro.Home');
  }
}
