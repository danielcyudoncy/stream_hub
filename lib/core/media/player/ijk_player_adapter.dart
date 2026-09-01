import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/media/player/error_classification.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';
import 'package:stream_hub/core/streaming/security/sensitive_data_redactor.dart';

/// [PlayerAdapter] backed by the experimental native IJKPlayer Activity.
///
/// Phase 3 evaluation backend (see docs/PLAYBACK_ENGINEERING.md §10). It
/// mirrors [NativeActivityPlayerAdapter]: a plain Android Activity hosts
/// IjkMediaPlayer + TextureView so video is composited directly by Android,
/// outside Flutter's external-texture pipeline. This makes it a candidate for
/// devices where both media_kit and VLC black-screen, and lets the A/B test
/// compare ExoPlayer and FFmpeg-based decoding on identical streams.
///
/// Isolation rules:
/// - IJK specifics (options, JNI, error codes) never leave this adapter and
///   the corresponding Kotlin Activity; the engine/UI only see
///   [PlayerAdapter] plus [StructuredErrorReporter].
/// - `auto` mode NEVER selects this engine; it only runs when the user pins
///   it explicitly, and it is excluded from the automatic fallback chain.
///
/// Platform support: Android only ([isSupported]).
class IjkPlayerAdapter implements PlayerAdapter, StructuredErrorReporter {
  static const MethodChannel _launchChannel =
      MethodChannel('stream_hub/ijk_player_launch');
  static const MethodChannel _eventsChannel =
      MethodChannel('stream_hub/ijk_player_events');

  static bool get isSupported => Platform.isAndroid;

  final LoggingService _logger;

  bool _initialized = false;
  bool _disposed = false;
  int _videoWidth = 0;
  int _videoHeight = 0;

  NativeErrorCategory? _lastErrorCategory;
  int? _lastErrorHttpCode;

  @override
  NativeErrorCategory? get lastErrorCategory => _lastErrorCategory;

  @override
  int? get lastErrorHttpCode => _lastErrorHttpCode;

  @override
  void clearLastError() {
    _lastErrorCategory = null;
    _lastErrorHttpCode = null;
  }

  final _stateController = StreamController<PlaybackState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _bufferController = StreamController<Duration>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _subtitleController = StreamController<String>.broadcast();

  PlaybackState _currentState = PlaybackState.idle;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  Duration _currentBuffer = Duration.zero;
  double _currentVolume = 1.0;
  bool _currentMuted = false;
  PlaybackSpeed _currentSpeed = PlaybackSpeed.speed1_0;
  AspectRatioMode _currentAspectRatio = AspectRatioMode.ratio16x9;
  PlayerQuality _currentQuality = PlayerQuality.auto;

  IjkPlayerAdapter({LoggingService? logger})
      : _logger = logger ?? LoggingService();

  /// True once the native Activity has reported decoded video dimensions.
  ///
  /// Note this reports *decoded* size, not *rendered* frames; rendered-first-
  /// frame detection lives natively (INFO_VIDEO_RENDERING_START) and feeds
  /// the structured RENDERER error path instead of a Dart-side timeout.
  bool get hasVideoFrames => _videoWidth > 0 && _videoHeight > 0;

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.ijk;

  @override
  bool get isInitialized => _initialized;

  /// The video is rendered by the native Activity, not inside the Flutter
  /// widget tree.
  @override
  Widget buildPlayerWidget() => const SizedBox.shrink();

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _eventsChannel.setMethodCallHandler(_onNativeEvent);
    _logger.info('IjkPlayerAdapter ready', tag: 'Player');
  }

  @override
  Future<void> load(PlayableMediaSession session) async {
    final url = session.stream.url;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute) {
      throw Exception('Invalid stream URL: $url');
    }
    _registerAndLaunch(
      url,
      session.stream.headers ?? const <String, String>{},
      title: session.metadata.title ?? session.mediaItem.title,
      isLive: session.metadata.isLive,
    );
  }

  @override
  Future<void> playSession(PlayableSession session, {String? title}) async {
    final url = session.streamUrl;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute) {
      throw Exception('Invalid stream URL: $url');
    }
    // Header assembly mirrors NativeActivityPlayerAdapter exactly: UA /
    // Referer / Origin / Bearer / Cookie are merged with the session's custom
    // header map. No provider-specific knowledge here.
    final headers = <String, String>{...session.headers};
    if (session.userAgent != null && session.userAgent!.isNotEmpty) {
      headers['User-Agent'] = session.userAgent!;
    }
    if (session.referer != null && session.referer!.isNotEmpty) {
      headers['Referer'] = session.referer!;
    }
    if (session.origin != null && session.origin!.isNotEmpty) {
      headers['Origin'] = session.origin!;
    }
    if (session.requiresBearerToken) {
      headers['Authorization'] = 'Bearer ${session.bearerToken}';
    }
    if (session.cookies.isNotEmpty) {
      headers['Cookie'] = CookieManager.serializeCookies(session.cookies);
    }
    final isLive =
        !session.supportsSeeking || (session.metadata['isLive'] == true);
    await _registerAndLaunch(url, headers, title: title, isLive: isLive);
  }

  Future<void> _registerAndLaunch(
    String url,
    Map<String, String> headers, {
    String? title,
    required bool isLive,
  }) async {
    _eventsChannel.setMethodCallHandler(_onNativeEvent);
    clearLastError();
    try {
      await _launchChannel.invokeMethod<void>('launch', <String, dynamic>{
        'url': url,
        'headers': headers,
        if (title != null && title.isNotEmpty) 'title': title,
        'isLive': isLive,
        'hardwareDecode': true,
      });
      _logger.info(
        'IJK player launched: ${SensitiveDataRedactor.redactUrl(url)}',
        tag: 'Player',
      );
    } on PlatformException catch (e) {
      throw Exception('Failed to launch IJK player: ${e.message}');
    }
  }

  Future<void> _onNativeEvent(MethodCall call) async {
    if (_disposed) return;
    switch (call.method) {
      case 'onState':
        _setPlaybackState(_parseNativeState(call.arguments));
      case 'onPosition':
        final args = call.arguments as Map? ?? const <String, dynamic>{};
        _currentPosition = Duration(
            milliseconds: (args['positionMs'] as num?)?.toInt() ?? 0);
        _currentBuffer = Duration(
            milliseconds: (args['bufferedMs'] as num?)?.toInt() ?? 0);
        _currentDuration = Duration(
            milliseconds: (args['durationMs'] as num?)?.toInt() ?? 0);
        if (_positionController.hasListener) {
          _positionController.add(_currentPosition);
        }
        if (_bufferController.hasListener) {
          _bufferController.add(_currentBuffer);
        }
      case 'onVideo':
        final args = call.arguments as Map? ?? const <String, dynamic>{};
        _videoWidth = (args['width'] as num?)?.toInt() ?? 0;
        _videoHeight = (args['height'] as num?)?.toInt() ?? 0;
      case 'onError':
        final args = call.arguments as Map? ?? const <String, dynamic>{};
        final message = args['message']?.toString() ?? 'IJK player error.';
        _lastErrorCategory =
            parseNativeErrorCategory(args['category']?.toString());
        _lastErrorHttpCode = (args['httpCode'] as num?)?.toInt();
        _setPlaybackState(PlaybackState.error);
        _errorController.add(message);
        _logger.error(
          'IJK player error '
          '(category: ${_lastErrorCategory?.name ?? 'unclassified'}, '
          'http: ${_lastErrorHttpCode ?? '-'}): $message',
          tag: 'Player',
        );
      case 'onFinished':
        _setPlaybackState(PlaybackState.stopped);
    }
  }

  PlaybackState _parseNativeState(dynamic state) {
    switch (state) {
      case 'loading':
        return PlaybackState.loading;
      case 'buffering':
        return PlaybackState.buffering;
      case 'playing':
        return PlaybackState.playing;
      case 'paused':
        return PlaybackState.paused;
      case 'completed':
        return PlaybackState.completed;
      case 'stopped':
        return PlaybackState.stopped;
      case 'error':
        return PlaybackState.error;
      default:
        return _currentState;
    }
  }

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      await _launchChannel.invokeMethod<void>(method, args);
    } catch (e) {
      _logger.warning('IJK player $method failed', tag: 'Player', error: e);
    }
  }

  @override
  Future<void> play() => _invoke('play');

  @override
  Future<void> pause() => _invoke('pause');

  @override
  Future<void> resume() => _invoke('play');

  @override
  Future<void> stop() => _invoke('stop');

  @override
  Future<void> seek(Duration position) =>
      _invoke('seekTo', {'positionMs': position.inMilliseconds});

  @override
  Future<void> replay() async {
    await seek(Duration.zero);
    await play();
  }

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> retry() => _invoke('reload');

  @override
  PlaybackState get state => _currentState;

  @override
  Duration get position => _currentPosition;

  @override
  Duration get duration => _currentDuration;

  @override
  Duration get bufferPosition => _currentBuffer;

  @override
  double get volume => _currentVolume;

  @override
  bool get isMuted => _currentMuted;

  @override
  PlaybackSpeed get speed => _currentSpeed;

  @override
  AspectRatioMode get aspectRatio => _currentAspectRatio;

  @override
  PlayerQuality get currentQuality => _currentQuality;

  @override
  Future<List<dynamic>> getAvailableAudioTracks() async => const [];

  @override
  Future<List<dynamic>> getAvailableSubtitleTracks() async => const [];

  @override
  Future<List<PlayerQuality>> getAvailableQualities() async =>
      const [PlayerQuality.auto];

  @override
  Future<void> setAudioTrack(String trackId) async {}

  @override
  Future<void> setSubtitleTrack(String trackId) async {}

  @override
  Future<void> enterPictureInPicture() async {}

  @override
  bool get isInPip => false;

  @override
  Future<void> setSpeed(PlaybackSpeed speed) async {
    _currentSpeed = speed;
    await _invoke('setSpeed', {'speed': speed.value});
  }

  @override
  Future<void> setAspectRatio(AspectRatioMode mode) async {
    _currentAspectRatio = mode;
  }

  @override
  Future<void> setQuality(PlayerQuality quality) async {
    _currentQuality = quality;
  }

  @override
  Future<void> setVolume(double volume) async {
    _currentVolume = volume.clamp(0.0, 1.0);
    await _invoke('setVolume', {'volume': _currentVolume});
  }

  @override
  Future<void> setMuted(bool muted) async {
    _currentMuted = muted;
    await _invoke('setMuted', {'muted': muted});
  }

  @override
  Future<BufferInfo> getBufferInfo() async {
    return BufferInfo(
      currentBuffer: _currentBuffer,
      totalDuration: _currentDuration,
      bufferPercentage: _currentDuration > Duration.zero
          ? (_currentBuffer.inMilliseconds /
                  _currentDuration.inMilliseconds *
                  100)
              .clamp(0, 100)
          : 0.0,
      bufferHealthMs: _currentBuffer.inMilliseconds,
      measuredAt: DateTime.now(),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _invoke('stop');
    await _stateController.close();
    await _positionController.close();
    await _bufferController.close();
    await _errorController.close();
    await _subtitleController.close();
    _logger.info('IjkPlayerAdapter disposed', tag: 'Player');
  }

  void _setPlaybackState(PlaybackState state) {
    if (state != _currentState) {
      _currentState = state;
      _stateController.add(state);
    }
  }

  @override
  Stream<PlaybackState> get stateStream => _stateController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration> get bufferStream => _bufferController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  Stream<String> get subtitleStream => _subtitleController.stream;
}
