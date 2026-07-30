import 'dart:async';
import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/events/playback_event.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/media/player/media_kit_player_adapter.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/media/player/player_settings.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/playback_analytics.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playable_stream.dart';

class PlaybackEngine {
  final PlayerAdapter adapter;
  final PlayerSettings settings;
  final LoggingService logger;

  PlayableMediaSession? _currentSession;
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

  final List<void Function(PlaybackState)> _stateListeners = [];
  final List<void Function(Duration)> _positionListeners = [];
  final List<void Function(Duration)> _bufferListeners = [];
  final List<void Function(PlaybackEvent)> _eventListeners = [];
  StreamSubscription<PlaybackState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _bufferSub;
  StreamSubscription<PlaybackState>? _errorSub;
  StreamSubscription<String>? _subtitleSub;

  PlaybackAnalytics? _analytics;
  Timer? _analyticsTimer;
  Timer? _bufferTimer;
  int _retryCount = 0;
  static const int maxRetries = 3;

  PlaybackEngine({
    PlayerAdapter? adapter,
    PlayerSettings? settings,
    LoggingService? logger,
  })  : adapter = adapter ?? MediaKitPlayerAdapter(),
        settings = settings ?? const PlayerSettings(),
        logger = logger ?? LoggingService();

  PlayableMediaSession? get currentSession => _currentSession;
  PlaybackState get currentState => _state;
  PlaybackAnalytics? get analytics => _analytics;
  bool get isPlaying => _state == PlaybackState.playing;
  bool get isLive => _currentSession?.metadata.isLive ?? false;

  Future<void> initialize() async {
    await adapter.initialize();
    _bindAdapterStreams();
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
    _retryCount = 0;
    _analytics = PlaybackAnalytics(
      sessionId: session.id,
      itemId: mediaItem.id,
      providerType: mediaItem.providerType.name,
      startedAt: DateTime.now(),
    );

    await loadSession(session);
    return session;
  }

  Future<void> loadSession(PlayableMediaSession session) async {
    _setState(PlaybackState.loading);
    try {
      await adapter.load(session);
      _setState(PlaybackState.buffering);
      await adapter.play();
      _setState(PlaybackState.playing);
      _startAnalytics();
      _startBufferMonitoring();
      _retryCount = 0;
      logger.info(
        'Session loaded: ${session.mediaItem.title}',
        tag: 'PlaybackEngine',
      );
    } catch (e, st) {
      _handleError('Failed to load session: $e', st);
      rethrow;
    }
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
    for (final listener in List.from(_stateListeners)) {
      listener(newState);
    }
  }

  void _bindAdapterStreams() {
    _stateSub = adapter.stateStream.listen((state) {
      if (state != _state) {
        _setState(state);
        if (state == PlaybackState.completed) {
          _onCompleted();
        } else if (state == PlaybackState.error) {
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

    _errorSub = adapter.errorStream.listen((error) {
      _handleError('Adapter error: $error');
    });

    _subtitleSub = adapter.subtitleStream.listen((text) {
      // Subtitles handled by UI overlay
    });
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

  void _handleError(String message, [StackTrace? stackTrace]) {
    _setState(PlaybackState.error);
    _analytics = _analytics!.copyWith(
      errorCount: _analytics!.errorCount + 1,
      lastError: message,
    );
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
            'Buffer unhealthy: ${info.bufferPercentage}%',
            tag: 'PlaybackEngine',
          );
        }
      } catch (e) {
        // Non-critical
      }
    });
  }

  void _cleanup() {
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
    _bufferTimer?.cancel();
    _bufferTimer = null;
    _analyticsTimer?.cancel();
    _analyticsTimer = null;
    _stateListeners.clear();
    _positionListeners.clear();
    _bufferListeners.clear();
    _eventListeners.clear();
    _currentSession = null;
    _analytics = null;
    _setState(PlaybackState.idle);
  }
}
