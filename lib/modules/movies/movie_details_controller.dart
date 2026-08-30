import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../core/iptv/models/player_negotiation.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/media/enums/playback_engine_preference.dart';
import '../../../core/media/media_library.dart';
import '../../../core/media/player/exo_player_surface_view_adapter.dart';
import '../../../core/media/player/ijk_player_adapter.dart';
import '../../../core/media/player/vlc_player_adapter.dart';
import '../../../core/media/repositories/playback_repository.dart';
import '../../../core/streaming/repositories/stream_repository.dart';
import '../../../core/streaming/vod/xtream_vod_info_service.dart';
import '../../../data/models/cast_member.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/playback_session_model.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import '../../../data/repositories/history_repository.dart';
import '../player/controllers/player_controller.dart';
import '../settings/settings_controller.dart';

enum MoviePlayAction {
  play,
  resume,
  watchAgain,
}

class MovieDetailsController extends GetxController {
  final CatalogRepository catalogRepository;
  final FavoriteRepository favoriteRepository;
  final PlaybackRepository playbackRepository;
  final MediaLibrary mediaLibrary;

  PlayerController? inlinePlayerController;
  final RxBool isInlinePlayerActive = false.obs;
  final GlobalKey embeddedPlayerKey = GlobalKey();

  final Rx<MediaItem?> movieRx = Rx<MediaItem?>(null);
  final RxBool isLoading = true.obs;
  final RxBool isFavorite = false.obs;
  final Rx<MoviePlayAction> playAction = MoviePlayAction.play.obs;
  final Rx<Duration> resumePosition = Duration.zero.obs;
  final Rx<Duration> totalDuration = Duration.zero.obs;
  final RxDouble completionPercentage = 0.0.obs;
  final RxList<CastMember> cast = <CastMember>[].obs;
  final RxList<MediaItem> relatedMovies = <MediaItem>[].obs;
  final RxString errorMessage = ''.obs;

  MovieDetailsController({
    required this.catalogRepository,
    required this.favoriteRepository,
    required this.playbackRepository,
    required this.mediaLibrary,
  });

  MediaItem? get movie => movieRx.value;
  String get actionButtonLabel => switch (playAction.value) {
        MoviePlayAction.resume => 'Resume',
        MoviePlayAction.watchAgain => 'Watch Again',
        MoviePlayAction.play => 'Play',
      };
  Duration? get watchProgress =>
      resumePosition.value > Duration.zero ? resumePosition.value : null;

  @override
  void onInit() {
    super.onInit();
    _loadMovie();
  }

  @override
  void onClose() {
    stopInlinePlayback();
    inlinePlayerController?.onClose();
    super.onClose();
  }

  Future<void> _loadMovie() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      MediaItem? item;
      final args = Get.arguments;
      if (args is MediaItem) {
        item = args;
      } else if (args is Map && args['item'] is MediaItem) {
        item = args['item'] as MediaItem;
      } else if (args is Map && args['id'] != null) {
        final id = args['id'].toString();
        item = await _findMovieById(id);
      } else if (Get.parameters['id'] != null) {
        item = await _findMovieById(Get.parameters['id']!);
      }

      if (item == null) {
        errorMessage.value = 'Movie information could not be found.';
        return;
      }

      movieRx.value = item;
      isFavorite.value = item.favorite;
      cast.assignAll(item.castMembers);

      await _checkFavoriteState(item);
      await _checkWatchProgress(item);
      await _loadRelatedMovies(item);
      _enrichFromVodService(item);
    } catch (e) {
      errorMessage.value = 'Failed to load movie details: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void _enrichFromVodService(MediaItem item) {
    if (item.mediaType == MediaType.movie && Get.isRegistered<XtreamVodInfoService>()) {
      final vodService = Get.find<XtreamVodInfoService>();
      vodService.fetchForMediaItem(item).then((info) {
        if (info == null) return;
        final current = movieRx.value;
        if (current == null || current.id != item.id) return;

        final updated = current.copyWith(
          poster: (current.poster == null || current.poster!.isEmpty) ? info.poster : current.poster,
          backdrop: (current.backdrop == null || current.backdrop!.isEmpty) ? info.backdrop : current.backdrop,
          description: (current.description == null || current.description!.isEmpty) ? info.plot : current.description,
          rating: current.rating ?? info.rating,
          metadata: {
            ...current.metadata,
            if (info.director != null && info.director!.isNotEmpty) 'director': info.director,
            if (info.cast != null && info.cast!.isNotEmpty) 'cast': info.cast,
            if (info.releaseDate != null && info.releaseDate!.isNotEmpty) 'release_date': info.releaseDate,
            if (info.durationSeconds != null && info.durationSeconds! > 0) 'duration_seconds': info.durationSeconds,
            if (info.genre != null && info.genre!.isNotEmpty) 'genre': info.genre,
          },
        );
        movieRx.value = updated;
        if (updated.castMembers.isNotEmpty) {
          cast.assignAll(updated.castMembers);
        }
      }).catchError((_) {});
    }
  }

  Future<MediaItem?> _findMovieById(String id) async {
    final all = await catalogRepository.getAllItems();
    try {
      return all.firstWhere((i) => i.id == id);
    } catch (_) {
      final libraryMovies = mediaLibrary.getMovies();
      try {
        return libraryMovies.firstWhere((i) => i.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _checkFavoriteState(MediaItem item) async {
    final fav = await favoriteRepository.isFavorite(item.id);
    isFavorite.value = fav || item.favorite;
  }

  Future<void> _checkWatchProgress(MediaItem item) async {
    PlaybackSessionModel? session = await playbackRepository.getWatchSession(item.id);
    if (session == null && item.metadata['position'] != null) {
      final posNum = item.metadata['position'] is num ? item.metadata['position'] as num : 0;
      final durNum = item.metadata['duration'] is num ? item.metadata['duration'] as num : 0;
      if (posNum > 10000) {
        session = PlaybackSessionModel(
          id: item.id,
          itemId: item.id,
          providerType: item.providerType.name,
          resumePosition: Duration(milliseconds: posNum.toInt()),
          completionPercentage: durNum > 0 ? (posNum / durNum).clamp(0.0, 1.0) : 0.0,
          updatedAt: DateTime.now(),
        );
      }
    }
    if (session != null) {
      resumePosition.value = session.resumePosition;
      completionPercentage.value = session.completionPercentage;
      if (session.completionPercentage >= 0.90) {
        playAction.value = MoviePlayAction.watchAgain;
      } else if (session.resumePosition > const Duration(seconds: 10)) {
        playAction.value = MoviePlayAction.resume;
      } else {
        playAction.value = MoviePlayAction.play;
      }
    } else {
      resumePosition.value = Duration.zero;
      completionPercentage.value = 0.0;
      playAction.value = MoviePlayAction.play;
    }
  }

  Future<void> _loadRelatedMovies(MediaItem current) async {
    try {
      final all = await catalogRepository.getByType(MediaType.movie);
      final pool = all.isNotEmpty ? all : mediaLibrary.getMovies();

      final currentGenres = current.genres.map((g) => g.toLowerCase().trim()).toSet();
      final currentCategory = current.metadata['category_name']?.toString().toLowerCase();
      final currentDirector = current.director?.toLowerCase();

      final scored = <MediaItem, int>{};
      for (final candidate in pool) {
        if (candidate.id == current.id) continue;
        int score = 0;

        // Genre match score
        for (final g in candidate.genres) {
          if (currentGenres.contains(g.toLowerCase().trim())) {
            score += 3;
          }
        }

        // Category match score
        final candCategory = candidate.metadata['category_name']?.toString().toLowerCase();
        if (currentCategory != null && candCategory == currentCategory) {
          score += 2;
        }

        // Director match score
        final candDirector = candidate.director?.toLowerCase();
        if (currentDirector != null && candDirector == currentDirector) {
          score += 4;
        }

        // Provider match score fallback
        if (candidate.providerId == current.providerId) {
          score += 1;
        }

        if (score > 0) {
          scored[candidate] = score;
        }
      }

      final sorted = scored.keys.toList()
        ..sort((a, b) => (scored[b] ?? 0).compareTo(scored[a] ?? 0));

      relatedMovies.assignAll(sorted.take(15));
    } catch (_) {
      relatedMovies.clear();
    }
  }

  Future<void> toggleFavorite() async {
    final item = movie;
    if (item == null) return;

    if (isFavorite.value) {
      await favoriteRepository.remove(item.id);
      isFavorite.value = false;
    } else {
      await favoriteRepository.add(item.copyWith(favorite: true));
      isFavorite.value = true;
    }
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

    inlinePlayerController = PlayerController(
      engineKind: chosenEngine,
      streamRepository: Get.isRegistered<StreamRepository>()
          ? Get.find<StreamRepository>()
          : null,
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

  Future<void> startInlinePlayback() async {
    final item = movie;
    if (item == null) return;

    _initInlinePlayer();
    _activateInlinePlayer();

    Duration? startPosition;
    if (playAction.value == MoviePlayAction.resume) {
      startPosition = resumePosition.value;
    }

    final itemsToPass = [item, ...relatedMovies];
    inlinePlayerController?.setChannelList(itemsToPass, currentId: item.id);
    inlinePlayerController?.setVolume(1.0);
    await inlinePlayerController?.playMediaItem(
      item,
      resumePosition: startPosition,
    );
  }

  final RxBool isFullscreenMode = false.obs;
  DateTime lastFullscreenEntered = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> stopInlinePlayback() async {
    final item = movie;
    if (item != null && inlinePlayerController != null) {
      final currentPos = inlinePlayerController!.playbackController.engine.positionRx.value;
      final totalDur = inlinePlayerController!.playbackController.engine.durationRx.value;
      if (currentPos > Duration.zero && totalDur > Duration.zero) {
        await playbackRepository.saveWatchProgress(item, currentPos, totalDur);
        await _checkWatchProgress(item);
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
    if (!isInlinePlayerActive.value) {
      startInlinePlayback();
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

  void openFullscreen() {
    expandToFullscreen();
  }

  void play() {
    startInlinePlayback();
  }

  void selectMovie(MediaItem item) {
    movieRx.value = item;
    isFavorite.value = item.favorite;
    cast.assignAll(item.castMembers);
    _checkFavoriteState(item);
    _checkWatchProgress(item);
    _loadRelatedMovies(item);
    _enrichFromVodService(item);

    if (isInlinePlayerActive.value) {
      startInlinePlayback();
    }
  }

  void openRelatedMovie(MediaItem related) {
    selectMovie(related);
  }

  Future<void> reload() => _loadMovie();
}
