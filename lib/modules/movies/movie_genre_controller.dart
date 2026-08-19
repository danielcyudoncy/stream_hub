import 'package:get/get.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/media/media_library.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/curated_genre.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';

enum MovieGenreSortOption {
  recentlyAdded('Recently Added'),
  rating('Top Rated'),
  year('Release Year'),
  titleAZ('Title (A-Z)'),
  duration('Duration');

  final String label;
  const MovieGenreSortOption(this.label);
}

class MovieGenreController extends GetxController {
  final CatalogRepository catalogRepository;
  final FavoriteRepository? favoriteRepository;
  final MediaLibrary mediaLibrary;

  final RxString genreTitle = ''.obs;
  final RxString searchQuery = ''.obs;
  final RxString selectedProvider = ''.obs;
  final RxBool favoritesOnly = false.obs;
  final Rx<MovieGenreSortOption> selectedSort =
      MovieGenreSortOption.recentlyAdded.obs;
  final RxBool isLoading = true.obs;

  final RxList<MediaItem> displayedMovies = <MediaItem>[].obs;
  final List<MediaItem> _genreMovies = <MediaItem>[];

  MovieGenreController({
    required this.catalogRepository,
    this.favoriteRepository,
    required this.mediaLibrary,
  });

  @override
  void onInit() {
    super.onInit();
    _initGenre();
  }

  Future<void> _initGenre() async {
    isLoading.value = true;
    final args = Get.arguments;
    List<MediaItem>? initialItems;

    if (args is Map) {
      genreTitle.value = args['title']?.toString() ?? args['genre']?.toString() ?? 'Movies';
      if (args['items'] is List) {
        initialItems = List<MediaItem>.from(args['items'] as List);
      }
    } else if (args is String) {
      genreTitle.value = args;
    } else if (Get.parameters['genre'] != null) {
      genreTitle.value = Get.parameters['genre']!;
    } else {
      genreTitle.value = 'Movies';
    }

    if (initialItems != null && initialItems.isNotEmpty) {
      _genreMovies.assignAll(initialItems);
      _applyFilters();
      isLoading.value = false;
    } else {
      await _loadMoviesForGenre();
    }
  }

  Future<void> _loadMoviesForGenre() async {
    isLoading.value = true;
    try {
      var all = await catalogRepository.getByType(MediaType.movie);
      if (all.isEmpty) {
        all = mediaLibrary.getMovies();
      }

      final normalizedGenre = genreTitle.value.toLowerCase().trim();
      final curated = CuratedGenre.findByQuery(normalizedGenre);

      final matches = all.where((item) {
        if (normalizedGenre == 'all' || normalizedGenre == 'movies') return true;

        // Check curated keywords
        if (curated != null) {
          final itemGenres = item.genres.map((g) => g.toLowerCase().trim()).toList();
          final category = item.metadata['category_name']?.toString().toLowerCase() ?? '';
          if (itemGenres.any((g) => curated.keywords.any((k) => g.contains(k))) ||
              curated.keywords.any((k) => category.contains(k))) {
            return true;
          }
        }

        // Direct matching
        for (final g in item.genres) {
          final gl = g.toLowerCase().trim();
          if (gl == normalizedGenre || gl.contains(normalizedGenre) || normalizedGenre.contains(gl)) {
            return true;
          }
        }

        final category = item.metadata['category_name']?.toString().toLowerCase() ?? '';
        return category.contains(normalizedGenre);
      }).toList();

      final favRepo = favoriteRepository;
      final enrichedMatches = <MediaItem>[];
      for (final match in matches) {
        if (favRepo != null) {
          final isFav = await favRepo.isFavorite(match.id);
          enrichedMatches.add(match.copyWith(favorite: isFav));
        } else {
          enrichedMatches.add(match);
        }
      }

      _genreMovies.assignAll(enrichedMatches);
      _applyFilters();
    } catch (_) {
      _genreMovies.clear();
      displayedMovies.clear();
    } finally {
      isLoading.value = false;
    }
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
    _applyFilters();
  }

  void setSort(MovieGenreSortOption sort) {
    selectedSort.value = sort;
    _applyFilters();
  }

  void setProvider(String provider) {
    selectedProvider.value = provider;
    _applyFilters();
  }

  void toggleFavoritesOnly() {
    favoritesOnly.value = !favoritesOnly.value;
    _applyFilters();
  }

  void _applyFilters() {
    var filtered = List<MediaItem>.from(_genreMovies);

    // Provider filter
    if (selectedProvider.value.isNotEmpty) {
      filtered = filtered.where((i) {
        return i.providerId == selectedProvider.value ||
            i.providerType.displayName == selectedProvider.value;
      }).toList();
    }

    // Favorites filter
    if (favoritesOnly.value) {
      filtered = filtered.where((i) => i.favorite).toList();
    }

    // Search query filter
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((i) {
        final title = i.title.toLowerCase();
        final director = i.director?.toLowerCase() ?? '';
        final cast = i.castMembers.map((c) => c.name.toLowerCase()).join(' ');
        final genres = i.genres.join(' ').toLowerCase();
        return title.contains(query) ||
            director.contains(query) ||
            cast.contains(query) ||
            genres.contains(query);
      }).toList();
    }

    // Sorting
    switch (selectedSort.value) {
      case MovieGenreSortOption.recentlyAdded:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case MovieGenreSortOption.rating:
        filtered.sort((a, b) {
          final rComp = (b.rating ?? 0).compareTo(a.rating ?? 0);
          if (rComp != 0) return rComp;
          return b.updatedAt.compareTo(a.updatedAt);
        });
        break;
      case MovieGenreSortOption.year:
        filtered.sort((a, b) {
          final yComp = (b.releaseYear ?? 0).compareTo(a.releaseYear ?? 0);
          if (yComp != 0) return yComp;
          return b.updatedAt.compareTo(a.updatedAt);
        });
        break;
      case MovieGenreSortOption.titleAZ:
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case MovieGenreSortOption.duration:
        filtered.sort((a, b) => (b.durationMinutes ?? 0).compareTo(a.durationMinutes ?? 0));
        break;
    }

    displayedMovies.assignAll(filtered);
  }

  void openMovie(MediaItem item) {
    Get.toNamed(
      AppRoutes.movieDetails,
      arguments: item,
    );
  }

  Future<void> toggleFavorite(MediaItem item) async {
    final repo = favoriteRepository;
    if (repo == null) return;
    final isFav = await repo.isFavorite(item.id);
    if (isFav) {
      await repo.remove(item.id);
    } else {
      await repo.add(item.copyWith(favorite: true));
    }
    // Update local instance
    final index = _genreMovies.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      _genreMovies[index] = _genreMovies[index].copyWith(favorite: !isFav);
      _applyFilters();
    }
  }

  Future<void> reload() => _loadMoviesForGenre();
}
