import 'package:get/get.dart';
import 'package:stream_hub/core/media/media_library.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';

class SeriesGenreController extends GetxController {
  final CatalogRepository catalogRepository;
  final MediaLibrary? mediaLibrary;
  final FavoriteRepository? favoriteRepository;

  SeriesGenreController({
    required this.catalogRepository,
    this.mediaLibrary,
    this.favoriteRepository,
  });

  final RxBool isLoading = true.obs;
  final RxString genreName = ''.obs;
  final RxList<MediaItem> series = <MediaItem>[].obs;
  final RxString sortBy = 'rating'.obs; // 'rating', 'title', 'recent'

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is String) {
      genreName.value = args;
    } else if (args is Map) {
      genreName.value = args['genre']?.toString() ??
          args['title']?.toString() ??
          'Series';
    } else {
      genreName.value = 'Series';
    }
    loadGenreSeries();
  }

  Future<void> loadGenreSeries() async {
    isLoading.value = true;
    try {
      var all = await catalogRepository.getByType(MediaType.series);
      if (all.isEmpty) {
        final allItems = await catalogRepository.getAllItems();
        all = allItems
            .where((item) => item.mediaType == MediaType.series)
            .toList();
      }
      if (all.isEmpty && mediaLibrary != null) {
        all = mediaLibrary!.getSeries();
      }

      final gName = genreName.value.toLowerCase().trim();

      List<MediaItem> filtered;
      if (gName == 'trending') {
        filtered = List.of(all)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      } else if (gName == 'recently added') {
        filtered = List.of(all)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else if (gName == 'top rated') {
        filtered = all.where((s) => s.rating != null).toList()
          ..sort((a, b) => b.rating!.compareTo(a.rating!));
      } else if (gName.isEmpty || gName == 'all' || gName == 'series') {
        filtered = List.of(all);
      } else {
        final targets = _getGenreKeywords(gName);
        filtered = all.where((s) => _matchesGenreKeywords(s, targets)).toList();
      }

      _applySort(filtered);
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  List<String> _getGenreKeywords(String gName) {
    if (gName.contains('drama')) return ['drama'];
    if (gName.contains('comedy')) return ['comedy'];
    if (gName.contains('action') || gName.contains('adventure')) {
      return ['action', 'adventure'];
    }
    if (gName.contains('sci-fi') ||
        gName.contains('scifi') ||
        gName.contains('fantasy') ||
        gName.contains('science')) {
      return ['sci-fi', 'scifi', 'science', 'fantasy'];
    }
    if (gName.contains('animation') ||
        gName.contains('anime') ||
        gName.contains('cartoon')) {
      return ['animation', 'anime', 'cartoon'];
    }
    if (gName.contains('doc') || gName.contains('biography')) {
      return ['documentary', 'doc', 'biography'];
    }
    return [gName];
  }

  bool _matchesGenreKeywords(MediaItem item, List<String> targets) {
    final genreStrings = <String>[
      ...item.genres,
      if (item.metadata['genre'] != null) item.metadata['genre'].toString(),
      if (item.metadata['category_name'] != null)
        item.metadata['category_name'].toString(),
      if (item.metadata['categoryName'] != null)
        item.metadata['categoryName'].toString(),
      if (item.metadata['group-title'] != null)
        item.metadata['group-title'].toString(),
      if (item.metadata['categoryId'] != null)
        item.metadata['categoryId'].toString(),
      if (item.metadata['category_id'] != null)
        item.metadata['category_id'].toString(),
    ].map((g) => g.toLowerCase());

    return genreStrings.any((g) => targets.any((t) => g.contains(t)));
  }

  void setSortBy(String sort) {
    sortBy.value = sort;
    _applySort(series);
  }

  void _applySort(List<MediaItem> list) {
    final sorted = List<MediaItem>.from(list);
    switch (sortBy.value) {
      case 'title':
        sorted.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'recent':
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case 'rating':
      default:
        sorted.sort((a, b) {
          final rA = a.rating ?? 0.0;
          final rB = b.rating ?? 0.0;
          final rComp = rB.compareTo(rA);
          if (rComp != 0) return rComp;
          return b.updatedAt.compareTo(a.updatedAt);
        });
        break;
    }
    series.assignAll(sorted);
  }

  void openSeries(MediaItem item) {
    Get.toNamed(AppRoutes.seriesDetails, arguments: item);
  }

  Future<void> toggleFavorite(MediaItem item) async {
    if (favoriteRepository == null) return;
    if (item.favorite) {
      await favoriteRepository!.remove(item.id);
    } else {
      await favoriteRepository!.add(item.copyWith(favorite: true));
    }
    loadGenreSeries();
  }
}
