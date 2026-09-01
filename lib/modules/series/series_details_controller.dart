// modules/series/series_details_controller.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/enums/playback_engine_preference.dart';
import 'package:stream_hub/core/media/player/exo_player_surface_view_adapter.dart';
import 'package:stream_hub/core/media/player/ijk_player_adapter.dart';
import 'package:stream_hub/core/media/player/vlc_player_adapter.dart';
import 'package:stream_hub/core/media/repositories/playback_repository.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/core/streaming/series/next_episode_resolver.dart';
import 'package:stream_hub/core/streaming/series/series_progress_service.dart';
import 'package:stream_hub/core/streaming/series/xtream_series_info_service.dart';
import 'package:stream_hub/core/streaming/session/session_manager.dart';
import 'package:stream_hub/data/models/cast_member.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playback_session_model.dart';
import 'package:stream_hub/data/models/series_progress.dart';
import 'package:stream_hub/data/providers/stalker/stalker_portal_client.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/data/repositories/history_repository.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
import 'package:stream_hub/modules/settings/settings_controller.dart';

/// Loads a series' seasons and episodes and prepares individual episodes for playback.
class SeriesDetailsController extends GetxController {
  final SessionManager sessionManager;
  final ProviderRepository providerRepository;
  final CatalogRepository catalogRepository;
  final XtreamSeriesInfoService seriesInfoService;
  final FavoriteRepository? favoriteRepository;
  final PlaybackRepository? playbackRepository;
  final StreamRepository? streamRepository;
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
    this.streamRepository,
    this.progressService = const SeriesProgressService(),
    this.resolver = const NextEpisodeResolver(),
    LoggingService? logger,
    MediaItem? initialSeries,
  }) : logger = logger ?? LoggingService(),
       _initialSeries = initialSeries;

  final Rx<MediaItem?> _series = Rx<MediaItem?>(null);
  MediaItem? get series => _series.value;
  Rx<MediaItem?> get seriesRx => _series;

  String get seriesTitle => _series.value?.title ?? 'Series';

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

  PlayerController? inlinePlayerController;
  final RxBool isInlinePlayerActive = false.obs;
  final Rx<MediaItem?> activeEpisode = Rx<MediaItem?>(null);
  final RxBool isFullscreenMode = false.obs;
  DateTime lastFullscreenEntered = DateTime.fromMillisecondsSinceEpoch(0);

  SeasonGroup? get selectedSeason {
    final index = selectedSeasonIndex.value;
    if (seasons.isEmpty || index < 0 || index >= seasons.length) return null;
    return seasons[index];
  }

  int get seasonCount => seasons.length;

  int get totalEpisodes =>
      seasons.fold(0, (sum, season) => sum + season.episodes.length);

  @override
  void onClose() {
    stopInlinePlayback();
    inlinePlayerController?.onClose();
    super.onClose();
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    _series.value = _initialSeries ??
        (args is MediaItem
            ? args
            : (args is Map ? args['item'] as MediaItem? : null));
    isFavorite.value = _series.value?.favorite ?? false;
    _parseCastMembers();
    _load();
  }

  void _parseCastMembers() {
    final s = _series.value;
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
      final current = _series.value;
      if (current == null) {
        errorMessage.value = 'No series was selected.';
        return;
      }
      final groups = await _fetchSeasonGroups(current);
      seasons.assignAll(groups);
      selectedSeasonIndex.value = 0;
      await _loadProgress();
      await _loadRelatedSeries();
    } on StreamSeriesInfoUnavailableException catch (e) {
      logger.warning(
        'Provider does not expose series info for ${_series.value?.id}',
        tag: 'SeriesDetailsController',
        error: e,
      );
      infoMessage.value =
          'Episode list unavailable from provider.\n'
          'Your provider may not support episode discovery for this series.';
    } catch (e) {
      logger.warning(
        'Failed to load episodes for series ${_series.value?.id} (error: $e)',
        tag: 'SeriesDetailsController',
        error: e,
      );
      errorMessage.value = 'Could not load episodes: ${e.toString()}';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadProgress() async {
    final s = _series.value;
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
    final s = _series.value;
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

    if (series.providerType == MediaSourceType.stalker) {
      try {
        final groups = await _stalkerSeasonGroups(series, seriesId);
        if (groups.isNotEmpty) {
          _cacheEpisodes(groups);
          return groups;
        }
      } catch (e) {
        logger.info(
          'Failed live stalker season fetch for series $seriesId, attempting catalog fallback: $e',
          tag: 'SeriesDetailsController',
        );
      }
    }

    // For other providers or fallbacks, try catalog first
    final catalog = await _catalogSeasonGroups(series, seriesId);
    if (catalog.isNotEmpty) return catalog;

    final fallback = _synthesizeFallbackSeason(series, seriesId);
    if (fallback.isNotEmpty) {
      unawaited(_cacheEpisodes(fallback));
      return fallback;
    }

    return const [];
  }

  Future<List<SeasonGroup>> _stalkerSeasonGroups(
    MediaItem series,
    String seriesId,
  ) async {
    final session = await _sessionFor(series);
    final baseUrl = session.baseUrl ?? series.metadata['portalUrl']?.toString();
    final mac = session.macAddress ?? series.metadata['macAddress']?.toString();
    if (baseUrl == null || baseUrl.isEmpty || mac == null || mac.isEmpty) {
      return const [];
    }

    final client = StalkerPortalClient(
      baseUrl: baseUrl,
      macAddress: mac,
      serial: session.deviceId,
      token: session.portalToken,
      logger: logger,
    );

    final rawSeasons = await client.getSeriesSeasons(seriesId);
    if (rawSeasons.isEmpty) return const [];

    final groups = <SeasonGroup>[];
    for (var i = 0; i < rawSeasons.length; i++) {
      final seasonItem = rawSeasons[i];
      final seasonName = seasonItem['name']?.toString() ?? 'Season ${i + 1}';
      final seasonNum = int.tryParse(seasonItem['season_num']?.toString() ?? '') ??
          int.tryParse(seasonItem['season_number']?.toString() ?? '') ??
          (seasonItem['id'] != null && seasonItem['id'].toString().contains(':')
              ? int.tryParse(seasonItem['id'].toString().split(':').last)
              : null) ??
          int.tryParse(RegExp(r'\d+').firstMatch(seasonName)?.group(0) ?? '') ??
          (i + 1);
      final seasonCmd = seasonItem['cmd']?.toString() ?? series.metadata['cmd']?.toString() ?? '';

      final epListRaw = seasonItem['series'] ?? seasonItem['episodes'] ?? seasonItem['files'];
      final epNumbers = <int>[];
      if (epListRaw is List) {
        for (final el in epListRaw) {
          final n = int.tryParse(el.toString());
          if (n != null) epNumbers.add(n);
        }
      } else if (epListRaw is String && epListRaw.isNotEmpty) {
        for (final part in epListRaw.split(RegExp(r'[,;]'))) {
          final n = int.tryParse(part.trim());
          if (n != null) epNumbers.add(n);
        }
      } else if (epListRaw is num && epListRaw > 0) {
        for (var ep = 1; ep <= epListRaw.toInt(); ep++) {
          epNumbers.add(ep);
        }
      }

      if (epNumbers.isEmpty) {
        epNumbers.add(1);
      } else {
        epNumbers.sort();
      }

      final episodes = epNumbers.map((epNum) {
        return MediaItem(
          id: '${series.id}_s${seasonNum}_ep$epNum',
          providerId: series.providerId,
          providerType: series.providerType,
          mediaType: MediaType.episode,
          title: epNumbers.length == 1 && seasonItem['name'] != null ? '${seasonItem['name']}' : 'Episode $epNum',
          subtitle: seasonName,
          poster: seasonItem['screenshot_uri']?.toString() ?? series.poster,
          backdrop: series.backdrop,
          genres: series.genres,
          metadata: {
            ...series.metadata,
            'type': 'series',
            'seriesId': seriesId,
            'seasonNumber': seasonNum,
            'episodeNumber': epNum,
            'seriesIndex': epNum,
            if (seasonCmd.isNotEmpty) 'cmd': seasonCmd,
          },
          createdAt: series.createdAt,
          updatedAt: series.updatedAt,
        );
      }).toList();

      groups.add(
        SeasonGroup(
          number: seasonNum,
          name: seasonName,
          episodes: episodes,
        ),
      );
    }
    _sortSeasonGroups(groups);
    return groups;
  }

  List<SeasonGroup> _sortSeasonGroups(List<SeasonGroup> groups) {
    groups.sort((a, b) => a.number.compareTo(b.number));
    for (final group in groups) {
      group.episodes.sort((a, b) {
        final epA = int.tryParse(a.metadata['episodeNumber']?.toString() ?? '') ??
            int.tryParse(a.metadata['seriesIndex']?.toString() ?? '') ??
            int.tryParse(RegExp(r'\d+').firstMatch(a.title)?.group(0) ?? '') ??
            0;
        final epB = int.tryParse(b.metadata['episodeNumber']?.toString() ?? '') ??
            int.tryParse(b.metadata['seriesIndex']?.toString() ?? '') ??
            int.tryParse(RegExp(r'\d+').firstMatch(b.title)?.group(0) ?? '') ??
            0;
        return epA.compareTo(epB);
      });
    }
    return groups;
  }

  List<SeasonGroup> _synthesizeFallbackSeason(MediaItem series, String seriesId) {
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
        'Failed to cache episodes for ${_series.value?.id}',
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

    // Enrich series metadata with rich overview, cast, rating, cover, backdrop
    final currentSeries = _series.value;
    if (currentSeries != null) {
      final updatedPlot = (info.plot != null && info.plot!.isNotEmpty)
          ? info.plot
          : (currentSeries.description != null && currentSeries.description!.isNotEmpty
              ? currentSeries.description
              : null);
      final updatedCover = info.cover.isNotEmpty ? info.cover : currentSeries.poster;
      final updatedBackdrop = info.backdrop.isNotEmpty ? info.backdrop : currentSeries.backdrop;
      final updatedRating = info.rating ?? currentSeries.rating;
      final updatedGenres = (info.genre != null && info.genre!.isNotEmpty)
          ? info.genre!
              .split(RegExp(r'[,;/]'))
              .map((g) => g.trim())
              .where((g) => g.isNotEmpty)
              .toList()
          : currentSeries.genres;

      final newMeta = <String, dynamic>{
        ...currentSeries.metadata,
        if (info.cast != null && info.cast!.isNotEmpty) 'cast': info.cast,
        if (info.director != null && info.director!.isNotEmpty) 'director': info.director,
        if (info.releaseDate != null && info.releaseDate!.isNotEmpty) 'releaseDate': info.releaseDate,
        if (info.youtubeTrailer != null && info.youtubeTrailer!.isNotEmpty) 'youtubeTrailer': info.youtubeTrailer,
      };

      _series.value = currentSeries.copyWith(
        description: updatedPlot,
        poster: updatedCover,
        backdrop: updatedBackdrop,
        rating: updatedRating,
        genres: updatedGenres.isNotEmpty ? updatedGenres : currentSeries.genres,
        metadata: newMeta,
      );
      _parseCastMembers();
    }

    final groups = info.seasons.map((season) {
      return SeasonGroup(
        number: season.number,
        name: season.name,
        episodes: season.episodes
            .map(
              (episode) =>
                  _episodeMediaItem(_series.value ?? series, session, episode, season: season),
            )
            .toList(),
      );
    }).toList();
    _sortSeasonGroups(groups);
    return groups;
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
      subtitle: (season?.name != null && season!.name.isNotEmpty)
          ? season.name
          : 'Season ${episode.seasonNum > 0 ? episode.seasonNum : 1}',
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
        if (episode.durationSeconds != null) 'duration': episode.durationSeconds,
        if (episode.durationSeconds != null) 'durationSeconds': episode.durationSeconds,
        if (episode.airDate != null) 'airDate': episode.airDate,
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

  void _initInlinePlayer() {
    if (inlinePlayerController != null) return;

    PlaybackEngineKind chosenEngine = PlaybackEngineKind.mediaKit;
    final settingsCtrl = Get.isRegistered<SettingsController>()
        ? Get.find<SettingsController>()
        : null;
    if (settingsCtrl != null) {
      final pref = settingsCtrl.preferredPlayer.value;
      if (pref == PlaybackEnginePreference.exoPlayer &&
          ExoPlayerSurfaceViewAdapter.isSupported) {
        chosenEngine = PlaybackEngineKind.exoPlayer;
      } else if (pref == PlaybackEnginePreference.vlc &&
          VlcPlayerAdapter.isSupported) {
        chosenEngine = PlaybackEngineKind.vlc;
      } else if (pref == PlaybackEnginePreference.ijk &&
          IjkPlayerAdapter.isSupported) {
        chosenEngine = PlaybackEngineKind.ijk;
      } else if (pref == PlaybackEnginePreference.mediaKit) {
        chosenEngine = PlaybackEngineKind.mediaKit;
      } else {
        if (ExoPlayerSurfaceViewAdapter.isSupported) {
          chosenEngine = PlaybackEngineKind.exoPlayer;
        } else {
          chosenEngine = PlaybackEngineKind.mediaKit;
        }
      }
    } else if (ExoPlayerSurfaceViewAdapter.isSupported) {
      chosenEngine = PlaybackEngineKind.exoPlayer;
    }

    final sRepo = streamRepository ??
        (Get.isRegistered<StreamRepository>()
            ? Get.find<StreamRepository>()
            : null);
    if (sRepo == null) {
      logger.warning(
        'SeriesDetailsController: StreamRepository not available, skipping player instantiation',
      );
      return;
    }

    inlinePlayerController = PlayerController(
      engineKind: chosenEngine,
      streamRepository: sRepo,
      historyRepository: Get.isRegistered<HistoryRepository>()
          ? Get.find<HistoryRepository>()
          : null,
      favoriteRepository: favoriteRepository,
      playbackRepository: playbackRepository,
      catalogRepository: catalogRepository,
    );
    inlinePlayerController!.onInit();
  }

  void _activateInlinePlayer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isClosed) {
        isInlinePlayerActive.value = true;
      }
    });
  }

  /// Starts inline playback for a specific episode.
  Future<void> startEpisodePlayback(
    MediaItem episode, {
    Duration? resumePosition,
  }) async {
    activeEpisode.value = episode;
    _activateInlinePlayer();

    _initInlinePlayer();
    if (inlinePlayerController == null) return;
    final allSeasonEps = selectedSeason?.episodes ?? seasons.expand((s) => s.episodes).toList();
    final itemsToPass = allSeasonEps.isNotEmpty ? allSeasonEps : [episode];
    inlinePlayerController?.setChannelList(itemsToPass, currentId: episode.id);
    inlinePlayerController?.setVolume(1.0);

    // Resolve resume position if not provided
    var startPos = resumePosition;
    if (startPos == null && playbackRepository != null) {
      final progress = await playbackRepository!.getWatchProgress(episode.id);
      if (progress != null && progress > Duration.zero) {
        startPos = progress;
      }
    }

    await inlinePlayerController?.playMediaItem(
      episode,
      resumePosition: startPos,
    );
  }

  /// Stops inline playback and saves current watch progress.
  Future<void> stopInlinePlayback() async {
    final ep = activeEpisode.value;
    if (ep != null && inlinePlayerController != null && playbackRepository != null) {
      final currentPos = inlinePlayerController!.playbackController.engine.positionRx.value;
      final totalDur = inlinePlayerController!.playbackController.engine.durationRx.value;
      if (currentPos > Duration.zero && totalDur > Duration.zero) {
        await playbackRepository!.saveWatchProgress(ep, currentPos, totalDur);
        await _loadProgress();
      }
    }
    isInlinePlayerActive.value = false;
    isFullscreenMode.value = false;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    inlinePlayerController?.stop();
  }

  void expandToFullscreen() {
    if (!isInlinePlayerActive.value && seasons.isNotEmpty) {
      playPrimaryAction();
    }
    lastFullscreenEntered = DateTime.now();
    isFullscreenMode.value = true;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void exitFullscreen() {
    isFullscreenMode.value = false;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void toggleFullscreen() {
    if (isFullscreenMode.value) {
      exitFullscreen();
    } else {
      expandToFullscreen();
    }
  }

  /// Triggers the primary action (Play S01E01 / Resume / Play Next / Watch Again).
  void playPrimaryAction() {
    final prog = seriesProgress.value;
    final allEps = seasons.expand((s) => s.episodes).toList();
    if (allEps.isEmpty) return;

    final target = prog?.nextEpisodeToWatch ?? allEps.first;
    startEpisodePlayback(
      target,
      resumePosition: (prog?.actionType == SeriesWatchActionType.resume && prog?.currentPosition != null)
          ? prog!.currentPosition
          : null,
    );
  }

  /// Plays a single episode in the inline player.
  void playEpisode(MediaItem episode) {
    startEpisodePlayback(episode);
  }

  /// Plays every episode of the currently selected season.
  void playSeason() {
    final season = selectedSeason;
    if (season == null || season.episodes.isEmpty) return;
    startEpisodePlayback(season.episodes.first);
  }

  /// Plays the next episode in sequence.
  void playNextEpisode() {
    final current = activeEpisode.value;
    if (current == null) return;
    final allEps = seasons.expand((s) => s.episodes).toList();
    final idx = allEps.indexWhere((e) => e.id == current.id);
    if (idx >= 0 && idx + 1 < allEps.length) {
      startEpisodePlayback(allEps[idx + 1]);
    }
  }

  /// Plays the previous episode in sequence.
  void playPreviousEpisode() {
    final current = activeEpisode.value;
    if (current == null) return;
    final allEps = seasons.expand((s) => s.episodes).toList();
    final idx = allEps.indexWhere((e) => e.id == current.id);
    if (idx > 0) {
      startEpisodePlayback(allEps[idx - 1]);
    }
  }

  Future<void> toggleFavorite() async {
    final item = _series.value;
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

  void selectSeries(MediaItem item) {
    stopInlinePlayback();
    activeEpisode.value = null;
    _series.value = item;
    isFavorite.value = item.favorite;
    _parseCastMembers();
    seasons.clear();
    selectedSeasonIndex.value = 0;
    _load();
  }

  void openRelatedSeries(MediaItem item) {
    selectSeries(item);
  }

  static String? _seriesId(MediaItem series) {
    final direct = series.metadata['seriesId']?.toString() ??
        series.metadata['series_id']?.toString() ??
        series.metadata['streamId']?.toString() ??
        series.metadata['stream_id']?.toString();
    if (direct != null && direct.isNotEmpty) {
      return direct.contains(':') ? direct.split(':').first : direct;
    }
    if (series.id.startsWith('xtream-series-')) {
      return series.id.replaceFirst('xtream-series-', '');
    }
    if (series.id.startsWith('stalker-series-')) {
      final raw = series.id.replaceFirst('stalker-series-', '');
      return raw.contains(':') ? raw.split(':').first : raw;
    }
    if (series.id.startsWith('stalker-vod-')) {
      final raw = series.id.replaceFirst('stalker-vod-', '');
      return raw.contains(':') ? raw.split(':').first : raw;
    }
    if (series.id.contains(':')) {
      return series.id.split(':').first;
    }
    return series.id;
  }
}
