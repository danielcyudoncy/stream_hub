import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/channel.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';

class LiveTVController extends GetxController {
  final MediaEngine _mediaEngine;
  final MediaLibrary _mediaLibrary;
  final CatalogRepository _catalogRepository;

  LiveTVController({
    required MediaEngine mediaEngine,
    required MediaLibrary mediaLibrary,
    required CatalogRepository catalogRepository,
  })  : _mediaEngine = mediaEngine,
        _mediaLibrary = mediaLibrary,
        _catalogRepository = catalogRepository;

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
  final RxBool showFavoritesOnly = false.obs;
  final RxBool showRecentlyAdded = false.obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadLiveTVData();
  }

  Future<void> _loadLiveTVData() async {
    isLoading.value = true;
    try {
      final allItems = await _catalogRepository.getAllItems();
      final liveChannels = allItems
          .where((item) => item.mediaType == MediaType.channel)
          .toList();
      channels.assignAll(liveChannels);
      filteredChannels.assignAll(liveChannels);
      favorites.assignAll(
        liveChannels.where((item) => item.favorite).toList(),
      );

      final providerSet = <String>{};
      final languageSet = <String>{};
      final countrySet = <String>{};
      final resolutionSet = <String>{};
      final categorySet = <String>{};

      for (final item in liveChannels) {
        if (item.providerType != null) {
          providerSet.add(item.providerType!.displayName);
        }
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
          categorySet.add(genre);
        }
      }

      categories.assignAll(['All Channels', ...categorySet]);
      providers.assignAll(providerSet.toList()..sort());
      languages.assignAll(languageSet.toList()..sort());
      countries.assignAll(countrySet.toList()..sort());
      resolutions.assignAll(resolutionSet.toList()..sort());
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }

  void setView(String view) {
    selectedView.value = view;
  }

  void setCategory(String category) {
    selectedCategory.value = category;
    _applyFilters();
  }

  void setProvider(String provider) {
    selectedProvider.value = provider;
    _applyFilters();
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

    if (selectedCategory.value != 'All Channels') {
      result = result
          .where((item) => item.genres.contains(selectedCategory.value))
          .toList();
    }

    if (selectedProvider.value.isNotEmpty) {
      result = result
          .where((item) =>
              item.providerType?.displayName == selectedProvider.value)
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
        result.sort((a, b) => (a.providerType?.displayName ?? '')
            .compareTo(b.providerType?.displayName ?? ''));
        break;
      case 'country':
        result.sort((a, b) => (a.country ?? '').compareTo(b.country ?? ''));
        break;
    }

    filteredChannels.assignAll(result);
  }

  void toggleFavorite(MediaItem item) {
    _loadLiveTVData();
  }

  void refresh() {
    _loadLiveTVData();
  }

  @override
  void onClose() {
    super.onClose();
  }
}