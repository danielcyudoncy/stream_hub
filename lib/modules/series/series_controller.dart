// modules/series/series_controller.dart
import 'dart:async';
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

  StreamSubscription? _catalogSubscription;

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
    _catalogSubscription = catalogRepository.watchUpdates().listen((_) {
      _loadSeries();
    });
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

  @override
  void onClose() {
    _catalogSubscription?.cancel();
    super.onClose();
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
      var seriesItems = await catalogRepository.getByType(MediaType.series);
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
    final repo = playbackRepository;
    if (repo == null) return;
    try {
      final sessions = await repo.getAllWatchSessions();
      if (sessions.isEmpty || activeSeries.isEmpty) {
        continueWatching.clear();
        return;
      }

      final sessionsByItem = <String, PlaybackSessionModel>{
        for (final s in sessions) s.itemId: s,
      };

      // Query episodes ONCE across the whole catalog instead of querying inside the series loop
      final episodes = await catalogRepository.getByType(MediaType.episode);
      if (episodes.isEmpty) {
        continueWatching.clear();
        return;
      }

      // Group episodes by seriesId for O(1) lookup
      final episodesBySeriesId = <String, List<MediaItem>>{};
      for (final ep in episodes) {
        final sId = ep.metadata['seriesId']?.toString() ??
            ep.metadata['series_id']?.toString() ??
            (ep.id.contains('_') ? ep.id.substring(0, ep.id.lastIndexOf('_')) : null);
        if (sId != null && sId.isNotEmpty) {
          episodesBySeriesId.putIfAbsent(sId, () => []).add(ep);
        }
      }

      // Identify watched series: only process series that appear in watch sessions
      final watchedSeriesIds = <String>{};
      for (final session in sessions) {
        watchedSeriesIds.add(session.itemId);
        for (final ep in episodes) {
          if (ep.id == session.itemId) {
            final sId = ep.metadata['seriesId']?.toString() ??
                ep.metadata['series_id']?.toString();
            if (sId != null && sId.isNotEmpty) {
              watchedSeriesIds.add(sId);
            }
            break;
          }
        }
      }

      final cwList = <ContinueWatchingSeriesItem>[];
      final activeSeriesMap = {for (final s in activeSeries) s.id: s};

      for (final seriesId in watchedSeriesIds) {
        final s = activeSeriesMap[seriesId];
        if (s == null) continue;

        final seriesEpisodes = episodesBySeriesId[s.id] ??
            episodes.where((e) => e.id.startsWith('${s.id}_')).toList();
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
    // Sample up to 500 items to avoid string/regex parsing across 37k+ items
    final sample = allSeries.take(500);
    for (final s in sample) {
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
    if (allSeries.isEmpty) {
      featuredSeries.clear();
      trendingSeries.clear();
      topRatedSeries.clear();
      recentlyAddedSeries.clear();
      dramaSeries.clear();
      comedySeries.clear();
      actionAdventureSeries.clear();
      sciFiFantasySeries.clear();
      animationSeries.clear();
      documentarySeries.clear();
      return;
    }

    // Featured series - up to 6 top series with backdrop from first 200 candidates
    final candidateSample = allSeries.take(200).toList();
    final withBackdrop = candidateSample
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
      featuredSeries.assignAll(candidateSample.take(6).toList());
    }

    // Trending series - most recently updated
    trendingSeries.assignAll(allSeries.take(15).toList());

    // Top rated series - from candidate sample to avoid full-list sorting in memory
    final rated = allSeries.take(500).where((item) => item.rating != null).toList()
      ..sort((a, b) => b.rating!.compareTo(a.rating!));
    topRatedSeries.assignAll(rated.take(15).toList());

    // Recently added series - from candidate sample
    final recent = allSeries.take(500).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    recentlyAddedSeries.assignAll(recent.take(15).toList());

    // Genre-based sections - lazy iteration halts as soon as 15 items match
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
    for (final g in item.genres) {
      final lower = g.toLowerCase();
      for (final t in targets) {
        if (lower.contains(t)) return true;
      }
    }
    final metaGenre = item.metadata['genre']?.toString().toLowerCase();
    if (metaGenre != null) {
      for (final t in targets) {
        if (metaGenre.contains(t)) return true;
      }
    }
    final catName = (item.metadata['category_name'] ??
            item.metadata['categoryName'] ??
            item.metadata['group-title'])
        ?.toString()
        .toLowerCase();
    if (catName != null) {
      for (final t in targets) {
        if (catName.contains(t)) return true;
      }
    }
    return false;
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
