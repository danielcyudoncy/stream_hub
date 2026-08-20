// modules/series/series_details_controller.dart
import 'dart:async';
import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/repositories/playback_repository.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/series/next_episode_resolver.dart';
import 'package:stream_hub/core/streaming/series/series_progress_service.dart';
import 'package:stream_hub/core/streaming/series/xtream_series_info_service.dart';
import 'package:stream_hub/core/streaming/session/session_manager.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/data/models/cast_member.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playback_session_model.dart';
import 'package:stream_hub/data/models/series_progress.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';

/// Loads a series' seasons and episodes and prepares individual episodes for playback.
class SeriesDetailsController extends GetxController {
  final SessionManager sessionManager;
  final ProviderRepository providerRepository;
  final CatalogRepository catalogRepository;
  final XtreamSeriesInfoService seriesInfoService;
  final FavoriteRepository? favoriteRepository;
  final PlaybackRepository? playbackRepository;
  final LoggingService logger;
  final SeriesProgressService progressService;
  final NextEpisodeResolver resolver;
  final MediaItem? _initialSeries;

  SeriesDetailsController({
    required this.sessionManager,
    required this.providerRepository,
    required this.catalogRepository,
    required this.seriesInfoService,
    this.favoriteRepository,
    this.playbackRepository,
    this.progressService = const SeriesProgressService(),
    this.resolver = const NextEpisodeResolver(),
    LoggingService? logger,
    MediaItem? initialSeries,
  }) : logger = logger ?? LoggingService(),
       _initialSeries = initialSeries;

  MediaItem? _series;
  MediaItem get series => _series!;

  String get seriesTitle => _series?.title ?? 'Series';

  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final RxString infoMessage = ''.obs;

  final RxList<SeasonGroup> seasons = <SeasonGroup>[].obs;
  final RxInt selectedSeasonIndex = 0.obs;
  final RxBool isFavorite = false.obs;

  final Rx<SeriesProgress?> seriesProgress = Rx<SeriesProgress?>(null);
  final RxMap<String, double> episodeProgressMap = <String, double>{}.obs;
  final RxSet<String> completedEpisodeIds = <String>{}.obs;
  final RxList<MediaItem> relatedSeries = <MediaItem>[].obs;
  final RxList<CastMember> castMembers = <CastMember>[].obs;

  SeasonGroup? get selectedSeason {
    final index = selectedSeasonIndex.value;
    if (seasons.isEmpty || index < 0 || index >= seasons.length) return null;
    return seasons[index];
  }

  int get seasonCount => seasons.length;

  int get totalEpisodes =>
      seasons.fold(0, (sum, season) => sum + season.episodes.length);

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    _series = _initialSeries ??
        (args is MediaItem
            ? args
            : (args is Map ? args['item'] as MediaItem? : null));
    isFavorite.value = _series?.favorite ?? false;
    _parseCastMembers();
    _load();
  }

  void _parseCastMembers() {
    final s = _series;
    if (s == null) return;
    final rawCast = s.metadata['cast'] ?? s.metadata['actors'];
    if (rawCast is List) {
      castMembers.assignAll(
        rawCast.map((c) {
          if (c is Map) {
            return CastMember.fromMap(c);
          }
          return CastMember.fromString(c.toString());
        }).where((c) => c.name.isNotEmpty),
      );
    } else if (rawCast is String && rawCast.trim().isNotEmpty) {
      final names = rawCast.split(RegExp(r'[,;/]'));
      castMembers.assignAll(
        names
            .map((n) => CastMember.fromString(n))
            .where((c) => c.name.isNotEmpty),
      );
    }
  }


  Future<void> _load() async {
    isLoading.value = true;
    errorMessage.value = '';
    infoMessage.value = '';
    try {
      final series = _series;
      if (series == null) {
        errorMessage.value = 'No series was selected.';
        return;
      }
      final groups = await _fetchSeasonGroups(series);
      seasons.assignAll(groups);
      selectedSeasonIndex.value = 0;
      await _loadProgress();
      await _loadRelatedSeries();
    } on StreamSeriesInfoUnavailableException catch (e) {
      logger.warning(
        'Provider does not expose series info for ${_series?.id}',
        tag: 'SeriesDetailsController',
        error: e,
      );
      infoMessage.value =
          'Episode list unavailable from provider.\n'
          'Your provider may not support episode discovery for this series.';
    } catch (e) {
      logger.warning(
        'Failed to load episodes for series ${_series?.id} (error: $e)',
        tag: 'SeriesDetailsController',
        error: e,
      );
      errorMessage.value = 'Could not load episodes: ${e.toString()}';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadProgress() async {
    final s = _series;
    if (s == null || playbackRepository == null) return;
    try {
      final sessions = await playbackRepository!.getAllWatchSessions();
      final sessionsByItem = <String, PlaybackSessionModel>{
        for (final item in sessions) item.itemId: item,
      };

      for (final season in seasons) {
        for (final ep in season.episodes) {
          final sess = sessionsByItem[ep.id];
          if (sess != null) {
            episodeProgressMap[ep.id] = sess.completionPercentage;
            if (sess.completionPercentage >= 0.90) {
              completedEpisodeIds.add(ep.id);
            }
          }
        }
      }

      final computed = progressService.computeProgress(
        series: s,
        seasons: seasons,
        watchSessions: sessionsByItem,
      );
      seriesProgress.value = computed;

      // If there's an in-progress or next episode, auto-select its season tab
      final targetEp = computed.nextEpisodeToWatch;
      if (targetEp != null) {
        final targetSeasonNum = NextEpisodeResolver.seasonNumberFor(targetEp);
        final targetSeasonIdx = seasons.indexWhere((s) => s.number == targetSeasonNum);
        if (targetSeasonIdx >= 0) {
          selectedSeasonIndex.value = targetSeasonIdx;
        }
      }
    } catch (_) {}
  }

  Future<void> _loadRelatedSeries() async {
    final s = _series;
    if (s == null) return;
    try {
      final all = await catalogRepository.getByType(MediaType.series);
      final related = all.where((item) {
        if (item.id == s.id) return false;
        if (s.genres.isNotEmpty && item.genres.isNotEmpty) {
          return item.genres.any((g) => s.genres.contains(g));
        }
        return item.providerId == s.providerId;
      }).take(10).toList();
      relatedSeries.assignAll(related);
    } catch (_) {}
  }

  void selectSeason(int index) {
    if (index < 0 || index >= seasons.length) return;
    selectedSeasonIndex.value = index;
  }

  /// Reloads the season/episode structure (used by the retry action).
  Future<void> retry() => _load();

  Future<List<SeasonGroup>> _fetchSeasonGroups(MediaItem series) async {
    final seriesId = _seriesId(series);
    if (seriesId == null || seriesId.isEmpty) {
      throw StateError('This series has no provider identifier.');
    }

    if (series.providerType == MediaSourceType.xtream) {
      try {
        final groups = await _xtreamSeasonGroups(series, seriesId);
        if (groups.isNotEmpty) {
          _cacheEpisodes(groups);
          return groups;
        }
      } catch (e) {
        logger.info(
          'Failed live xtream season fetch for series $seriesId, attempting catalog fallback: $e',
          tag: 'SeriesDetailsController',
        );
      }
      final catalog = await _catalogSeasonGroups(series, seriesId);
      if (catalog.isNotEmpty) return catalog;
      throw const StreamSeriesInfoUnavailableException(
        message: 'No season or episode data available from provider.',
      );
    }

    // For non-Xtream providers, always try catalog first
    final catalog = await _catalogSeasonGroups(series, seriesId);
    if (catalog.isNotEmpty) return catalog;

    final fallback = _synthesizeFallbackSeason(series, seriesId);
    if (fallback.isNotEmpty) {
      unawaited(_cacheEpisodes(fallback));
      return fallback;
    }

    return const [];
  }

  List<SeasonGroup> _synthesizeFallbackSeason(MediaItem series, String seriesId) {
    final cmd = series.metadata['cmd']?.toString();
    final direct = series.metadata['directSource']?.toString() ??
        series.metadata['streamUrl']?.toString();
    if ((cmd == null || cmd.isEmpty) && (direct == null || direct.isEmpty)) {
      return const [];
    }

    final seriesRaw = series.metadata['series'] ?? series.metadata['episodes'];
    final epNumbers = <int>[];
    if (seriesRaw is List) {
      for (final el in seriesRaw) {
        final n = int.tryParse(el.toString());
        if (n != null) epNumbers.add(n);
      }
    } else if (seriesRaw is String && seriesRaw.isNotEmpty) {
      for (final part in seriesRaw.split(RegExp(r'[,;]'))) {
        final n = int.tryParse(part.trim());
        if (n != null) epNumbers.add(n);
      }
    } else if (seriesRaw is num && seriesRaw > 0) {
      for (var i = 1; i <= seriesRaw.toInt(); i++) {
        epNumbers.add(i);
      }
    }

    if (epNumbers.isEmpty) {
      epNumbers.add(1);
    }

    final episodes = epNumbers.map((epNum) {
      return MediaItem(
        id: '${series.id}_ep_$epNum',
        providerId: series.providerId,
        providerType: series.providerType,
        mediaType: MediaType.episode,
        title: epNumbers.length == 1 ? series.title : 'Episode $epNum',
        subtitle: 'Season 1',
        poster: series.poster,
        backdrop: series.backdrop,
        genres: series.genres,
        metadata: {
          ...series.metadata,
          'seriesId': seriesId,
          'episodeNumber': epNum,
          'seasonNumber': 1,
          'seriesIndex': epNum,
        },
        createdAt: series.createdAt,
        updatedAt: series.updatedAt,
      );
    }).toList();

    return [
      SeasonGroup(
        number: 1,
        name: 'Season 1',
        episodes: episodes,
      ),
    ];
  }

  Future<void> _cacheEpisodes(List<SeasonGroup> groups) async {
    try {
      final episodes = groups.expand((group) => group.episodes).toList();
      if (episodes.isNotEmpty) {
        await catalogRepository.upsertItems(episodes);
      }
    } catch (e) {
      logger.warning(
        'Failed to cache episodes for ${_series?.id}',
        tag: 'SeriesDetailsController',
        error: e,
      );
    }
  }

  Future<List<SeasonGroup>> _xtreamSeasonGroups(
    MediaItem series,
    String seriesId,
  ) async {
    final session = await _sessionFor(series);
    final streamId = series.metadata['streamId']?.toString();
    final info = await seriesInfoService.fetch(
      session: session,
      seriesId: seriesId,
      alternativeIds: [if (streamId != null && streamId.isNotEmpty) streamId],
    );
    if (info.seasons.isEmpty) return const [];
    return info.seasons.map((season) {
      return SeasonGroup(
        number: season.number,
        name: season.name,
        episodes: season.episodes
            .map(
              (episode) =>
                  _episodeMediaItem(series, session, episode, season: season),
            )
            .toList(),
      );
    }).toList();
  }

  Future<List<SeasonGroup>> _catalogSeasonGroups(
    MediaItem series,
    String seriesId,
  ) async {
    final allItems = await catalogRepository.getAllItems();
    final episodes = allItems.where((item) {
      return item.mediaType == MediaType.episode &&
          item.providerId == series.providerId &&
          (item.metadata['seriesId']?.toString() == seriesId ||
              item.id.startsWith('${series.id}_') ||
              item.id.startsWith('xtream-episode-$seriesId'));
    }).toList();

    if (episodes.isEmpty) return const [];

    int seasonNumberFor(MediaItem episode) {
      return int.tryParse(episode.metadata['seasonId']?.toString() ?? '') ??
          int.tryParse(episode.metadata['seasonNumber']?.toString() ?? '') ??
          0;
    }

    final grouped = <int, List<MediaItem>>{};
    final fallbackNames = <int, String>{};
    for (final episode in episodes) {
      final number = seasonNumberFor(episode);
      grouped.putIfAbsent(number, () => []).add(episode);
      final seasonName = episode.metadata['seasonName']?.toString();
      if (seasonName != null && seasonName.isNotEmpty) {
        fallbackNames.putIfAbsent(number, () => seasonName);
      }
    }

    final numbers = grouped.keys.toList()..sort();

    return numbers.map((number) {
      final seasonEpisodes = grouped[number]!;
      seasonEpisodes.sort((a, b) {
        final episodeA =
            int.tryParse(a.metadata['episodeNumber']?.toString() ?? '') ??
            int.tryParse(a.metadata['streamId']?.toString() ?? '') ??
            0;
        final episodeB =
            int.tryParse(b.metadata['episodeNumber']?.toString() ?? '') ??
            int.tryParse(b.metadata['streamId']?.toString() ?? '') ??
            0;
        return episodeA.compareTo(episodeB);
      });
      return SeasonGroup(
        number: number,
        name:
            fallbackNames[number] ??
            (number > 0 ? 'Season $number' : 'Episodes'),
        episodes: seasonEpisodes,
      );
    }).toList();
  }

  Future<ProviderSession> _sessionFor(MediaItem series) async {
    final provider = await providerRepository.getProviderById(
      series.providerId,
    );
    final providerConfig = provider != null
        ? <String, dynamic>{
            'providerId': provider.id,
            'serverUrl': provider.serverUrl,
            'portalUrl': provider.serverUrl,
            'username': provider.username,
            'password': provider.password,
            'macAddress': provider.macAddress,
          }
        : null;

    return sessionManager.getOrCreateSession(
      mediaItemId: series.id,
      providerType: series.providerType,
      itemMetadata: series.metadata,
      providerConfig: providerConfig,
      providerId: series.providerId,
    );
  }

  MediaItem _episodeMediaItem(
    MediaItem series,
    ProviderSession session,
    XtreamSeriesEpisode episode, {
    XtreamSeriesSeason? season,
  }) {
    final now = DateTime.now();
    return MediaItem(
      id: 'xtream-episode-${episode.id}',
      providerId: series.providerId,
      providerType: series.providerType,
      mediaType: MediaType.episode,
      title: episode.title,
      subtitle: 'S${episode.seasonNum} E${episode.episodeNum}',
      description: episode.plot,
      poster: (episode.cover != null && episode.cover!.isNotEmpty)
          ? episode.cover
          : series.poster,
      backdrop: series.backdrop,
      genres: series.genres,
      rating: series.rating,
      metadata: {
        'seriesId': _seriesId(series),
        'episodeId': episode.id,
        'seasonId': '${season?.number ?? episode.seasonNum}',
        'seasonNumber': episode.seasonNum,
        'seasonName': season?.name,
        'episodeNumber': episode.episodeNum,
        'streamUrl': episode.streamUrl(
          baseUrl: session.baseUrl,
          username: session.username,
          password: session.password,
        ),
        'isVod': true,
        'seriesTitle': series.title,
      },
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Triggers the primary action (Play S01E01 / Resume / Play Next / Watch Again).
  void playPrimaryAction() {
    final prog = seriesProgress.value;
    final allEps = seasons.expand((s) => s.episodes).toList();
    if (allEps.isEmpty) return;

    final target = prog?.nextEpisodeToWatch ?? allEps.first;
    Get.toNamed(
      AppRoutes.fullscreenPlayer,
      arguments: {
        'items': allEps,
        'currentId': target.id,
        if (prog?.actionType == SeriesWatchActionType.resume && prog?.currentPosition != null)
          'resumePosition': prog!.currentPosition,
      },
    );
  }

  /// Plays a single episode, passing all episodes in the season for next/prev playlist support.
  void playEpisode(MediaItem episode) {
    final allSeasonEps = selectedSeason?.episodes ?? seasons.expand((s) => s.episodes).toList();
    Get.toNamed(
      AppRoutes.fullscreenPlayer,
      arguments: {
        'items': allSeasonEps.isNotEmpty ? allSeasonEps : [episode],
        'currentId': episode.id,
      },
    );
  }

  /// Plays every episode of the currently selected season.
  void playSeason() {
    final season = selectedSeason;
    if (season == null || season.episodes.isEmpty) return;
    Get.toNamed(
      AppRoutes.fullscreenPlayer,
      arguments: {
        'items': season.episodes,
        'currentId': season.episodes.first.id,
      },
    );
  }

  Future<void> toggleFavorite() async {
    final item = _series;
    final repository = favoriteRepository;
    if (item == null || repository == null) return;
    try {
      if (isFavorite.value) {
        await repository.remove(item.id);
      } else {
        await repository.add(item.copyWith(favorite: true));
      }
      isFavorite.value = !isFavorite.value;
    } catch (e) {
      logger.warning(
        'Failed to toggle favorite for ${item.id}',
        tag: 'SeriesDetailsController',
        error: e,
      );
    }
  }

  void openRelatedSeries(MediaItem item) {
    Get.toNamed(AppRoutes.seriesDetails, arguments: item, preventDuplicates: false);
  }

  static String? _seriesId(MediaItem series) {
    final direct = series.metadata['seriesId']?.toString() ??
        series.metadata['series_id']?.toString() ??
        series.metadata['streamId']?.toString() ??
        series.metadata['stream_id']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    if (series.id.startsWith('xtream-series-')) {
      return series.id.replaceFirst('xtream-series-', '');
    }
    return series.id;
  }
}
