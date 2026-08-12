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
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playable_stream.dart';
import 'package:stream_hub/data/repositories/history_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';

class PlayerController extends GetxController {
  final PlaybackController playbackController;
  final StreamRepository streamRepository;
  final HistoryRepository? historyRepository;
  final FavoriteRepository? favoriteRepository;
  final PlaybackRepository? playbackRepository;
  final IptvCore? iptvCore;

  final String? itemId;
  final String? streamUrl;

  /// Items passed from the binding that will be loaded inside [onInit], after
  /// settings are applied and the event listener is registered.
  final List<MediaItem> _pendingItems;
  final String? _pendingCurrentId;

  final RxList<MediaItem> channelList = <MediaItem>[].obs;
  final RxBool isFavoriteRx = false.obs;
  int _currentChannelIndex = -1;
  MediaItem? _pendingItem;
  late final Worker _sessionWorker;

  PlayerController({
    this.itemId,
    this.streamUrl,
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
    IptvCore? iptvCore,
  })  : _pendingItems = pendingItems ?? const [],
        _pendingCurrentId = pendingCurrentId,
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
  bool get canSwitchNext => _currentChannelIndex < channelList.length - 1;
  bool get canSwitchPrevious => _currentChannelIndex > 0;

  @override
  Future<void> onInit() async {
    super.onInit();
    _sessionWorker = ever(sessionRx, (session) {
      isFavoriteRx.value = session?.mediaItem.favorite ?? false;
    });
    await _loadPersistedSettings();
    // Register the event listener BEFORE starting playback so that early
    // loading/buffering/error events emitted during session creation reach the
    // UI instead of being silently dropped.
    playbackController.addEventListener(_onPlaybackEvent);
    if (itemId != null && streamUrl != null) {
      await _autoStart(itemId!, streamUrl!);
    } else if (_pendingItems.isNotEmpty) {
      // Items provided by the binding are started here, after the engine is
      // configured and the event listener is in place.
      setChannelList(_pendingItems, currentId: _pendingCurrentId);
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
    _sessionWorker.dispose();
    playbackController.removeEventListener(_onPlaybackEvent);
    // Tear down the engine and the active backend (player, platform view, or
    // native Activity). stop() alone leaves the adapter initialized and its
    // render surface/native process alive, leaking resources between plays.
    playbackController.dispose();
    super.onClose();
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

  Future<void> playMediaItem(MediaItem item) async {
    final startedAt = DateTime.now();
    PlayableSession? session;
    _pendingItem = item;
    try {
      if (!playbackController.engine.adapter.isInitialized) {
        await playbackController.engine.initialize();
      }

      // Derive the actual stream URL from the item's metadata so the Stream
      // Engine can locate the source. Passing item.id (a UUID) as the fallback
      // caused a StreamResolutionException for every channel whose metadata
      // does not include a pre-resolved 'streamUrl' key (Xtream, canonical, etc.).
      final fallbackUrl = item.metadata['streamUrl']?.toString()
          ?? item.metadata['stream_url']?.toString()
          ?? item.metadata['url']?.toString();

      session = await streamRepository.resolvePlayback(
        mediaItemId: item.id,
        providerType: item.providerType,
        itemMetadata: item.metadata,
        providerId: item.providerId,
        fallbackUrl: fallbackUrl,
      );
      await playWithSession(item, session);
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

  void setChannelList(List<MediaItem> channels, {String? currentId}) {
    channelList.assignAll(channels);
    _currentChannelIndex =
        currentId != null ? channels.indexWhere((c) => c.id == currentId) : -1;
    if (_currentChannelIndex != -1) {
      playMediaItem(channels[_currentChannelIndex]);
    }
  }

  Future<void> switchToChannel(int index) async {
    if (index < 0 || index >= channelList.length) return;
    _currentChannelIndex = index;
    final item = channelList[index];
    await playMediaItem(item);
  }

  Future<void> switchToNextChannel() async {
    if (canSwitchNext) {
      await switchToChannel(_currentChannelIndex + 1);
    }
  }

  Future<void> switchToPreviousChannel() async {
    if (canSwitchPrevious) {
      await switchToChannel(_currentChannelIndex - 1);
    }
  }

  Future<void> play() => playbackController.play();
  Future<void> pause() => playbackController.pause();
  Future<void> resume() => playbackController.resume();
  Future<void> stop() => playbackController.stop();
  Future<void> seek(Duration position) => playbackController.seek(position);
  Future<void> replay() => playbackController.replay();
  Future<void> next() => switchToNextChannel();
  Future<void> previous() => switchToPreviousChannel();
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
  Future<void> setSubtitleTrack(String trackId) =>
      playbackController.setSubtitleTrack(trackId);
  Future<void> setAudioTrack(String trackId) =>
      playbackController.setAudioTrack(trackId);
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

  void _onPlaybackEvent(dynamic event) {
    update(['player']);
  }
}
