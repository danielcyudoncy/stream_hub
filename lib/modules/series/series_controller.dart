// modules/series/series_controller.dart
import 'package:get/get.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';

class SeriesController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;

  SeriesController({
    required this.mediaEngine,
    required this.mediaLibrary,
    required this.catalogRepository,
  });

  final RxBool isLoading = true.obs;
  final RxString selectedProvider = ''.obs;
  final RxList<MediaItem> series = <MediaItem>[].obs;
  final List<MediaItem> _allSeries = <MediaItem>[];
  final RxList<MediaItem> featuredSeries = <MediaItem>[].obs;
  final RxList<MediaItem> continueWatching = <MediaItem>[].obs;
  final RxList<MediaItem> trendingSeries = <MediaItem>[].obs;
  final RxList<MediaItem> topRatedSeries = <MediaItem>[].obs;
  final RxList<MediaItem> recentlyAddedSeries = <MediaItem>[].obs;
  final RxList<MediaItem> dramaSeries = <MediaItem>[].obs;
  final RxList<MediaItem> comedySeries = <MediaItem>[].obs;
  final RxList<MediaItem> actionAdventureSeries = <MediaItem>[].obs;
  final RxList<MediaItem> sciFiFantasySeries = <MediaItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadSeries();
    mediaLibrary.seriesStream.listen((items) {
      if (items.isNotEmpty) {
        final sorted = items.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _allSeries
          ..clear()
          ..addAll(sorted);
        _applyProviderFilter();
      }
    });
  }

  Future<void> reloadSeries() => _loadSeries();

  void setProvider(String providerId) {
    selectedProvider.value = providerId;
    _applyProviderFilter();
  }

  void _applyProviderFilter() {
    List<MediaItem> filtered;
    if (selectedProvider.value.isEmpty) {
      filtered = List.of(_allSeries);
    } else {
      filtered = _allSeries.where((item) {
        return item.providerId == selectedProvider.value ||
            item.providerType.displayName == selectedProvider.value;
      }).toList();
    }
    series.assignAll(filtered);
    _computeSections(filtered);
  }

  Future<void> _loadSeries() async {
    isLoading.value = true;
    try {
      final allItems = await catalogRepository.getAllItems();
      var seriesItems =
          allItems.where((item) => item.mediaType == MediaType.series).toList();
      if (seriesItems.isEmpty) {
        seriesItems = mediaLibrary.getSeries();
      }
      seriesItems.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _allSeries
        ..clear()
        ..addAll(seriesItems);
      _applyProviderFilter();
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }

  void _computeSections(List<MediaItem> allSeries) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    // Featured series - highest rated, most recently updated
    featuredSeries.assignAll(
      _takePreferred(
        preferred: allSeries.where((item) => item.rating != null).toList()
          ..sort((a, b) {
            final ratingCompare = b.rating!.compareTo(a.rating!);
            if (ratingCompare != 0) return ratingCompare;
            return b.updatedAt.compareTo(a.updatedAt);
          }),
        fallback: allSeries,
        limit: 5,
      ),
    );

    // Trending series - most recently updated
    trendingSeries.assignAll(
      _takePreferred(
        preferred: List<MediaItem>.of(allSeries),
        fallback: allSeries,
        limit: 15,
      ),
    );

    // Top rated series - sorted by rating
    topRatedSeries.assignAll(
      _takePreferred(
        preferred: allSeries.where((item) => item.rating != null).toList()
          ..sort((a, b) => b.rating!.compareTo(a.rating!)),
        fallback: allSeries,
        limit: 15,
      ),
    );

    // Recently added series - added in the last week
    recentlyAddedSeries.assignAll(
      _takePreferred(
        preferred:
            allSeries.where((item) => item.createdAt.isAfter(weekAgo)).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        fallback: allSeries,
        limit: 15,
      ),
    );

    // Genre-based sections
    dramaSeries.assignAll(
      _takePreferred(
        preferred: allSeries.where(_isDrama).toList(),
        fallback: allSeries,
        limit: 15,
      ),
    );

    comedySeries.assignAll(
      _takePreferred(
        preferred: allSeries.where(_isComedy).toList(),
        fallback: allSeries,
        limit: 15,
      ),
    );

    actionAdventureSeries.assignAll(
      _takePreferred(
        preferred: allSeries.where(_isActionOrAdventure).toList(),
        fallback: allSeries,
        limit: 15,
      ),
    );

    sciFiFantasySeries.assignAll(
      _takePreferred(
        preferred: allSeries.where(_isSciFiOrFantasy).toList(),
        fallback: allSeries,
        limit: 15,
      ),
    );
  }

  List<MediaItem> _takePreferred({
    required List<MediaItem> preferred,
    required List<MediaItem> fallback,
    required int limit,
  }) {
    final result = <MediaItem>[];
    final seen = <String>{};

    void addItems(Iterable<MediaItem> items) {
      for (final item in items) {
        if (result.length >= limit) return;
        if (seen.add(item.id)) {
          result.add(item);
        }
      }
    }

    addItems(preferred);
    addItems(fallback);
    return result.take(limit).toList();
  }

  // Genre filters
  bool _isDrama(MediaItem item) {
    final genres = item.genres.map((genre) => genre.toLowerCase()).toList();
    return genres.any((genre) => genre.contains('drama'));
  }

  bool _isComedy(MediaItem item) {
    final genres = item.genres.map((genre) => genre.toLowerCase()).toList();
    return genres.any((genre) => genre.contains('comedy'));
  }

  bool _isActionOrAdventure(MediaItem item) {
    final genres = item.genres.map((genre) => genre.toLowerCase()).toList();
    return genres.any((genre) => genre.contains('action')) ||
        genres.any((genre) => genre.contains('adventure'));
  }

  bool _isSciFiOrFantasy(MediaItem item) {
    final genres = item.genres.map((genre) => genre.toLowerCase()).toList();
    return genres.any((genre) => genre.contains('sci-fi')) ||
        genres.any((genre) => genre.contains('scifi')) ||
        genres.any((genre) => genre.contains('science')) ||
        genres.any((genre) => genre.contains('fantasy'));
  }

  @override
  Future<void> refresh() async {
    await _loadSeries();
  }
}
