import 'package:get/get.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';

class MoviesController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;

  MoviesController({
    required this.mediaEngine,
    required this.mediaLibrary,
    required this.catalogRepository,
  });

  final RxBool isLoading = true.obs;
  final RxString selectedProvider = ''.obs;
  final RxList<MediaItem> movies = <MediaItem>[].obs;
  final List<MediaItem> _allMovies = <MediaItem>[];
  final RxList<MediaItem> featuredMovies = <MediaItem>[].obs;
  final RxList<MediaItem> trendingMovies = <MediaItem>[].obs;
  final RxList<MediaItem> newThisWeekMovies = <MediaItem>[].obs;
  final RxList<MediaItem> mysteryThrillerMovies = <MediaItem>[].obs;
  final RxList<MediaItem> romanticComedyMovies = <MediaItem>[].obs;
  final RxList<MediaItem> topRatedMovies = <MediaItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadMovies();
    mediaLibrary.moviesStream.listen((items) {
      if (items.isNotEmpty) {
        final sorted = items.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _allMovies
          ..clear()
          ..addAll(sorted);
        _applyProviderFilter();
      }
    });
  }

  Future<void> reloadMovies() => _loadMovies();

  void setProvider(String providerId) {
    selectedProvider.value = providerId;
    _applyProviderFilter();
  }

  void _applyProviderFilter() {
    List<MediaItem> filtered;
    if (selectedProvider.value.isEmpty) {
      filtered = List.of(_allMovies);
    } else {
      filtered = _allMovies.where((item) {
        return item.providerId == selectedProvider.value ||
            item.providerType.displayName == selectedProvider.value;
      }).toList();
    }
    movies.assignAll(filtered);
    _computeSections(filtered);
  }

  Future<void> _loadMovies() async {
    isLoading.value = true;
    try {
      var movieItems = await catalogRepository.getByType(MediaType.movie);
      if (movieItems.isEmpty) {
        movieItems = mediaLibrary.getMovies();
      }
      movieItems.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _allMovies
        ..clear()
        ..addAll(movieItems);
      _applyProviderFilter();
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }

  void _computeSections(List<MediaItem> allMovies) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    featuredMovies.assignAll(
      _takePreferred(
        preferred: allMovies.where((item) => item.rating != null).toList()
          ..sort((a, b) {
            final ratingCompare = b.rating!.compareTo(a.rating!);
            if (ratingCompare != 0) return ratingCompare;
            return b.updatedAt.compareTo(a.updatedAt);
          }),
        fallback: allMovies,
        limit: 3,
      ),
    );

    trendingMovies.assignAll(
      _takePreferred(
        preferred: List<MediaItem>.of(allMovies),
        fallback: allMovies,
        limit: 15,
      ),
    );

    newThisWeekMovies.assignAll(
      _takePreferred(
        preferred:
            allMovies.where((item) => item.createdAt.isAfter(weekAgo)).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        fallback: allMovies,
        limit: 15,
      ),
    );

    mysteryThrillerMovies.assignAll(
      _takePreferred(
        preferred: allMovies.where(_isMysteryOrThriller).toList(),
        fallback: allMovies,
        limit: 15,
      ),
    );

    romanticComedyMovies.assignAll(
      _takePreferred(
        preferred: _sortRomanticComedyMatches(allMovies),
        fallback: allMovies,
        limit: 15,
      ),
    );

    topRatedMovies.assignAll(
      _takePreferred(
        preferred: allMovies.where((item) => item.rating != null).toList()
          ..sort((a, b) => b.rating!.compareTo(a.rating!)),
        fallback: allMovies,
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

  bool _isMysteryOrThriller(MediaItem item) {
    final genres = item.genres.map((genre) => genre.toLowerCase()).toList();
    return genres.any((genre) => genre.contains('mystery')) ||
        genres.any((genre) => genre.contains('thriller'));
  }

  List<MediaItem> _sortRomanticComedyMatches(List<MediaItem> items) {
    final both = <MediaItem>[];
    final partial = <MediaItem>[];

    for (final item in items) {
      final genres = item.genres.map((genre) => genre.toLowerCase()).toList();
      final hasRomance = genres.any((genre) => genre.contains('romance'));
      final hasComedy = genres.any((genre) => genre.contains('comedy'));
      if (hasRomance && hasComedy) {
        both.add(item);
      } else if (hasRomance || hasComedy) {
        partial.add(item);
      }
    }

    return [...both, ...partial];
  }

  bool canOpenMovie(MediaItem item) {
    final streamUrl = item.metadata['streamUrl']?.toString();
    final directSource = item.metadata['directSource']?.toString();
    final streamId = item.metadata['streamId']?.toString();
    return (streamUrl != null && streamUrl.isNotEmpty) ||
        (directSource != null && directSource.isNotEmpty) ||
        (streamId != null && streamId.isNotEmpty);
  }

  @override
  Future<void> refresh() async {
    await _loadMovies();
  }
}
