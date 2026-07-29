import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/channel.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';

class ProviderController extends GetxController {
  final MediaEngine _mediaEngine;
  final MediaLibrary _mediaLibrary;
  final CatalogRepository _catalogRepository;

  ProviderController({
    required MediaEngine mediaEngine,
    required MediaLibrary mediaLibrary,
    required CatalogRepository catalogRepository,
  })  : _mediaEngine = mediaEngine,
        _mediaLibrary = mediaLibrary,
        _catalogRepository = catalogRepository;

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
      final allItems = await _catalogRepository.getAllItems();
      final channelItems = allItems
          .where((item) => item.mediaType == MediaType.channel)
          .toList();

      allChannels.assignAll(channelItems);

      final grouped = <String, List<MediaItem>>{};
      final stats = <String, int>{};

      for (final item in channelItems) {
        final providerName = item.providerType?.displayName ?? 'Unknown';
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

  void refresh() {
    _loadProviders();
  }

  @override
  void onClose() {
    super.onClose();
  }
}