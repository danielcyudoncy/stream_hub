import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/series/xtream_series_info_service.dart';
import 'package:stream_hub/core/streaming/session/session_manager.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';

/// A group of episodes that belong to one season.
class SeasonGroup {
  final int number;
  final String name;
  final List<MediaItem> episodes;

  const SeasonGroup({
    required this.number,
    required this.name,
    required this.episodes,
  });
}

/// Loads a series' seasons and episodes and prepares individual episodes for
/// playback.
///
/// Xtream episodes are discovered live through `get_series_info`. Stalker
/// episodes were already synced into the local catalog during provider sync,
/// so they are read from there. The UI consumes only normalized [MediaItem]s.
class SeriesDetailsController extends GetxController {
  final SessionManager sessionManager;
  final ProviderRepository providerRepository;
  final CatalogRepository catalogRepository;
  final XtreamSeriesInfoService seriesInfoService;
  final FavoriteRepository? favoriteRepository;
  final LoggingService logger;
  final MediaItem? _initialSeries;

  SeriesDetailsController({
    required this.sessionManager,
    required this.providerRepository,
    required this.catalogRepository,
    required this.seriesInfoService,
    this.favoriteRepository,
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
        (args is Map<String, dynamic> ? args['item'] as MediaItem? : null);
    isFavorite.value = _series?.favorite ?? false;
    _load();
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
    } on StreamSeriesInfoUnavailableException catch (e) {
      logger.warning(
        'Provider does not expose series info for ${_series?.id}',
        tag: 'SeriesDetailsController',
        error: e,
      );
      infoMessage.value =
          'Your provider does not expose an episode list for this series.';
    } catch (e) {
      logger.warning(
        'Failed to load episodes for series ${_series?.id}',
        tag: 'SeriesDetailsController',
        error: e,
      );
      errorMessage.value = 'Could not load episodes for this series.\n$e';
    } finally {
      isLoading.value = false;
    }
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
        _cacheEpisodes(groups);
        return groups;
      } on StreamSeriesInfoUnavailableException {
        final catalog = await _catalogSeasonGroups(series, seriesId);
        if (catalog.isNotEmpty) return catalog;
        rethrow;
      }
    }

    return _catalogSeasonGroups(series, seriesId);
  }

  /// Persists freshly discovered episodes into the local catalog so the
  /// catalog fallback (and the unified library) has them for later opens —
  /// including offline and panels whose `get_series_info` is flaky.
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

  /// Fetches the live `get_series_info` structure for Xtream panels. Falls back
  /// to the stream ID when the panel rejects the series ID with 404.
  Future<List<SeasonGroup>> _xtreamSeasonGroups(
    MediaItem series,
    String seriesId,
  ) async {
    final session = await _sessionFor(series);
    final streamId = series.metadata['streamId']?.toString();
    final info = await seriesInfoService.fetch(
      session: session,
      seriesId: seriesId,
      alternativeIds: [
        if (streamId != null && streamId.isNotEmpty) streamId,
      ],
    );
    if (info.seasons.isEmpty) return const [];
    return info.seasons.map((season) {
      return SeasonGroup(
        number: season.number,
        name: season.name,
        episodes: season.episodes
            .map(
              (episode) => _episodeMediaItem(
                series,
                session,
                episode,
                season: season,
              ),
            )
            .toList(),
      );
    }).toList();
  }

  /// Groups episodes that were already persisted during provider sync
  /// (e.g. Stalker portals) by season. Returns an empty list when the provider
  /// synced no episodes for this series.
  Future<List<SeasonGroup>> _catalogSeasonGroups(
    MediaItem series,
    String seriesId,
  ) async {
    final allItems = await catalogRepository.getAllItems();
    final episodes = allItems.where((item) {
      return item.mediaType == MediaType.episode &&
          item.providerId == series.providerId &&
          item.metadata['seriesId']?.toString() == seriesId;
    }).toList();

    if (episodes.isEmpty) return const [];

    int seasonNumberFor(MediaItem episode) {
      return int.tryParse(
            episode.metadata['seasonId']?.toString() ?? '',
          ) ??
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
        final episodeA = int.tryParse(
              a.metadata['episodeNumber']?.toString() ?? '',
            ) ??
            int.tryParse(a.metadata['streamId']?.toString() ?? '') ??
            0;
        final episodeB = int.tryParse(
              b.metadata['episodeNumber']?.toString() ?? '',
            ) ??
            int.tryParse(b.metadata['streamId']?.toString() ?? '') ??
            0;
        return episodeA.compareTo(episodeB);
      });
      return SeasonGroup(
        number: number,
        name: fallbackNames[number] ?? (number > 0 ? 'Season $number' : 'Episodes'),
        episodes: seasonEpisodes,
      );
    }).toList();
  }

  Future<ProviderSession> _sessionFor(MediaItem series) async {
    final provider = await providerRepository.getProviderById(series.providerId);
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

    logger.debug(
      'SeriesDetailsController._sessionFor: '
      'providerId=${series.providerId}, '
      'providerFound=${provider != null}, '
      'usernameInProvider=${provider?.username != null && provider!.username!.isNotEmpty}, '
      'passwordInProvider=${provider?.password != null && provider!.password!.isNotEmpty}',
      tag: 'SeriesDetailsController',
    );

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

  /// Plays a single episode.
  void playEpisode(MediaItem episode) {
    Get.toNamed(
      AppRoutes.fullscreenPlayer,
      arguments: {
        'items': [episode],
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

  static String? _seriesId(MediaItem series) {
    return series.metadata['seriesId']?.toString() ??
        series.metadata['streamId']?.toString();
  }
}
