import 'package:get/get.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/modules/epg/models/epg_channel.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/modules/epg/repositories/guide_repository.dart';

class GuideController extends GetxController {
  final GuideRepository guideRepository;

  GuideController({required this.guideRepository});

  final RxList<EPGChannel> channels = <EPGChannel>[].obs;
  final RxList<EPGProgram> programs = <EPGProgram>[].obs;
  final RxList<EPGProgram> filteredPrograms = <EPGProgram>[].obs;
  final RxList<String> categories = <String>[].obs;
  final RxList<String> languages = <String>[].obs;
  final RxList<String> countries = <String>[].obs;
  final RxList<String> genres = <String>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final RxString selectedCategory = ''.obs;
  final RxString selectedLanguage = ''.obs;
  final RxString selectedCountry = ''.obs;
  final RxString selectedGenre = ''.obs;
  final RxString selectedProvider = ''.obs;
  final RxBool showFavoritesOnly = false.obs;
  final RxString searchQuery = ''.obs;
  final RxString error = ''.obs;
  final Rx<DateTime> selectedDate = DateTime.now().obs;
  final RxInt timelineWindowHours = 6.obs;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<ProviderRepository>()) {
      final providerRepo = Get.find<ProviderRepository>();
      selectedProvider.value = providerRepo.activeProviderId.value;
      ever(providerRepo.activeProviderId, (id) {
        if (selectedProvider.value != id) {
          setProvider(id);
        }
      });
    }
    loadGuide();
  }

  Future<void> loadGuide() async {
    isLoading.value = true;
    error.value = '';
    try {
      final guide = await guideRepository.fetchGuide(
        sourceId: 'default',
        startDate: DateTime.now().subtract(const Duration(hours: 2)),
        endDate: DateTime.now().add(const Duration(hours: 24)),
      );
      channels.assignAll(guide.channels);
      programs.assignAll(guide.programs);
      filteredPrograms.assignAll(guide.programs);
      categories.assignAll(['All', ...guide.categories.toList()..sort()]);
      languages.assignAll(['All', ...guide.languages.toList()..sort()]);
      countries.assignAll(['All', ...guide.countries.toList()..sort()]);
      genres.assignAll(['All', ...guide.genres.toList()..sort()]);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshGuide() async {
    isRefreshing.value = true;
    try {
      await guideRepository.clearCache();
      await loadGuide();
    } finally {
      isRefreshing.value = false;
    }
  }

  void setCategory(String category) {
    selectedCategory.value = category;
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

  void setGenre(String genre) {
    selectedGenre.value = genre;
    _applyFilters();
  }

  void setProvider(String provider) {
    if (selectedProvider.value != provider) {
      selectedProvider.value = provider;
    }
    selectedCategory.value = 'All';
    if (Get.isRegistered<ProviderRepository>()) {
      final providerRepo = Get.find<ProviderRepository>();
      if (providerRepo.activeProviderId.value != provider) {
        providerRepo.setActiveProviderId(provider);
      }
    }
    _applyFilters();
  }

  void setFavoritesOnly(bool value) {
    showFavoritesOnly.value = value;
    _applyFilters();
  }

void setSearchQuery(String query) {
    searchQuery.value = query;
    _applyFilters();
  }

  void setTimelineWindowHours(int hours) {
    timelineWindowHours.value = hours;
  }

  void scrollToMorning() {
    setTimelineWindowHours(12);
  }

  void scrollToAfternoon() {
    setTimelineWindowHours(12);
  }

  void scrollToEvening() {
    setTimelineWindowHours(12);
  }

  void scrollToTomorrow() {
    setSelectedDate(DateTime.now().add(const Duration(days: 1)));
    loadGuide();
  }

  void setSelectedDate(DateTime date) {
    selectedDate.value = date;
  }

  void _applyFilters() {
    var result = List<EPGProgram>.from(programs);

    if (selectedCategory.value != 'All' && selectedCategory.value.isNotEmpty) {
      result = result
          .where((p) => (p.categories ?? []).contains(selectedCategory.value))
          .toList();
    }

    if (selectedLanguage.value != 'All' && selectedLanguage.value.isNotEmpty) {
      result = result
          .where((p) => p.language == selectedLanguage.value)
          .toList();
    }

    if (selectedCountry.value != 'All' && selectedCountry.value.isNotEmpty) {
      result = result
          .where((p) => p.country == selectedCountry.value)
          .toList();
    }

    if (selectedGenre.value != 'All' && selectedGenre.value.isNotEmpty) {
      result = result
          .where((p) => p.genres.contains(selectedGenre.value))
          .toList();
    }

    if (showFavoritesOnly.value) {
      result = result.where((p) => p.favorite).toList();
    }

    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      result = result
          .where((p) =>
              p.title.toLowerCase().contains(query) ||
              (p.subtitle != null &&
                  p.subtitle!.toLowerCase().contains(query)) ||
              (p.description != null &&
                  p.description!.toLowerCase().contains(query)) ||
              (p.cast ?? []).any((c) => c.toLowerCase().contains(query)) ||
              (p.directors ?? []).any((d) => d.toLowerCase().contains(query)))
          .toList();
    }

    filteredPrograms.assignAll(result);
  }
}