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

      continueWatching.assignAll(
        allItems.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      );

      liveChannels.assignAll(channelItems);

      movies.assignAll(
        movieItems.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      );

      series.assignAll(
        seriesItems.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      );

      favorites.assignAll(
        allItems.where((item) => item.favorite).toList(),
      );

      recentlyAdded.assignAll(
        allItems.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

      final history = await historyRepository.getRecent(limit: 20);
      recentlyPlayed.assignAll(history);
    } catch (e) {
      // Log error
    }
  }

  @override
  Future<void> refresh() async {
    await _loadHomeData();
  }
}