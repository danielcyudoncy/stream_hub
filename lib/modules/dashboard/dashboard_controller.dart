import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/history_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/data/repositories/media_source_repository.dart';
import 'package:stream_hub/data/services/catalog_refresh_coordinator.dart';

class DashboardController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;
  final HistoryRepository historyRepository;
  final FavoriteRepository favoriteRepository;
  final MediaSourceRepository mediaSourceRepository;
  StreamSubscription? _catalogSubscription;

  DashboardController({
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
  final RxList<MediaItem> continueWatching = <MediaItem>[].obs;
  final RxList<MediaItem> liveChannels = <MediaItem>[].obs;
  final RxList<MediaItem> recentlyPlayed = <MediaItem>[].obs;
  final RxList<MediaItem> favorites = <MediaItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadDashboard();
    _subscribeToCatalogUpdates();
  }

  void _subscribeToCatalogUpdates() {
    if (Get.isRegistered<CatalogRefreshCoordinator>()) {
      final coordinator = Get.find<CatalogRefreshCoordinator>();
      _catalogSubscription = coordinator.refreshSignal.listen((_) {
        coordinator.runCoalesced(loadDashboard);
      });
    } else {
      _catalogSubscription = catalogRepository.watchUpdates().listen((_) {
        loadDashboard();
      });
    }
  }

  @override
  void onClose() {
    _catalogSubscription?.cancel();
    super.onClose();
  }

  void changeIndex(int index) {
    selectedIndex.value = index;
  }

  Future<void> loadDashboard() async {
    isLoading.value = true;
    try {
      final providers = await mediaSourceRepository.getAll();
      providerCount.value = providers.length;

      final liveChannelsList = await catalogRepository.getByType(
        MediaType.channel,
      );
      liveChannels.assignAll(
        liveChannelsList.take(200).toList(),
      );

      final favList = await favoriteRepository.getAll();
      final newFavs = <MediaItem>[];
      for (final fav in favList) {
        final item = await catalogRepository.getItem(fav.id);
        if (item != null) newFavs.add(item);
      }
      favorites.assignAll(newFavs);

      final history = await historyRepository.getRecent(limit: 20);
      recentlyPlayed.assignAll(history);
      continueWatching.assignAll(
        history.where((item) => item.mediaType == MediaType.channel).toList(),
      );
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }
}
