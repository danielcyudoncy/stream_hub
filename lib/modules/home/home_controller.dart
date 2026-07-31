import 'dart:async';

import 'package:get/get.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import '../../../data/repositories/media_source_repository.dart';

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

  final RxString greetingMessage = ''.obs;
  final RxBool isLoading = true.obs;
  final RxInt providerCount = 0.obs;
  final RxBool hasProviders = false.obs;

  final RxList<MediaItem> continueWatching = <MediaItem>[].obs;
  final RxList<MediaItem> liveChannels = <MediaItem>[].obs;
  final RxList<MediaItem> movies = <MediaItem>[].obs;
  final RxList<MediaItem> series = <MediaItem>[].obs;
  final RxList<MediaItem> favorites = <MediaItem>[].obs;
  final RxList<MediaItem> recentlyAdded = <MediaItem>[].obs;
  final RxList<MediaItem> recentlyPlayed = <MediaItem>[].obs;
  final RxList<MediaItem> downloads = <MediaItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadHomeData();
    _catalogSubscription = catalogRepository.watchUpdates().listen((_) => refresh());
  }

  @override
  void onClose() {
    _catalogSubscription?.cancel();
    super.onClose();
  }

  Future<void> _loadHomeData() async {
    isLoading.value = true;
    try {
      _updateGreeting();
      await _loadProviders();
      await _loadDashboardData();
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      greetingMessage.value = 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      greetingMessage.value = 'Good Afternoon';
    } else {
      greetingMessage.value = 'Good Evening';
    }
  }

  Future<void> _loadProviders() async {
    final providers = await mediaSourceRepository.getAll();
    providerCount.value = providers.length;
    hasProviders.value = providers.isNotEmpty;
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

      movies.assignAll(
        movieItems.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      );

      series.assignAll(
        seriesItems.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      );

      recentlyAdded.assignAll(
        allItems.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

      final favItems = await favoriteRepository.getAll();
      final favIds = favItems.map((f) => f.id).toSet();
      favorites.assignAll(
        allItems.where((item) => favIds.contains(item.id)).toList(),
      );

      final history = await historyRepository.getRecent(limit: 20);
      recentlyPlayed.assignAll(history);

      continueWatching.assignAll(
        history.where((item) => item.mediaType == MediaType.channel).toList(),
      );
    } catch (e) {
      // Log error
    }
  }

  @override
  Future<void> refresh() async {
    await _loadHomeData();
  }
}
