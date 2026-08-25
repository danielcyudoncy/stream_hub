import 'package:get/get.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';
import '../../../core/media/repositories/playback_repository.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/curated_genre.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/playback_session_model.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';

class MoviesController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;
  final PlaybackRepository? playbackRepository;
  final FavoriteRepository? favoriteRepository;

  MoviesController({
    required this.mediaEngine,
    required this.mediaLibrary,
    required this.catalogRepository,
    PlaybackRepository? playbackRepository,
    FavoriteRepository? favoriteRepository,
  })  : playbackRepository = playbackRepository ??
            (Get.isRegistered<PlaybackRepository>()
                ? Get.find<PlaybackRepository>()
                : null),
        favoriteRepository = favoriteRepository ??
            (Get.isRegistered<FavoriteRepository>()
                ? Get.find<FavoriteRepository>()
                : null);

  final RxBool isLoading = true.obs;
  final RxString selectedProvider = ''.obs;
  final RxList<MediaItem> movies = <MediaItem>[].obs;
  final List<MediaItem> _allMovies = <MediaItem>[];

  // Curated & Dynamic Sections
  final Rx<MediaItem?> heroMovie = Rx<MediaItem?>(null);
  final RxList<MediaItem> featuredMovies = <MediaItem>[].obs;
  final RxList<MediaItem> continueWatchingMovies = <MediaItem>[].obs;
  final RxList<MediaItem> trendingMovies = <MediaItem>[].obs;
  final RxList<MediaItem> newThisWeekMovies = <MediaItem>[].obs;
  final RxList<MediaItem> topRatedMovies = <MediaItem>[].obs;
  final RxList<MediaItem> mysteryThrillerMovies = <MediaItem>[].obs;
  final RxList<MediaItem> romanticComedyMovies = <MediaItem>[].obs;

  // Dynamic Genres: Map of genre display title -> list of movies
  final RxMap<String, List<MediaItem>> genreSections =
      <String, List<MediaItem>>{}.obs;
  final RxList<String> availableGenres = <String>[].obs;

  // Watch Progress maps
  final RxMap<String, double> progressMap = <String, double>{}.obs;
  final RxMap<String, PlaybackSessionModel> sessionsMap =
      <String, PlaybackSessionModel>{}.obs;
  final RxSet<String> completedIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _loadMovies();
    mediaLibrary.moviesStream.listen((items) {
      if (items.isNotEmpty) {
        final sorted = items.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _allMovies
          ..clear()
          ..addAll(sorted);
        _applyProviderFilter();
      }
    });
  }

  @override
  void onReady() {
    super.onReady();
    _loadWatchSessions().then((_) => _computeSections(movies));
  }

  Future<void> reloadMovies() => _loadMovies();

  void setProvider(String providerId) {
    selectedProvider.value = providerId;
    _applyProviderFilter();
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

      await _loadWatchSessions();
      _applyProviderFilter();
    } catch (e) {
      // Non-critical logging
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadWatchSessions() async {
    final repo = playbackRepository;
    if (repo == null) return;
    try {
      final sessions = await repo.getAllWatchSessions();
      final pMap = <String, double>{};
      final sMap = <String, PlaybackSessionModel>{};
      final done = <String>{};

      for (final s in sessions) {
        pMap[s.itemId] = s.completionPercentage;
        sMap[s.itemId] = s;
        if (s.completionPercentage >= 0.90) {
          done.add(s.itemId);
        }
      }

      progressMap.assignAll(pMap);
      sessionsMap.assignAll(sMap);
      completedIds.assignAll(done);
    } catch (_) {
      // Non-critical
    }
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
    _computeGenres(filtered);
  }

  void _computeSections(List<MediaItem> allMovies) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    // 1. Featured Movies (Top rated or trending)
    final featured = _takePreferred(
      preferred: allMovies.where((item) => item.rating != null).toList()
        ..sort((a, b) {
          final ratingCompare = b.rating!.compareTo(a.rating!);
          if (ratingCompare != 0) return ratingCompare;
          return b.updatedAt.compareTo(a.updatedAt);
        }),
      fallback: allMovies,
      limit: 5,
    );
    featuredMovies.assignAll(featured);
    heroMovie.value = featured.isNotEmpty ? featured.first : null;

    // 2. Continue Watching (In-progress items with 0% < progress < 90%)
    final continueList = <MediaItem>[];
    for (final movie in allMovies) {
      final session = sessionsMap[movie.id];
      if (session != null &&
          session.completionPercentage > 0.01 &&
          session.completionPercentage < 0.90) {
        continueList.add(movie);
      }
    }
    continueList.sort((a, b) {
      final sA = sessionsMap[a.id]?.updatedAt ?? a.updatedAt;
      final sB = sessionsMap[b.id]?.updatedAt ?? b.updatedAt;
      return sB.compareTo(sA);
    });
    continueWatchingMovies.assignAll(continueList);

    // 3. Trending
    trendingMovies.assignAll(
      _takePreferred(
        preferred: List<MediaItem>.of(allMovies),
        fallback: allMovies,
        limit: 15,
      ),
    );

    // 4. New This Week
    newThisWeekMovies.assignAll(
      _takePreferred(
        preferred:
            allMovies.where((item) => item.createdAt.isAfter(weekAgo)).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        fallback: allMovies,
        limit: 15,
      ),
    );

    // 5. Mystery & Thriller
    mysteryThrillerMovies.assignAll(
      _takePreferred(
        preferred: allMovies.where(_isMysteryOrThriller).toList(),
        fallback: allMovies,
        limit: 15,
      ),
    );

    // 6. Romantic Comedy
    romanticComedyMovies.assignAll(
      _takePreferred(
        preferred: _sortRomanticComedyMatches(allMovies),
        fallback: allMovies,
        limit: 15,
      ),
    );

    // 7. Top Rated
    topRatedMovies.assignAll(
      _takePreferred(
        preferred: allMovies.where((item) => item.rating != null).toList()
          ..sort((a, b) => b.rating!.compareTo(a.rating!)),
        fallback: allMovies,
        limit: 15,
      ),
    );

    // 8. Dynamic Genres Extraction & Grouping
    _buildDynamicGenres(allMovies);
  }

  void _buildDynamicGenres(List<MediaItem> allMovies) {
    final Map<String, List<MediaItem>> genreMap = {};

    for (final movie in allMovies) {
      final candidateGenres = <String>{};

      // Add direct genres
      for (final g in movie.genres) {
        final normalized = g.trim();
        if (normalized.isNotEmpty) {
          final curated = CuratedGenre.findByQuery(normalized);
          candidateGenres.add(curated?.title ?? normalized);
        }
      }

      // Add category name if present
      final cat = movie.metadata['category_name']?.toString().trim();
      if (cat != null && cat.isNotEmpty) {
        final curated = CuratedGenre.findByQuery(cat);
        candidateGenres.add(curated?.title ?? cat);
      }

      for (final g in candidateGenres) {
        genreMap.putIfAbsent(g, () => []).add(movie);
      }
    }

    // Sort genres by number of movies descending, taking meaningful genres (min 2 movies)
    final sortedGenres = genreMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final Map<String, List<MediaItem>> finalGenres = {};
    for (final entry in sortedGenres) {
      if (entry.value.length >= 2 && finalGenres.length < 10) {
        finalGenres[entry.key] = entry.value.take(15).toList();
      }
    }

    genreSections.assignAll(finalGenres);
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

  static final RegExp _kLiveTvMarkerPattern = RegExp(
    r'(\b(live|itv|channel|fhd|hevc|uhd|4k|sd|h265|radio|epg|stream|24/7|sports\s*\d)\b|^uk\s*:|^us\s*:|^ca\s*:|^all\s+channels$)',
    caseSensitive: false,
  );

  void _computeGenres(List<MediaItem> allMovies) {
    final genreSet = <String>{};
    for (final m in allMovies) {
      for (final g in m.genres) {
        final clean = g.trim();
        if (clean.isEmpty) continue;
        if (RegExp(r'^\d+$').hasMatch(clean)) continue;

        for (final part in clean.split(RegExp(r'[,/|]'))) {
          final trimmed = part.trim();
          if (trimmed.isNotEmpty &&
              !RegExp(r'^\d+$').hasMatch(trimmed) &&
              !_kLiveTvMarkerPattern.hasMatch(trimmed)) {
            genreSet.add(trimmed);
          }
        }
      }

      final cat = m.metadata['category_name']?.toString().trim() ??
          m.metadata['categoryName']?.toString().trim() ??
          m.metadata['genre']?.toString().trim();
      if (cat != null && cat.isNotEmpty) {
        for (final part in cat.split(RegExp(r'[,/|]'))) {
          final trimmed = part.trim();
          if (trimmed.isNotEmpty &&
              !RegExp(r'^\d+$').hasMatch(trimmed) &&
              !_kLiveTvMarkerPattern.hasMatch(trimmed)) {
            genreSet.add(trimmed);
          }
        }
      }
    }
    final sorted = genreSet.toList()..sort();
    availableGenres.assignAll(sorted);
  }

  void openMovie(MediaItem item) {
    Get.toNamed(
      AppRoutes.movieDetails,
      arguments: item,
    );
  }

  void openGenre(String genreTitle, List<MediaItem> items) {
    Get.toNamed(
      AppRoutes.movieGenre,
      arguments: {
        'title': genreTitle,
        'items': items,
      },
    );
  }

  void openGenreByName(String genreName) {
    final target = genreName.toLowerCase().trim();
    final matching = movies.where((m) {
      final inGenres = m.genres.any((g) => g.toLowerCase().contains(target));
      final inCat = (m.metadata['category_name']?.toString() ??
              m.metadata['categoryName']?.toString() ??
              m.metadata['genre']?.toString() ??
              '')
          .toLowerCase()
          .contains(target);
      return inGenres || inCat;
    }).toList();

    openGenre(genreName, matching.isNotEmpty ? matching : movies);
  }

  void playMovieDirectly(MediaItem item, {Duration? resumePosition}) {
    Get.toNamed(
      AppRoutes.fullscreenPlayer,
      arguments: {
        'items': [item],
        'currentId': item.id,
        'resumePosition': resumePosition,
      },
    );
  }

  void resumeMovie(MediaItem item) {
    final session = sessionsMap[item.id];
    playMovieDirectly(item, resumePosition: session?.resumePosition);
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
    // Update local list
    final idx = _allMovies.indexWhere((m) => m.id == item.id);
    if (idx >= 0) {
      _allMovies[idx] = _allMovies[idx].copyWith(favorite: !isFav);
      _applyProviderFilter();
    }
  }

  @override
  Future<void> refresh() async {
    await _loadMovies();
  }
}
