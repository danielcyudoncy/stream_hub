// modules/series/series_controller.dart
import 'package:get/get.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';
import '../../../core/media/repositories/playback_repository.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/streaming/series/next_episode_resolver.dart';
import '../../../core/streaming/series/series_progress_service.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/playback_session_model.dart';
import '../../../data/models/series_progress.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import '../../../data/repositories/provider_repository.dart';

class ContinueWatchingSeriesItem {
  final MediaItem series;
  final MediaItem? episode;
  final Duration position;
  final Duration duration;
  final SeriesProgress progress;

  const ContinueWatchingSeriesItem({
    required this.series,
    this.episode,
    required this.position,
    required this.duration,
    required this.progress,
  });
}

class SeriesController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;
  final PlaybackRepository? playbackRepository;
  final FavoriteRepository? favoriteRepository;
  final NextEpisodeResolver nextEpisodeResolver;
  final SeriesProgressService progressService;

  SeriesController({
    required this.mediaEngine,
    required this.mediaLibrary,
    required this.catalogRepository,
    PlaybackRepository? playbackRepository,
    FavoriteRepository? favoriteRepository,
    NextEpisodeResolver? nextEpisodeResolver,
    SeriesProgressService? progressService,
  })  : playbackRepository = playbackRepository ??
            (Get.isRegistered<PlaybackRepository>()
                ? Get.find<PlaybackRepository>()
                : null),
        favoriteRepository = favoriteRepository ??
            (Get.isRegistered<FavoriteRepository>()
                ? Get.find<FavoriteRepository>()
                : null),
        nextEpisodeResolver = nextEpisodeResolver ?? NextEpisodeResolver(),
        progressService =
            progressService ?? const SeriesProgressService();

  final RxBool isLoading = true.obs;
  final RxString selectedProvider = ''.obs;
  final RxList<MediaItem> series = <MediaItem>[].obs;
  final List<MediaItem> _allSeries = <MediaItem>[];
  final RxList<MediaItem> featuredSeries = <MediaItem>[].obs;
  final RxList<ContinueWatchingSeriesItem> continueWatching = <ContinueWatchingSeriesItem>[].obs;
  final RxList<MediaItem> trendingSeries = <MediaItem>[].obs;
  final RxList<MediaItem> topRatedSeries = <MediaItem>[].obs;
  final RxList<MediaItem> recentlyAddedSeries = <MediaItem>[].obs;
  final RxList<MediaItem> dramaSeries = <MediaItem>[].obs;
  final RxList<MediaItem> comedySeries = <MediaItem>[].obs;
  final RxList<MediaItem> actionAdventureSeries = <MediaItem>[].obs;
  final RxList<MediaItem> sciFiFantasySeries = <MediaItem>[].obs;
  final RxList<MediaItem> animationSeries = <MediaItem>[].obs;
  final RxList<MediaItem> documentarySeries = <MediaItem>[].obs;

  final RxMap<String, double> progressMap = <String, double>{}.obs;
  final RxSet<String> completedSeriesIds = <String>{}.obs;
  final RxList<String> availableGenres = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<ProviderRepository>()) {
      final providerRepo = Get.find<ProviderRepository>();
      selectedProvider.value = providerRepo.activeProviderId.value;
      ever(providerRepo.activeProviderId, (id) {
        if (selectedProvider.value != id) {
          selectedProvider.value = id;
          _applyProviderFilter();
        }
      });
    }
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
    if (selectedProvider.value == providerId) return;
    selectedProvider.value = providerId;
    if (Get.isRegistered<ProviderRepository>()) {
      final providerRepo = Get.find<ProviderRepository>();
      if (providerRepo.activeProviderId.value != providerId) {
        providerRepo.setActiveProviderId(providerId);
      }
    }
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
    _computeGenres(filtered);
    _loadContinueWatching(filtered);
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

  Future<void> _loadContinueWatching(List<MediaItem> activeSeries) async {
    if (playbackRepository == null) return;
    try {
      final sessions = await playbackRepository!.getAllWatchSessions();
      if (sessions.isEmpty) {
        continueWatching.clear();
        return;
      }

      final sessionsByItem = <String, PlaybackSessionModel>{
        for (final s in sessions) s.itemId: s,
      };

      final cwList = <ContinueWatchingSeriesItem>[];

      for (final s in activeSeries) {
        // Find episodes for this series
        final episodes = await catalogRepository.getByType(MediaType.episode);
        final seriesEpisodes = episodes.where((e) {
          final sId = e.metadata['seriesId']?.toString() ?? e.metadata['series_id']?.toString();
          return sId == s.id || e.id.startsWith('${s.id}_');
        }).toList();

        if (seriesEpisodes.isEmpty) continue;

        // Group into seasons
        final seasonsMap = <int, List<MediaItem>>{};
        for (final ep in seriesEpisodes) {
          final sNum = NextEpisodeResolver.seasonNumberFor(ep);
          seasonsMap.putIfAbsent(sNum, () => []).add(ep);
        }
        final seasonGroups = seasonsMap.entries.map((e) {
          return SeasonGroup(
            number: e.key,
            name: 'Season ${e.key}',
            episodes: e.value,
          );
        }).toList();

        final prog = progressService.computeProgress(
          series: s,
          seasons: seasonGroups,
          watchSessions: sessionsByItem,
        );

        if (prog.overallPercentage > 0) {
          progressMap[s.id] = prog.overallPercentage;
        }
        if (prog.isCompleted) {
          completedSeriesIds.add(s.id);
        }

        // If in-progress or next up, add to continue watching list
        if (!prog.isCompleted && prog.actionType == SeriesWatchActionType.resume) {
          cwList.add(ContinueWatchingSeriesItem(
            series: s,
            episode: prog.nextEpisodeToWatch ?? prog.currentEpisode,
            position: prog.currentPosition,
            duration: prog.currentDuration,
            progress: prog,
          ));
        }
      }

      continueWatching.assignAll(cwList);
    } catch (_) {}
  }

  static final RegExp _kLiveTvMarkerPattern = RegExp(
    r'(\b(live|itv|channel|fhd|hevc|uhd|4k|sd|h265|radio|epg|stream|24/7|sports\s*\d)\b|^uk\s*:|^us\s*:|^ca\s*:|^all\s+channels$)',
    caseSensitive: false,
  );

  void _computeGenres(List<MediaItem> allSeries) {
    final genreSet = <String>{};
    for (final s in allSeries) {
      for (final g in s.genres) {
        final clean = g.trim();
        if (clean.isEmpty) continue;

        // Skip raw numeric IDs that failed mapping
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
    }
    final sorted = genreSet.toList()..sort();
    availableGenres.assignAll(sorted);
  }

  void _computeSections(List<MediaItem> allSeries) {
    // Featured series - up to 6 top series with backdrop for the hero carousel
    final withBackdrop = allSeries
        .where((item) => item.backdrop != null && item.backdrop!.isNotEmpty)
        .toList();
    if (withBackdrop.isNotEmpty) {
      withBackdrop.sort((a, b) {
        final rA = a.rating ?? 0.0;
        final rB = b.rating ?? 0.0;
        final rComp = rB.compareTo(rA);
        if (rComp != 0) return rComp;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      featuredSeries.assignAll(withBackdrop.take(6).toList());
    } else {
      featuredSeries.assignAll(allSeries.take(6).toList());
    }

    // Trending series - most recently updated
    trendingSeries.assignAll(
      allSeries.take(15).toList(),
    );

    // Top rated series - sorted by rating
    final rated = allSeries.where((item) => item.rating != null).toList()
      ..sort((a, b) => b.rating!.compareTo(a.rating!));
    topRatedSeries.assignAll(rated.take(15).toList());

    // Recently added series - sorted by createdAt
    final recent = List<MediaItem>.of(allSeries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    recentlyAddedSeries.assignAll(recent.take(15).toList());

    // Genre-based sections - strictly contain items that actually match the genre
    dramaSeries.assignAll(allSeries.where(_isDrama).take(15).toList());
    comedySeries.assignAll(allSeries.where(_isComedy).take(15).toList());
    actionAdventureSeries.assignAll(
      allSeries.where(_isActionOrAdventure).take(15).toList(),
    );
    sciFiFantasySeries.assignAll(
      allSeries.where(_isSciFiOrFantasy).take(15).toList(),
    );
    animationSeries.assignAll(allSeries.where(_isAnimation).take(15).toList());
    documentarySeries.assignAll(
      allSeries.where(_isDocumentary).take(15).toList(),
    );
  }

  // Genre filters
  bool _isDrama(MediaItem item) => _hasGenre(item, ['drama']);
  bool _isComedy(MediaItem item) => _hasGenre(item, ['comedy']);
  bool _isActionOrAdventure(MediaItem item) =>
      _hasGenre(item, ['action', 'adventure']);
  bool _isSciFiOrFantasy(MediaItem item) =>
      _hasGenre(item, ['sci-fi', 'scifi', 'science', 'fantasy']);
  bool _isAnimation(MediaItem item) =>
      _hasGenre(item, ['animation', 'anime', 'cartoon']);
  bool _isDocumentary(MediaItem item) =>
      _hasGenre(item, ['documentary', 'doc', 'biography']);

  bool _hasGenre(MediaItem item, List<String> targets) {
    final genreStrings = <String>[
      ...item.genres,
      if (item.metadata['genre'] != null) item.metadata['genre'].toString(),
      if (item.metadata['category_name'] != null)
        item.metadata['category_name'].toString(),
      if (item.metadata['categoryName'] != null)
        item.metadata['categoryName'].toString(),
      if (item.metadata['group-title'] != null)
        item.metadata['group-title'].toString(),
    ].map((g) => g.toLowerCase());

    return genreStrings.any((g) => targets.any((t) => g.contains(t)));
  }


  void openSeries(MediaItem item) {
    Get.toNamed(AppRoutes.seriesDetails, arguments: item);
  }

  void openGenre(String genreName) {
    Get.toNamed(AppRoutes.seriesGenre, arguments: genreName);
  }

  Future<void> toggleFavorite(MediaItem item) async {
    if (favoriteRepository == null) return;
    if (item.favorite) {
      await favoriteRepository!.remove(item.id);
    } else {
      await favoriteRepository!.add(item.copyWith(favorite: true));
    }
    _loadSeries();
  }

  @override
  Future<void> refresh() async {
    await _loadSeries();
  }
}
