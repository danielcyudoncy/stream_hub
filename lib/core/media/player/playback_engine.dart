import 'dart:async';
import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/playback_engine_preference.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/events/playback_event.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/media/player/media_kit_player_adapter.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/media/player/player_adapter_factory.dart';
import 'package:stream_hub/core/media/player/player_selection_strategy.dart';
import 'package:stream_hub/core/media/player/player_settings.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/playback_analytics.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';
import 'package:stream_hub/core/utils/hardware_detector.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playable_stream.dart';

class PlaybackEngine {
  PlayerSettings settings;
  final LoggingService logger;

  PlayerAdapter _adapter;
  PlaybackEngineKind _engineKind;
  final PlayerSelectionStrategy _selectionStrategy;

  /// Whether the engine may select and hot-swap the backend per session.
  ///
  /// Enabled only when no adapter/engine was explicitly provided (i.e. the
  /// user preference is `Auto`). Explicit adapters (tests) and explicit engine
  /// kinds (forced MediaKit/VLC) disable switching.
  final bool allowEngineFallback;

  bool _initialized = false;
  final Set<PlaybackEngineKind> _attemptedEngines = <PlaybackEngineKind>{};
  int _silentVideoSeconds = 0;

  PlayableMediaSession? _currentSession;
  PlayableSession? _currentPlayableSession;
  final Rx<PlayableMediaSession?> sessionRx = Rx<PlayableMediaSession?>(null);
  PlaybackState _state = PlaybackState.idle;
  final Rx<PlaybackState> stateRx = PlaybackState.idle.obs;
  final Rx<Duration> positionRx = Duration.zero.obs;
  final Rx<Duration> durationRx = Duration.zero.obs;
  final Rx<Duration> bufferRx = Duration.zero.obs;
  final Rx<double> volumeRx = 1.0.obs;
  final Rx<bool> mutedRx = false.obs;
  final Rx<PlaybackSpeed> speedRx = PlaybackSpeed.speed1_0.obs;
  final Rx<AspectRatioMode> aspectRatioRx = AspectRatioMode.fit.obs;
  final Rx<PlayerQuality> qualityRx = PlayerQuality.auto.obs;
  final Rx<BufferInfo?> bufferInfoRx = Rx<BufferInfo?>(null);
  final Rx<String> errorMessageRx = ''.obs;
  final Rx<PlaybackEngineKind> engineKindRx = Rx<PlaybackEngineKind>(PlaybackEngineKind.mediaKit);

  final List<void Function(PlaybackState)> _stateListeners = [];
  final List<void Function(Duration)> _positionListeners = [];
  final List<void Function(Duration)> _bufferListeners = [];
  final List<void Function(PlaybackEvent)> _eventListeners = [];
  StreamSubscription<PlaybackState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _bufferSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<String>? _subtitleSub;

  PlaybackAnalytics? _analytics;
  Timer? _analyticsTimer;
  Timer? _bufferTimer;
  int _retryCount = 0;
  static const int maxRetries = 3;

  PlaybackEngine({
    PlayerAdapter? adapter,
    PlaybackEngineKind? engineKind,
    PlayerSettings? settings,
    LoggingService? logger,
    PlayerSelectionStrategy? selectionStrategy,
  })  : settings = settings ?? const PlayerSettings(),
        logger = logger ?? LoggingService(),
        _selectionStrategy =
            selectionStrategy ?? const PlayerSelectionStrategy(),
        _adapter = adapter ??
            PlayerAdapterFactory.create(
              engineKind ?? PlaybackEngineKind.mediaKit,
              logger: logger,
              hardwareDecode: (settings ?? const PlayerSettings()).hardwareDecode,
            ),
        _engineKind = adapter != null
            ? adapter.kind
            : (engineKind ?? PlaybackEngineKind.mediaKit),
        allowEngineFallback = adapter == null && engineKind == null {
    engineKindRx.value = _engineKind;
  }

  /// Replaces the engine's settings with the persisted [newSettings].
  ///
  /// `preferredPlayer` is read again on the next session selection, and any
  /// adapter created after this call (engine swaps in Auto mode) honors the
  /// updated `hardwareDecode` flag.
  void applySettings(PlayerSettings newSettings) {
    settings = newSettings;
    logger.info(
      'Applied player settings (preferred engine: ${settings.preferredPlayer.name})',
      tag: 'PlaybackEngine',
    );
  }

  PlayableMediaSession? get currentSession => _currentSession;
  PlaybackState get currentState => _state;
  PlaybackAnalytics? get analytics => _analytics;
  bool get isPlaying => _state == PlaybackState.playing;
  bool get isLive => _currentSession?.metadata.isLive ?? false;

  /// The currently active playback backend.
  PlayerAdapter get adapter => _adapter;

  /// The kind of the currently active playback backend.
  PlaybackEngineKind get engineKind => _engineKind;

  Future<void> initialize() async {
    if (_initialized) return;
    if (allowEngineFallback &&
        settings.preferredPlayer == PlaybackEnginePreference.auto) {
      if (await HardwareDetector.isUnisocOrMali()) {
        _adapter = PlayerAdapterFactory.create(
          PlaybackEngineKind.nativeActivity,
          logger: logger,
          hardwareDecode: settings.hardwareDecode,
        );
        _engineKind = PlaybackEngineKind.nativeActivity;
        engineKindRx.value = PlaybackEngineKind.nativeActivity;
      }
    }
    await _adapter.initialize();
    _bindAdapterStreams();
    _initialized = true;
    logger.info('PlaybackEngine initialized', tag: 'PlaybackEngine');
  }

  Future<PlayableMediaSession> createSession(
    MediaItem mediaItem,
    PlayableStream stream, {
    String? providerId,
    Duration? resumePosition,
  }) async {
    final session = PlayableMediaSession(
      id: 'session_${mediaItem.id}_${DateTime.now().millisecondsSinceEpoch}',
      mediaItem: mediaItem,
      stream: stream,
      providerId: providerId ?? mediaItem.providerId,
      resumePosition: resumePosition ?? Duration.zero,
      capabilities: PlaybackCapabilities(
        canResume: true,
        canPause: true,
        canSeek: stream.drm == null,
        canChangeSpeed: true,
        canChangeAspectRatio: true,
        canPictureInPicture: true,
        supportsAudioOnly: stream.audioTracks != null &&
            stream.audioTracks!.isNotEmpty,
        supportsSubtitles: stream.subtitleTracks != null &&
            stream.subtitleTracks!.isNotEmpty,
        canChangeSubtitle:
            stream.subtitleTracks != null && stream.subtitleTracks!.isNotEmpty,
        canChangeAudioTrack:
            stream.audioTracks != null && stream.audioTracks!.isNotEmpty,
        canChangeQuality: false,
        supportsMultipleQualities: false,
      ),
      metadata: SessionMetadata(
        title: mediaItem.title,
        description: mediaItem.description,
        posterUrl: mediaItem.poster,
        providerType: mediaItem.providerType.name,
        isLive: mediaItem.mediaType == MediaType.channel,
      ),
    );

    _currentSession = session;
    sessionRx.value = session;
    _retryCount = 0;
    _attemptedEngines.clear();
    _analytics = PlaybackAnalytics(
      sessionId: session.id,
      itemId: mediaItem.id,
      providerType: mediaItem.providerType.name,
      startedAt: DateTime.now(),
    );

    await _maybeSelectEngineForUrl(
      stream.url,
      isLive: mediaItem.mediaType == MediaType.channel,
    );
    await loadSession(session);
    return session;
  }

  Future<void> loadSession(PlayableMediaSession session) async {
    await _runLoad(
      () => _adapter.load(session),
      title: session.mediaItem.title,
      loadId: 'session',
    );
    if (session.resumePosition > Duration.zero) {
      await seek(session.resumePosition);
    }
  }

  /// Plays an authenticated session produced by the Stream Engine.
  ///
  /// The engine consumes a [PlayableSession] and adapts it into the internal
  /// [PlayableMediaSession]; the player adapter only ever sees the session.
  Future<PlayableMediaSession> playFromStreamEngine(
    PlayableSession session, {
    MediaItem? mediaItem,
    Duration? resumePosition,
  }) async {
    final item = mediaItem ??
        MediaItem(
          id: session.mediaItemId,
          providerId: session.providerId,
          providerType: session.providerType,
          mediaType: MediaType.channel,
          title: session.metadata['title']?.toString() ?? session.mediaItemId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    final headers = <String, String>{...session.headers};
    if (session.userAgent != null) {
      headers['User-Agent'] = session.userAgent!;
    }
    if (session.referer != null) {
      headers['Referer'] = session.referer!;
    }
    if (session.origin != null) {
      headers['Origin'] = session.origin!;
    }
    if (session.requiresBearerToken) {
      headers['Authorization'] = 'Bearer ${session.bearerToken}';
    }
    if (session.cookies.isNotEmpty) {
      headers['Cookie'] = CookieManager.serializeCookies(session.cookies);
    }

    final playableMediaSession = PlayableMediaSession(
      id: session.sessionId,
      mediaItem: item,
      stream: PlayableStream(
        url: session.streamUrl,
        headers: headers,
        expires: session.expiresAt,
        drm: session.drmInformation?.toMap(),
      ),
      providerId: session.providerId,
      resumePosition: resumePosition ?? Duration.zero,
      capabilities: PlaybackCapabilities(
        canResume: true,
        canPause: session.supportsPause,
        canSeek: session.supportsSeeking,
        canChangeSpeed: true,
        canChangeAspectRatio: true,
        canPictureInPicture: true,
        canChangeQuality: true,
        canChangeAudioTrack: true,
        canChangeSubtitle: true,
        supportsSubtitles: true,
      ),
      metadata: SessionMetadata(
        title: item.title,
        description: item.description,
        posterUrl: item.poster,
        providerType: item.providerType.name,
        isLive: item.mediaType == MediaType.channel,
      ),
    );

    _currentSession = playableMediaSession;
    _currentPlayableSession = session;
    sessionRx.value = playableMediaSession;
    _retryCount = 0;
    _attemptedEngines.clear();
    _analytics = PlaybackAnalytics(
      sessionId: playableMediaSession.id,
      itemId: item.id,
      providerType: item.providerType.name,
      startedAt: DateTime.now(),
    );

    await _maybeSelectEngineForUrl(
      session.streamUrl,
      isLive: item.mediaType == MediaType.channel,
    );

    await _runLoad(
      () => _adapter.playSession(session, title: item.title),
      title: session.mediaItemId,
      loadId: 'stream session',
    );
    if (resumePosition != null && resumePosition > Duration.zero) {
      await seek(resumePosition);
    }
    unawaited(_autoEnableSubtitles());
    return playableMediaSession;
  }

  Future<void> _autoEnableSubtitles() async {
    try {
      final tracks = await _adapter.getAvailableSubtitleTracks();
      if (tracks.isNotEmpty) {
        final first = tracks.first;
        final trackId = (first is Map ? first['id'] : first)?.toString();
        if (trackId != null &&
            trackId.isNotEmpty &&
            trackId != 'no' &&
            trackId != 'none' &&
            trackId != '-1') {
          await setSubtitleTrack(trackId);
          logger.info(
            'Auto-enabled subtitle track: $trackId',
            tag: 'PlaybackEngine',
          );
        }
      }
    } catch (_) {}
  }

  Future<void> play() async {
    if (_state == PlaybackState.paused) {
      await adapter.resume();
      _setState(PlaybackState.playing);
      _publishEvent(PlaybackResumedEvent(
        sessionId: _currentSession!.id,
        occurredAt: DateTime.now(),
      ));
      _resumeAnalytics();
    } else if (_state == PlaybackState.stopped ||
        _state == PlaybackState.idle ||
        _state == PlaybackState.completed) {
      await adapter.play();
      _setState(PlaybackState.playing);
      _startAnalytics();
    }
  }

  Future<void> pause() async {
    if (_state == PlaybackState.playing) {
      await adapter.pause();
      _setState(PlaybackState.paused);
      _publishEvent(PlaybackPausedEvent(
        sessionId: _currentSession!.id,
        position: adapter.position,
        occurredAt: DateTime.now(),
      ));
      _pauseAnalytics();
      logger.info('Playback paused', tag: 'PlaybackEngine');
    }
  }

  Future<void> resume() async {
    await adapter.resume();
    _setState(PlaybackState.playing);
    _publishEvent(PlaybackResumedEvent(
      sessionId: _currentSession!.id,
      occurredAt: DateTime.now(),
    ));
    _resumeAnalytics();
  }

  Future<void> stop() async {
    await adapter.stop();
    _setState(PlaybackState.stopped);
    _finalizeAnalytics();
    _cleanup();
    logger.info('Playback stopped', tag: 'PlaybackEngine');
  }

  Future<void> seek(Duration position) async {
    if (_currentSession == null) return;
    _setState(PlaybackState.seeking);
    try {
      await adapter.seek(position);
      _setState(PlaybackState.playing);
      _analytics?.seekCount = _analytics!.seekCount + 1;
      _publishEvent(PlaybackSeekingEvent(
        sessionId: _currentSession!.id,
        position: position,
        occurredAt: DateTime.now(),
      ));
    } catch (e) {
      _handleError('Seek failed: $e');
    }
  }

  Future<void> replay() async {
    if (_currentSession == null) return;
    await seek(Duration.zero);
    await play();
  }

  Future<void> next() async {
    if (_currentSession == null) return;
    _analytics?.channelChanges = _analytics!.channelChanges + 1;
    await stop();
    _publishEvent(PlaybackCompletedEvent(
      sessionId: _currentSession!.id,
      itemId: _currentSession!.mediaItem.id,
      occurredAt: DateTime.now(),
    ));
  }

  Future<void> previous() async {
    if (_currentSession == null) return;
    _analytics?.channelChanges = _analytics!.channelChanges + 1;
    await stop();
  }

  Future<void> retry() async {
    if (_currentSession == null || _retryCount >= maxRetries) return;
    _retryCount++;
    logger.info(
      'Retrying playback (attempt $_retryCount)',
      tag: 'PlaybackEngine',
    );
    await loadSession(_currentSession!);
  }

  Future<void> setSpeed(PlaybackSpeed speed) async {
    await adapter.setSpeed(speed);
    speedRx.value = speed;
    _analytics?.speedChanges[speed.label] =
        (_analytics?.speedChanges[speed.label] ?? 0) + 1;
  }

  Future<void> setAspectRatio(AspectRatioMode mode) async {
    await adapter.setAspectRatio(mode);
    aspectRatioRx.value = mode;
  }

  Future<void> setQuality(PlayerQuality quality) async {
    await adapter.setQuality(quality);
    qualityRx.value = quality;
    _analytics?.qualityChanges[quality.displayName] =
        (_analytics?.qualityChanges[quality.displayName] ?? 0) + 1;
    _publishEvent(QualityChangedEvent(
      sessionId: _currentSession!.id,
      quality: quality,
      occurredAt: DateTime.now(),
    ));
  }

  Future<void> setSubtitleTrack(String trackId) async {
    await adapter.setSubtitleTrack(trackId);
    _publishEvent(SubtitleChangedEvent(
      sessionId: _currentSession!.id,
      subtitleTrackId: trackId,
      occurredAt: DateTime.now(),
    ));
  }

  Future<void> setAudioTrack(String trackId) async {
    await adapter.setAudioTrack(trackId);
    _publishEvent(AudioChangedEvent(
      sessionId: _currentSession!.id,
      audioTrackId: trackId,
      occurredAt: DateTime.now(),
    ));
  }

  Future<void> setVolume(double volume) async {
    await adapter.setVolume(volume);
    volumeRx.value = volume;
  }

  Future<void> setMuted(bool muted) async {
    await adapter.setMuted(muted);
    mutedRx.value = muted;
  }

  void addStateListener(void Function(PlaybackState) listener) {
    _stateListeners.add(listener);
  }

  void removeStateListener(void Function(PlaybackState) listener) {
    _stateListeners.remove(listener);
  }

  void addPositionListener(void Function(Duration) listener) {
    _positionListeners.add(listener);
  }

  void removePositionListener(void Function(Duration) listener) {
    _positionListeners.remove(listener);
  }

  void addBufferListener(void Function(Duration) listener) {
    _bufferListeners.add(listener);
  }

  void removeBufferListener(void Function(Duration) listener) {
    _bufferListeners.remove(listener);
  }

  void addEventListener(void Function(PlaybackEvent) listener) {
    _eventListeners.add(listener);
  }

  void removeEventListener(void Function(PlaybackEvent) listener) {
    _eventListeners.remove(listener);
  }

  Future<void> dispose() async {
    _finalizeAnalytics();
    _cleanup();
    await adapter.dispose();
    logger.info('PlaybackEngine disposed', tag: 'PlaybackEngine');
  }

  void _setState(PlaybackState newState) {
    _state = newState;
    stateRx.value = newState;
    if (newState != PlaybackState.error) {
      errorMessageRx.value = '';
    }
    for (final listener in List.from(_stateListeners)) {
      listener(newState);
    }
  }

  void _bindAdapterStreams() {
    _stateSub = adapter.stateStream.listen((state) async {
      if (state != _state) {
        _setState(state);
        if (state == PlaybackState.completed) {
          _onCompleted();
        } else if (state == PlaybackState.error) {
          if (await _tryEngineFallback() && _currentSession != null) {
            await loadSession(_currentSession!);
            return;
          }
          _handleError('Adapter reported error');
        }
      }
    });

    _positionSub = adapter.positionStream.listen((position) {
      positionRx.value = position;
      for (final listener in List.from(_positionListeners)) {
        listener(position);
      }
    });

    _bufferSub = adapter.bufferStream.listen((buffer) {
      bufferRx.value = buffer;
      for (final listener in List.from(_bufferListeners)) {
        listener(buffer);
      }
    });

    _errorSub = adapter.errorStream.listen((error) async {
      if (await _tryEngineFallback() && _currentSession != null) {
        await loadSession(_currentSession!);
        return;
      }
      _handleError('Player error: $error');
    });

    _subtitleSub = adapter.subtitleStream.listen((text) {
      // Subtitles handled by UI overlay
    });
  }

  /// Cancels the subscriptions created by [_bindAdapterStreams].
  ///
  /// Used when swapping backends so the old adapter's streams stop feeding the
  /// engine before the adapter is disposed.
  void _disposeAdapterStreams() {
    _stateSub?.cancel();
    _stateSub = null;
    _positionSub?.cancel();
    _positionSub = null;
    _bufferSub?.cancel();
    _bufferSub = null;
    _errorSub?.cancel();
    _errorSub = null;
    _subtitleSub?.cancel();
    _subtitleSub = null;
  }

  /// Selects the best backend for a stream URL when the engine is in Auto mode
  /// and swaps the active adapter if the backend changed.
  Future<void> _maybeSelectEngineForUrl(
    String url, {
    required bool isLive,
  }) async {
    if (!allowEngineFallback) return;
    var selected = _selectionStrategy.selectForUrl(
      url,
      preference: settings.preferredPlayer,
      isLive: isLive,
    );
    if (settings.preferredPlayer == PlaybackEnginePreference.auto &&
        await HardwareDetector.isUnisocOrMali()) {
      logger.warning(
        'Unisoc/Mali chipset detected, forcing Native Activity Player to avoid black screen',
        tag: 'PlaybackEngine',
      );
      selected = PlaybackEngineKind.nativeActivity;
    }
    if (selected != _engineKind) {
      logger.info(
        'Selecting ${selected.displayName} engine for stream',
        tag: 'PlaybackEngine',
      );
      await _swapAdapter(selected);
    }
  }

  /// Replaces the active adapter with the one for [kind], keeping the engine
  /// state machine and stream subscriptions intact.
  ///
  /// The swap is always initiated before any load action is run (engine
  /// selection in [createSession]/[playFromStreamEngine] and runtime fallback
  /// both call this before [_runLoad]'s load action), so a backend that must
  /// await its render surface (e.g. ExoPlayerSurfaceViewAdapter waiting for the
  /// platform view) is mounted before playback commands are sent. The reactive
  /// `engineKindRx` change below also remounts the video surface in the player
  /// page (see the keyed PlatformViewLink in ExoPlayerSurfaceViewAdapter), so
  /// the new adapter's `_viewReady` completes instead of deadlocking.
  Future<void> _swapAdapter(PlaybackEngineKind kind) async {
    final previous = _adapter;
    // Surface the switch to the UI immediately so the player page remounts the
    // new backend's surface and shows "Connecting..." instead of a stale frame.
    _setState(PlaybackState.loading);
    _adapter = PlayerAdapterFactory.create(
      kind,
      logger: logger,
      hardwareDecode: settings.hardwareDecode,
    );
    _engineKind = kind;
    engineKindRx.value = kind;
    _disposeAdapterStreams();
    await previous.dispose();
    await _adapter.initialize();
    _bindAdapterStreams();
    logger.info(
      'Switched playback engine to ${kind.displayName}',
      tag: 'PlaybackEngine',
    );
  }

  /// Attempts to recover from a failed load by switching to another backend.
  /// Returns `true` when a fallback was performed.
  ///
  /// Only runs in Auto mode, respects an explicit user preference, and iterates
  /// through candidates until all supported options have been exhausted.
  Future<bool> _tryEngineFallback() async {
    if (!allowEngineFallback) return false;
    if (_engineKind == PlaybackEngineKind.nativeActivity) return false;
    if (settings.preferredPlayer != PlaybackEnginePreference.auto) return false;

    _attemptedEngines.add(_engineKind);
    final url = _currentSession?.stream.url ?? '';
    final isLive = _currentSession?.metadata.isLive ?? false;
    final candidates = _selectionStrategy.fallbackOrderFor(url, isLive: isLive);
    for (final candidate in candidates) {
      if (candidate == _engineKind || _attemptedEngines.contains(candidate)) {
        continue;
      }
      if (!PlayerAdapterFactory.isSupported(candidate)) {
        continue;
      }
      _attemptedEngines.add(candidate);
      logger.warning(
        'Falling back from ${_engineKind.displayName} to ${candidate.displayName}',
        tag: 'PlaybackEngine',
      );
      await _swapAdapter(candidate);
      final rawSession = _currentPlayableSession;
      if (rawSession != null) {
        await _adapter.playSession(rawSession);
      } else {
        final currentSession = _currentSession;
        if (currentSession != null) {
          await _adapter.load(currentSession);
        }
      }
      return true;
    }
    return false;
  }

  /// Runs [loadAction] (a backend-specific load) with the engine's shared
  /// loading/buffering/playing state machine. On failure, retries once through
  /// the alternate engine when Auto fallback is available.
  Future<void> _runLoad(
    Future<void> Function() loadAction, {
    required String title,
    required String loadId,
  }) async {
    _setState(PlaybackState.loading);
    try {
      await loadAction();
      _setState(PlaybackState.buffering);
      await adapter.play();
      _setState(PlaybackState.playing);
      _startAnalytics();
      _startBufferMonitoring();
      _retryCount = 0;
      logger.info(
        'Session loaded: $title',
        tag: 'PlaybackEngine',
      );
    } catch (e, st) {
      if (await _tryEngineFallback()) {
        await _runLoad(loadAction, title: title, loadId: loadId);
        return;
      }
      _handleError('Failed to load $loadId: $e', st);
      rethrow;
    }
  }

  void _onCompleted() {
    if (_currentSession == null) return;
    _finalizeAnalytics();
    _publishEvent(PlaybackCompletedEvent(
      sessionId: _currentSession!.id,
      itemId: _currentSession!.mediaItem.id,
      occurredAt: DateTime.now(),
    ));
    logger.info('Playback completed', tag: 'PlaybackEngine');
  }

  /// Records a user-facing playback failure and transitions to the error state.
  ///
  /// Used for failures that happen before a [PlayableSession] reaches the
  /// engine (e.g. stream resolution) so the UI can show why playback failed
  /// instead of hanging on a loading state.
  void failPlayback(String message, {StackTrace? stackTrace}) {
    _handleError(message, stackTrace);
  }

  void _handleError(String message, [StackTrace? stackTrace]) {
    errorMessageRx.value = message;
    if (_analytics != null) {
      _analytics = _analytics!.copyWith(
        errorCount: _analytics!.errorCount + 1,
        lastError: message,
      );
    }
    _setState(PlaybackState.error);
    _publishEvent(PlaybackErrorEvent(
      sessionId: _currentSession?.id ?? 'unknown',
      error: message,
      stackTrace: stackTrace?.toString(),
      occurredAt: DateTime.now(),
    ));
    logger.error(message, tag: 'PlaybackEngine', error: message, stackTrace: stackTrace);
  }

  void _publishEvent(PlaybackEvent event) {
    for (final listener in List.from(_eventListeners)) {
      listener(event);
    }
  }

  void _startAnalytics() {
    _analyticsTimer?.cancel();
    _analyticsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_state == PlaybackState.playing && _currentSession != null) {
        _analytics = _analytics!.copyWith(
          totalWatchTime: _analytics!.totalWatchTime + const Duration(seconds: 30),
        );
      }
    });
  }

  void _pauseAnalytics() {
    _analyticsTimer?.cancel();
  }

  void _resumeAnalytics() {
    _startAnalytics();
  }

  void _finalizeAnalytics() {
    _analyticsTimer?.cancel();
    if (_analytics != null && _currentSession != null) {
      _analytics = _analytics!.copyWith(
        endedAt: DateTime.now(),
        completionPercentage: _calculateCompletion(),
      );
    }
  }

  double _calculateCompletion() {
    if (_currentSession == null || durationRx.value == Duration.zero) return 0.0;
    return (positionRx.value.inMilliseconds / durationRx.value.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  void _startBufferMonitoring() {
    _bufferTimer?.cancel();
    _bufferTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_state != PlaybackState.playing && _state != PlaybackState.buffering) {
        return;
      }
      try {
        final info = await adapter.getBufferInfo();
        bufferInfoRx.value = info;
        if (!info.isHealthy && _retryCount < maxRetries) {
          logger.warning(
            'Buffer unhealthy: ${info.bufferPercentage}% '
            '(${info.bufferHealthMs}ms buffered, ${info.droppedFrames} '
            'dropped frames)',
            tag: 'PlaybackEngine',
          );
        }
        // Silent black-screen detection (media_kit only): on some Android
        // devices (e.g. Unisoc/Mali) the native decoder produces frames but
        // Flutter's external-texture consumer never renders them (logcat:
        // `dequeueBuffer: BufferQueue has been abandoned`, codec output
        // buffers never recycled). No Dart exception is raised, so the usual
        // fallback path never fires. After a grace period, force the engine
        // to another backend per the selection strategy (on Android this
        // prefers ExoPlayer's real SurfaceView, which is composited by
        // SurfaceFlinger and bypasses Flutter's texture sampler), then reload
        // the current session on it.
        final activeAdapter = adapter;
        if (activeAdapter is MediaKitPlayerAdapter &&
            !activeAdapter.hasVideoFrames) {
          _silentVideoSeconds += 5;
          if (_silentVideoSeconds >= 5) {
            logger.warning(
              'Black screen detected: playing but no video frame rendered '
              'for $_silentVideoSeconds s; switching engine',
              tag: 'PlaybackEngine',
            );
            if (await _tryEngineFallback() && _currentSession != null) {
              await loadSession(_currentSession!);
            }
          }
        } else {
          _silentVideoSeconds = 0;
        }
      } catch (e) {
        // Non-critical
      }
    });
  }

  void _cleanup() {
    _disposeAdapterStreams();
    _bufferTimer?.cancel();
    _bufferTimer = null;
    _analyticsTimer?.cancel();
    _analyticsTimer = null;
    _stateListeners.clear();
    _positionListeners.clear();
    _bufferListeners.clear();
    _eventListeners.clear();
    _currentSession = null;
    sessionRx.value = null;
    _analytics = null;
    _setState(PlaybackState.idle);
  }
}
