import 'dart:async';
import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/iptv_core.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/media/player/native_activity_player_adapter.dart';
import 'package:stream_hub/core/media/player/player_settings.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/playback_controller.dart';
import 'package:stream_hub/core/media/repositories/playback_repository.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/streaming/series/next_episode_resolver.dart';
import 'package:stream_hub/core/streaming/series/intro_service.dart';
import 'package:stream_hub/data/models/intro_segment.dart';
import 'package:stream_hub/data/models/channel.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playable_stream.dart';
import 'package:stream_hub/data/repositories/history_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';

class PlayerController extends GetxController {
  final PlaybackController playbackController;
  final StreamRepository streamRepository;
  final HistoryRepository? historyRepository;
  final FavoriteRepository? favoriteRepository;
  final PlaybackRepository? playbackRepository;
  final CatalogRepository? catalogRepository;
  final IptvCore? iptvCore;
  final NextEpisodeResolver nextEpisodeResolver;
  final IntroService introService;

  final String? itemId;
  final String? streamUrl;
  final Duration? resumePosition;

  /// Items passed from the binding that will be loaded inside [onInit], after
  /// settings are applied and the event listener is registered.
  final List<MediaItem> _pendingItems;
  final String? _pendingCurrentId;

  final RxList<MediaItem> channelList = <MediaItem>[].obs;
  final RxBool isFavoriteRx = false.obs;
  final RxString selectedSubtitleTrackRx = 'no'.obs;
  final RxString selectedAudioTrackRx = 'auto'.obs;
  int _currentChannelIndex = -1;
  MediaItem? _pendingItem;
  late final Worker _sessionWorker;
  Timer? _progressSaveTimer;

  // Series & Episode Autoplay / Skip Intro support
  final RxBool isEpisodeRx = false.obs;
  final Rx<MediaItem?> nextEpisodeRx = Rx<MediaItem?>(null);
  final Rx<MediaItem?> previousEpisodeRx = Rx<MediaItem?>(null);
  final RxBool showNextEpisodeOverlayRx = false.obs;
  final RxBool showSkipIntroRx = false.obs;
  final Rx<IntroSegment?> activeIntroSegmentRx = Rx<IntroSegment?>(null);
  bool _hasTriggeredNextEpisodeOverlay = false;
  bool _userCancelledNextEpisode = false;
  Worker? _positionWorker;

  PlayerController({
    this.itemId,
    this.streamUrl,
    this.resumePosition,
    List<MediaItem>? pendingItems,
    String? pendingCurrentId,
    PlayerAdapter? adapter,
    PlaybackEngineKind? engineKind,
    PlayerSettings? settings,
    LoggingService? logger,
    StreamRepository? streamRepository,
    this.historyRepository,
    this.favoriteRepository,
    this.playbackRepository,
    this.catalogRepository,
    IptvCore? iptvCore,
    NextEpisodeResolver? nextEpisodeResolver,
    IntroService? introService,
  })  : _pendingItems = pendingItems ?? const [],
        _pendingCurrentId = pendingCurrentId,
        nextEpisodeResolver = nextEpisodeResolver ?? const NextEpisodeResolver(),
        introService = introService ?? IntroService(),
        playbackController = PlaybackController(
          adapter: adapter,
          engineKind: engineKind,
          settings: settings,
          logger: logger,
        ),
        streamRepository = streamRepository ?? Get.find<StreamRepository>(),
        iptvCore = iptvCore ??
            (Get.isRegistered<IptvCore>() ? Get.find<IptvCore>() : null);

  PlayableMediaSession? get session => playbackController.engine.currentSession;
  Rx<PlayableMediaSession?> get sessionRx => playbackController.engine.sessionRx;
  Rx<PlaybackState> get stateRx => playbackController.engine.stateRx;
  PlaybackState get state => playbackController.engine.currentState;
  Duration get position => playbackController.engine.positionRx.value;
  Duration get duration => playbackController.engine.durationRx.value;
  Duration get buffer => playbackController.engine.bufferRx.value;
  MediaItem? get currentItem => session?.mediaItem;
  bool get canSwitchNext => _currentChannelIndex < channelList.length - 1 || nextEpisodeRx.value != null;
  bool get canSwitchPrevious => _currentChannelIndex > 0 || previousEpisodeRx.value != null;

  Worker? _engineWorker;
  Worker? _stateWorker;

  @override
  Future<void> onInit() async {
    super.onInit();
    _sessionWorker = ever(sessionRx, (session) {
      isFavoriteRx.value = session?.mediaItem.favorite ?? false;
      if (stateRx.value == PlaybackState.playing) {
        _startProgressTimer();
      }
      if (session != null) {
        _autoSelectSubtitle();
        _onMediaSessionChanged(session.mediaItem);
      }
    });
    _engineWorker = ever(playbackController.engine.engineKindRx, (_) {
      _wireAdapterChannelListeners();
      _syncChannelsToNativeAdapter();
    });
    _stateWorker = ever(stateRx, (state) {
      if (state == PlaybackState.playing) {
        _startProgressTimer();
      } else {
        _stopProgressTimer();
      }
    });
    _positionWorker = ever(playbackController.engine.positionRx, (pos) {
      _checkIntroAndAutoplay(pos);
    });
    await _loadPersistedSettings();
    _wireAdapterChannelListeners();
    // Register the event listener BEFORE starting playback so that early
    // loading/buffering/error events emitted during session creation reach the
    // UI instead of being silently dropped.
    playbackController.addEventListener(_onPlaybackEvent);

    if (itemId != null && streamUrl != null) {
      await _autoStart(itemId!, streamUrl!);
    } else if (_pendingItems.isNotEmpty) {
      // Items provided by the binding are started here, after the engine is
      // configured and the event listener is in place.
      setChannelList(
        _pendingItems,
        currentId: _pendingCurrentId,
        resumePosition: resumePosition,
      );
    }
    _loadBackgroundChannels();
  }


  void _startProgressTimer() {
    if (playbackRepository == null) return;
    final item = currentItem;
    if (item == null || item.mediaType == MediaType.channel) return;
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _persistCurrentProgress();
    });
  }

  void _stopProgressTimer() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = null;
  }

  Future<void> _loadBackgroundChannels() async {
    try {
      List<MediaItem> allChannels = [];
      if (catalogRepository != null) {
        allChannels = await catalogRepository!.getByType(MediaType.channel);
        if (allChannels.isEmpty) {
          final all = await catalogRepository!.getAllItems();
          allChannels =
              all.where((i) => i.mediaType == MediaType.channel).toList();
        }
      }
      if (allChannels.isEmpty && Get.isRegistered<MediaLibrary>()) {
        allChannels = Get.find<MediaLibrary>().getLiveTV();
      }
      if (allChannels.isNotEmpty) {
        final currentId = _pendingCurrentId ?? itemId ?? currentItem?.id;
        final foundIdx = currentId != null
            ? allChannels.indexWhere((c) => c.id == currentId)
            : -1;
        channelList.assignAll(allChannels);
        if (foundIdx >= 0) {
          _currentChannelIndex = foundIdx;
        }
        _syncChannelsToNativeAdapter();
      }
    } catch (e) {
      playbackController.engine.logger.warning(
        'Failed to load background channels: $e',
        tag: 'PlayerController',
      );
    }
  }

  /// Applies the persisted player settings (preferred engine, hardware
  /// decode, ...) to the engine before the first session is started so the
  /// backend selection honors the user's preference.
  Future<void> _loadPersistedSettings() async {
    final repository = playbackRepository;
    if (repository == null) return;
    try {
      final loaded = await repository.getSettings();
      playbackController.engine.applySettings(loaded);
    } catch (e) {
      playbackController.engine.logger.warning(
        'Failed to load persisted player settings',
        tag: 'PlayerController',
        error: e,
      );
    }
  }

  @override
  void onClose() {
    _progressSaveTimer?.cancel();
    _persistCurrentProgress();
    _sessionWorker.dispose();
    _engineWorker?.dispose();
    _stateWorker?.dispose();
    _positionWorker?.dispose();
    playbackController.removeEventListener(_onPlaybackEvent);
    // Tear down the engine and the active backend (player, platform view, or
    // native Activity). stop() alone leaves the adapter initialized and its
    // render surface/native process alive, leaking resources between plays.
    playbackController.dispose();
    super.onClose();
  }

  void _onMediaSessionChanged(MediaItem item) {
    _hasTriggeredNextEpisodeOverlay = false;
    _userCancelledNextEpisode = false;
    showNextEpisodeOverlayRx.value = false;
    showSkipIntroRx.value = false;

    final isEp = item.mediaType == MediaType.episode ||
        (item.metadata['seriesId'] != null ||
            item.metadata['isEpisode'] == true ||
            item.metadata['seasonNumber'] != null);
    isEpisodeRx.value = isEp;

    activeIntroSegmentRx.value = introService.getIntroSegment(item);

    if (isEp) {
      _resolveAdjacentEpisodes(item);
    } else {
      nextEpisodeRx.value = null;
      previousEpisodeRx.value = null;
    }
  }

  void _resolveAdjacentEpisodes(MediaItem currentEp) {
    if (channelList.isNotEmpty && channelList.length > 1) {
      // Group channelList by season
      final seasonsMap = <int, List<MediaItem>>{};
      for (final itm in channelList) {
        final sNum = NextEpisodeResolver.seasonNumberFor(itm);
        seasonsMap.putIfAbsent(sNum, () => []).add(itm);
      }
      final seasonGroups = seasonsMap.entries.map((e) {
        return SeasonGroup(
          number: e.key,
          name: 'Season ${e.key}',
          episodes: e.value,
        );
      }).toList();

      final nextRes = nextEpisodeResolver.resolveNext(
        currentEpisode: currentEp,
        seasons: seasonGroups,
      );
      nextEpisodeRx.value = nextRes.nextEpisode;
      previousEpisodeRx.value = nextEpisodeResolver.resolvePrevious(
        currentEpisode: currentEp,
        seasons: seasonGroups,
      );
    }
  }

  void _checkIntroAndAutoplay(Duration pos) {
    // Intro segment check
    final intro = activeIntroSegmentRx.value;
    if (intro != null && intro.containsPosition(pos)) {
      if (playbackController.settings.autoSkipIntro) {
        skipIntro();
      } else {
        showSkipIntroRx.value = true;
      }
    } else {
      showSkipIntroRx.value = false;
    }

    // Next episode countdown check
    if (isEpisodeRx.value &&
        playbackController.settings.autoplayNextEpisode &&
        !_userCancelledNextEpisode &&
        !_hasTriggeredNextEpisodeOverlay &&
        nextEpisodeRx.value != null &&
        duration > Duration.zero) {
      final progress = pos.inMilliseconds / duration.inMilliseconds;
      if (progress >= 0.92 || (duration - pos) <= const Duration(seconds: 15)) {
        _hasTriggeredNextEpisodeOverlay = true;
        showNextEpisodeOverlayRx.value = true;
      }
    }
  }

  Future<void> skipIntro() async {
    final intro = activeIntroSegmentRx.value;
    if (intro != null) {
      await seek(intro.end);
      showSkipIntroRx.value = false;
    }
  }

  Future<void> playNextEpisode() async {
    showNextEpisodeOverlayRx.value = false;
    final nextEp = nextEpisodeRx.value;
    if (nextEp != null) {
      await playMediaItem(nextEp);
    }
  }

  Future<void> playPreviousEpisode() async {
    final prevEp = previousEpisodeRx.value;
    if (prevEp != null) {
      await playMediaItem(prevEp);
    }
  }

  void cancelNextEpisodeCountdown() {
    showNextEpisodeOverlayRx.value = false;
    _userCancelledNextEpisode = true;
  }


  Future<void> _autoStart(String id, String url) async {
    final mediaItem = MediaItem(
      id: id,
      providerId: 'unknown',
      providerType: MediaSourceType.m3u,
      mediaType: MediaType.channel,
      title: 'Live Stream',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    channelList.assignAll([mediaItem]);
    _currentChannelIndex = 0;
    _syncChannelsToNativeAdapter();
    final session = await streamRepository.resolveStream(
      mediaItemId: id,
      url: url,
      providerSession: ProviderSession(
        providerId: 'unknown',
        providerType: MediaSourceType.m3u,
        sessionId: 'direct_$id',
      ),
    );
    await playWithSession(mediaItem, session);
  }

  Future<void> playMedia(
    MediaItem mediaItem,
    PlayableStream stream, {
    String? providerId,
    Duration? resumePosition,
  }) async {
    await playbackController.playMedia(
      mediaItem,
      stream,
      providerId: providerId,
      resumePosition: resumePosition,
    );
    _recordPlayback(mediaItem);
  }

  /// Plays an authenticated session produced by the Stream Engine.
  Future<void> playWithSession(
    MediaItem mediaItem,
    PlayableSession session, {
    Duration? resumePosition,
  }) async {
    await playbackController.playSession(
      session,
      mediaItem: mediaItem,
      resumePosition: resumePosition,
    );
    _recordPlayback(mediaItem);
  }

  Future<void> playMediaItem(MediaItem item, {Duration? resumePosition}) async {
    final startedAt = DateTime.now();
    PlayableSession? session;
    _pendingItem = item;
    try {
      if (!playbackController.engine.adapter.isInitialized) {
        await playbackController.engine.initialize();
      }

      // Check if there is a resume position to use
      Duration? resume = resumePosition ?? this.resumePosition;
      if (resume == null &&
          item.mediaType != MediaType.channel &&
          playbackRepository != null) {
        final saved = await playbackRepository!.getWatchProgress(item.id);
        if (saved != null && saved > Duration.zero) {
          resume = saved;
        }
      }

      // Derive the actual stream URL from the item's metadata so the Stream
      // Engine can locate the source. Passing item.id (a UUID) as the fallback
      // caused a StreamResolutionException for every channel whose metadata
      // does not include a pre-resolved 'streamUrl' key (Xtream, canonical, etc.).
      final fallbackUrl = item.metadata['streamUrl']?.toString()
          ?? item.metadata['stream_url']?.toString()
          ?? item.metadata['url']?.toString();

      final resolved = await streamRepository.resolvePlayback(
        mediaItemId: item.id,
        providerType: item.providerType,
        itemMetadata: item.metadata,
        providerId: item.providerId,
        fallbackUrl: fallbackUrl,
      );
      session = resolved;
      await playWithSession(item, resolved, resumePosition: resume);
    } catch (e, st) {
      await _handlePlaybackFailure(item, session, e, st, startedAt);
    }
  }

  /// Attempts IPTV Core error recovery and records diagnostics, then surfaces
  /// the failure through the engine so the player never hangs silently.
  Future<void> _handlePlaybackFailure(
    MediaItem item,
    PlayableSession? session,
    Object error,
    StackTrace stackTrace,
    DateTime startedAt,
  ) async {
    final core = iptvCore;
    if (core != null && session != null) {
      try {
        final recovery = await core.errorRecovery.recover(
          session,
          error,
          itemMetadata: item.metadata,
        );
        if (recovery.recovered && recovery.finalSession != null) {
          try {
            await playWithSession(item, recovery.finalSession!);
            return;
          } catch (replayError) {
            core.diagnosticsBuilder.build(
              inputUrl: item.id,
              session: recovery.finalSession,
              extraErrors: [recovery.message, 'Replay failed: $replayError'],
              startedAt: startedAt,
              completedAt: DateTime.now(),
            );
          }
        } else {
          core.diagnosticsBuilder.build(
            inputUrl: item.id,
            session: session,
            extraErrors: [error.toString(), recovery.message],
            startedAt: startedAt,
            completedAt: DateTime.now(),
          );
        }
      } catch (recoveryError, recoveryStack) {
        playbackController.engine.logger.error(
          'Error recovery failed: $recoveryError',
          tag: 'PlayerController',
          error: recoveryError,
          stackTrace: recoveryStack,
        );
      }
    }

    final message = 'Failed to resolve and play media item ${item.id}: $error';
    playbackController.engine.logger.error(
      message,
      tag: 'PlayerController',
      error: error,
      stackTrace: stackTrace,
    );
    playbackController.engine.failPlayback(message, stackTrace: stackTrace);
  }

  void _wireAdapterChannelListeners() {
    final adapter = playbackController.engine.adapter;
    if (adapter is NativeActivityPlayerAdapter) {
      adapter.onNextChannelRequested = () => switchToNextChannel();
      adapter.onPreviousChannelRequested = () => switchToPreviousChannel();
      adapter.onFetchChannelsRequested = () async {
        await _loadBackgroundChannels();
        _syncChannelsToNativeAdapter();
      };
      adapter.onSwitchChannelRequested = (index, channelId) async {
        if (index >= 0 && index < channelList.length) {
          _currentChannelIndex = index;
          final item = channelList[index];
          _recordPlayback(item);
          isFavoriteRx.value = item.favorite;
          final streamUrl = (item is Channel ? item.streamUrl : null) ??
              item.metadata['streamUrl']?.toString() ??
              item.metadata['stream_url']?.toString() ??
              item.metadata['url']?.toString();
          if (streamUrl == null || streamUrl.isEmpty) {
            await playMediaItem(item);
          }
        } else if (channelId != null) {
          final foundIndex = channelList.indexWhere((c) => c.id == channelId);
          if (foundIndex != -1) {
            _currentChannelIndex = foundIndex;
            final item = channelList[foundIndex];
            _recordPlayback(item);
            isFavoriteRx.value = item.favorite;
            final streamUrl = (item is Channel ? item.streamUrl : null) ??
                item.metadata['streamUrl']?.toString() ??
                item.metadata['stream_url']?.toString() ??
                item.metadata['url']?.toString();
            if (streamUrl == null || streamUrl.isEmpty) {
              await playMediaItem(item);
            }
          }
        }
      };
    }
  }

  void _syncChannelsToNativeAdapter() {
    final adapter = playbackController.engine.adapter;
    if (adapter is NativeActivityPlayerAdapter && channelList.isNotEmpty) {
      final nativeChannels = channelList.map((item) {
        final streamUrl = (item is Channel ? item.streamUrl : null) ??
            item.metadata['streamUrl']?.toString() ??
            item.metadata['stream_url']?.toString() ??
            item.metadata['url']?.toString() ??
            '';
        final headers = (item.metadata['headers'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ) ??
            const <String, String>{};
        final category = (item.genres.isNotEmpty ? item.genres.first : null) ??
            item.metadata['category_name']?.toString() ??
            item.metadata['group-title']?.toString() ??
            item.metadata['category']?.toString() ??
            item.metadata['group']?.toString() ??
            'General';
        return <String, dynamic>{
          'id': item.id,
          'name': item.title,
          'url': streamUrl,
          'logoUrl': item.poster ?? item.thumbnail,
          'epgTitle': item.subtitle ?? item.metadata['epg_title']?.toString(),
          'category': category,
          'headers': headers,
        };
      }).toList();
      adapter.updateChannelList(
        nativeChannels,
        currentIndex: _currentChannelIndex,
      );
    }
  }

  void setChannelList(
    List<MediaItem> channels, {
    String? currentId,
    Duration? resumePosition,
  }) {
    channelList.assignAll(channels);
    _currentChannelIndex =
        currentId != null ? channels.indexWhere((c) => c.id == currentId) : -1;
    _syncChannelsToNativeAdapter();
    if (_currentChannelIndex != -1) {
      playMediaItem(
        channels[_currentChannelIndex],
        resumePosition: resumePosition ?? this.resumePosition,
      );
    }
  }

  Future<void> switchToChannel(int index) async {
    if (index < 0 || index >= channelList.length) return;
    _currentChannelIndex = index;
    _syncChannelsToNativeAdapter();
    final item = channelList[index];
    await playMediaItem(item);
  }

  Future<void> switchToNextChannel() async {
    if (channelList.isEmpty) return;
    final nextIndex = (_currentChannelIndex + 1) % channelList.length;
    await switchToChannel(nextIndex);
  }

  Future<void> switchToPreviousChannel() async {
    if (channelList.isEmpty) return;
    final prevIndex = _currentChannelIndex <= 0
        ? channelList.length - 1
        : _currentChannelIndex - 1;
    await switchToChannel(prevIndex);
  }

  Future<void> play() => playbackController.play();

  Future<void> pause() async {
    await playbackController.pause();
    await _persistCurrentProgress();
  }

  Future<void> resume() => playbackController.resume();

  Future<void> stop() async {
    await _persistCurrentProgress();
    await playbackController.stop();
  }

  Future<void> seek(Duration position) async {
    await playbackController.seek(position);
    await _persistCurrentProgress();
  }

  Future<void> replay() => playbackController.replay();

  Future<void> next() async {
    if (isEpisodeRx.value && nextEpisodeRx.value != null) {
      await playNextEpisode();
    } else {
      await switchToNextChannel();
    }
  }

  Future<void> previous() async {
    if (isEpisodeRx.value && previousEpisodeRx.value != null) {
      await playPreviousEpisode();
    } else {
      await switchToPreviousChannel();
    }
  }

  Future<void> retry() async {
    final pending = _pendingItem;
    if (pending != null) {
      await playMediaItem(pending);
    } else {
      await playbackController.retry();
    }
  }

  /// Stops playback and leaves the player route.
  ///
  /// With the Native Activity engine the Activity itself renders the video and
  /// owns its close affordances: stopping it finishes the Activity, and the
  /// fullscreen page already pops itself on the resulting `stopped` event.
  /// Popping again here would close an extra route, so it is skipped for that
  /// adapter. Every Flutter-rendered backend (MediaKit/VLC) stops here and the
  /// route is popped explicitly.
  Future<void> stopAndClose() async {
    final usesNativeActivity =
        playbackController.engine.adapter is NativeActivityPlayerAdapter;
    await stop();
    if (!usesNativeActivity) {
      Get.back();
    }
  }

  Future<void> setSpeed(PlaybackSpeed speed) =>
      playbackController.setSpeed(speed);
  Future<void> setAspectRatio(AspectRatioMode mode) =>
      playbackController.setAspectRatio(mode);
  Future<void> setQuality(PlayerQuality quality) =>
      playbackController.setQuality(quality);
  Future<List<dynamic>> getAvailableSubtitleTracks() async {
    try {
      final tracks = await playbackController.engine.adapter.getAvailableSubtitleTracks();
      final active = tracks.firstWhere(
        (t) => t is Map && t['selected'] == true,
        orElse: () => null,
      );
      if (active != null && active is Map) {
        selectedSubtitleTrackRx.value = active['id']?.toString() ?? selectedSubtitleTrackRx.value;
      }
      return tracks;
    } catch (_) {
      return const [];
    }
  }

  Future<List<dynamic>> getAvailableAudioTracks() async {
    try {
      final tracks = await playbackController.engine.adapter.getAvailableAudioTracks();
      final active = tracks.firstWhere(
        (t) => t is Map && t['selected'] == true,
        orElse: () => null,
      );
      if (active != null && active is Map) {
        selectedAudioTrackRx.value = active['id']?.toString() ?? selectedAudioTrackRx.value;
      }
      return tracks;
    } catch (_) {
      return const [];
    }
  }

  Future<void> setSubtitleTrack(String trackId) async {
    selectedSubtitleTrackRx.value = trackId;
    await playbackController.setSubtitleTrack(trackId);
  }

  Future<void> _autoSelectSubtitle() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final tracks = await getAvailableSubtitleTracks();
      if (tracks.isNotEmpty) {
        // Look for English subtitle track first
        final englishTrack = tracks.firstWhere(
          (t) {
            if (t is Map) {
              final lang = (t['language'] ?? '').toString().toLowerCase();
              final label = (t['label'] ?? '').toString().toLowerCase();
              return lang == 'en' ||
                  lang == 'eng' ||
                  lang.startsWith('en') ||
                  label.contains('english') ||
                  label.contains('eng');
            }
            return false;
          },
          orElse: () => tracks.first,
        );
        final trackId = (englishTrack is Map ? englishTrack['id'] : englishTrack)?.toString();
        if (trackId != null &&
            trackId.isNotEmpty &&
            trackId != 'no' &&
            trackId != 'none' &&
            trackId != '-1') {
          await setSubtitleTrack(trackId);
        }
      }
    } catch (_) {}
  }

  Future<void> setAudioTrack(String trackId) async {
    selectedAudioTrackRx.value = trackId;
    await playbackController.setAudioTrack(trackId);
  }

  Future<void> setVolume(double volume) =>
      playbackController.setVolume(volume);
  Future<void> setMuted(bool muted) => playbackController.setMuted(muted);

  Future<void> toggleFavorite() async {
    final item = currentItem;
    if (item == null || favoriteRepository == null) return;
    if (item.favorite) {
      await favoriteRepository!.remove(item.id);
    } else {
      await favoriteRepository!.add(item.copyWith(favorite: true));
    }
    isFavoriteRx.value = !item.favorite;
  }

  void _recordPlayback(MediaItem item) {
    historyRepository?.add(item);
  }

  Future<void> _persistCurrentProgress() async {
    final item = currentItem ?? _pendingItem;
    final currentPos = position;
    final totalDur = duration;
    if (item != null &&
        playbackRepository != null &&
        totalDur > Duration.zero &&
        item.mediaType != MediaType.channel) {
      try {
        await playbackRepository!.saveWatchProgress(item, currentPos, totalDur);
      } catch (e) {
        // Non-critical logging
      }
    }
  }

  void _onPlaybackEvent(dynamic event) {
    update(['player']);
  }
}
