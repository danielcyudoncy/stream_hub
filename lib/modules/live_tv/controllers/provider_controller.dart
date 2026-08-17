import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';

class ProviderController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;
  final FavoriteRepository? favoriteRepository;

  ProviderController({
    required this.mediaEngine,
    required this.mediaLibrary,
    required this.catalogRepository,
    this.favoriteRepository,
  });

  final RxList<MediaItem> allChannels = <MediaItem>[].obs;
  final RxMap<String, List<MediaItem>> providerChannels =
      RxMap<String, List<MediaItem>>({});
  final RxMap<String, int> providerStats = RxMap<String, int>({});
  final RxString selectedProvider = ''.obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    isLoading.value = true;
    try {
      final favList = await favoriteRepository?.getAll() ?? [];
      final favIds = favList.map((e) => e.id).toSet();

      final allItems = await catalogRepository.getAllItems();
      final channelItems = allItems
          .where((item) => item.mediaType == MediaType.channel)
          .map((item) => item.copyWith(favorite: favIds.contains(item.id)))
          .toList();

      allChannels.assignAll(channelItems);

      final grouped = <String, List<MediaItem>>{};
      final stats = <String, int>{};

      for (final item in channelItems) {
        final providerName = item.providerType.displayName;
        grouped.putIfAbsent(providerName, () => []).add(item);
        stats[providerName] = (stats[providerName] ?? 0) + 1;
      }

      providerChannels.clear();
      for (final entry in grouped.entries) {
        providerChannels[entry.key] = entry.value;
      }

      providerStats.clear();
      for (final entry in stats.entries) {
        providerStats[entry.key] = entry.value;
      }
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleFavorite(MediaItem item) async {
    if (favoriteRepository == null) {
      _loadProviders();
      return;
    }
    if (item.favorite) {
      await favoriteRepository!.remove(item.id);
    } else {
      await favoriteRepository!.add(item.copyWith(favorite: true));
    }
    await _loadProviders();
  }

  void selectProvider(String providerName) {
    selectedProvider.value = providerName;
  }

  List<MediaItem> getProviderChannels(String providerName) {
    return providerChannels[providerName] ?? [];
  }

  int getProviderCount(String providerName) {
    return providerStats[providerName] ?? 0;
  }

  List<String> getProviderNames() {
    return providerChannels.keys.toList()..sort();
  }

  @override
  void refresh() {
    _loadProviders();
  }
}
