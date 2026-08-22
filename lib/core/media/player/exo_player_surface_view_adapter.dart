import 'dart:async';
import 'dart:io';

import 'package:flutter/rendering.dart';
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

/// [PlayerAdapter] backed by ExoPlayer (AndroidX Media3) rendered through a
/// real Android `TextureView` hosted in a Hybrid-Composition platform view.
///
/// Render path
/// - The native platform view ([ExoPlayerSurfaceView]) renders MediaCodec
///   output into a `TextureView` inside a Flutter Hybrid-Composition platform
///   view. This was designed to bypass Flutter's external-texture GL sampler
///   (which black-screens on Unisoc/Mali devices). Note that on that device
///   class the TextureView surface never initializes inside the platform-view
///   wrapper, so live playback is handled by the [NativeActivityPlayerAdapter]
///   instead (see docs/PLAYBACK_ENGINEERING.md §1.1 and §8.3).
///
/// Platform support: Android only ([isSupported]).
///
/// Protocol support (native Media3 sources)
/// - HLS, DASH, RTSP, and progressive MP4/MKV/WebM/MPEG-TS.
/// - RTMP/UDP/RTP remain on VLC (see [PlayerSelectionStrategy]).
///
/// Channels
/// - Control: `stream_hub/exo_surface_<viewId>` (MethodChannel).
/// - Events: `stream_hub/exo_surface_events_<viewId>` (EventChannel).
class ExoPlayerSurfaceViewAdapter implements PlayerAdapter, StructuredErrorReporter {
  static const String _viewType = 'com.example.stream_hub/exo_surface';
  static const Duration _viewMountTimeout = Duration(seconds: 10);

  /// Whether ExoPlayer's native SurfaceView backend is available.
  static bool get isSupported => Platform.isAndroid;

  final LoggingService _logger;
  final bool _hardwareDecode;

  MethodChannel? _channel;
  EventChannel? _events;
  StreamSubscription<dynamic>? _eventSub;
  final Completer<int> _viewReady = Completer<int>();
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

  ExoPlayerSurfaceViewAdapter({
    LoggingService? logger,
    bool hardwareDecode = true,
  })  : _logger = logger ?? LoggingService(),
        _hardwareDecode = hardwareDecode;

  /// True once ExoPlayer has reported decoded video dimensions.
  ///
  /// Unlike the media_kit/vlc backends this is reached through a real
  /// SurfaceView (SurfaceFlinger compositing), so it doubles as a signal that
  /// the native render path is active and frames are being produced.
  bool get hasVideoFrames => _videoWidth > 0 && _videoHeight > 0;

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.exoPlayer;

  @override
  bool get isInitialized => _initialized;

  @override
  Widget buildPlayerWidget() {
    if (!_initialized) return const SizedBox.shrink();
    // initExpensiveAndroidView always uses Hybrid Composition, guaranteeing
    // the SurfaceView is composited by the Android view system instead of
    // Flutter's external-texture GL sampler.
    //
    // The PlatformViewLink is keyed by this adapter instance. Flutter keeps a
    // platform view alive as long as the widget stays in the same tree slot
    // with the same key; without the key, a new adapter created by an engine
    // swap (PlaybackEngine._swapAdapter) would reuse the previous adapter's
    // AndroidViewController, so `onCreatePlatformView` would never fire again,
    // the new adapter's `_viewReady` would never complete, and the old native
    // ExoPlayer (already released by the previous adapter's dispose) would
    // leave an orphaned, producer-less render surface. A per-instance key
    // forces the tree to tear down the old view and create a fresh one exactly
    // when the engine swaps backends.
    return PlatformViewLink(
      key: ValueKey(this),
      viewType: _viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const {},
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) {
        final controller = PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: <String, dynamic>{'hardwareDecode': _hardwareDecode},
          creationParamsCodec: const StandardMessageCodec(),
        );
        controller.addOnPlatformViewCreatedListener(params.onPlatformViewCreated);
        controller.addOnPlatformViewCreatedListener(_onPlatformViewCreated);
        controller.create();
        return controller;
      },
    );
  }

  void _onPlatformViewCreated(int viewId) {
    if (_disposed) return;
    _channel = MethodChannel('stream_hub/exo_surface_$viewId');
    _events = EventChannel('stream_hub/exo_surface_events_$viewId');
    _eventSub?.cancel();
    _eventSub = _events!.receiveBroadcastStream().listen(_onNativeEvent);
    if (!_viewReady.isCompleted) _viewReady.complete(viewId);
    _logger.info('ExoPlayer platform view created (id: $viewId)', tag: 'Player');
  }

  void _onNativeEvent(dynamic data) {
    if (data is! Map) return;
    switch (data['type']) {
      case 'state':
        _setPlaybackState(_parseNativeState(data['state']));
      case 'position':
        final positionMs = (data['positionMs'] as num?)?.toInt() ?? 0;
        final bufferedMs = (data['bufferedMs'] as num?)?.toInt() ?? 0;
        final durationMs = (data['durationMs'] as num?)?.toInt() ?? 0;
        _currentPosition = Duration(milliseconds: positionMs);
        _currentBuffer = Duration(milliseconds: bufferedMs);
        _currentDuration = Duration(milliseconds: durationMs);
        if (_positionController.hasListener) {
          _positionController.add(_currentPosition);
        }
        if (_bufferController.hasListener) {
          _bufferController.add(_currentBuffer);
        }
      case 'video':
        _videoWidth = (data['width'] as num?)?.toInt() ?? 0;
        _videoHeight = (data['height'] as num?)?.toInt() ?? 0;
      case 'error':
        final message =
            data['message']?.toString() ?? 'ExoPlayer playback error.';
        _lastErrorCategory = parseNativeErrorCategory(data['category']?.toString());
        _lastErrorHttpCode = (data['httpCode'] as num?)?.toInt();
        _setPlaybackState(PlaybackState.error);
        _errorController.add(message);
        _logger.error(
          'ExoPlayer playback error '
          '(category: ${_lastErrorCategory?.name ?? 'unclassified'}, '
          'http: ${_lastErrorHttpCode ?? '-'}): $message',
          tag: 'Player',
        );
    }
  }

  PlaybackState _parseNativeState(dynamic state) {
    switch (state) {
      case 'buffering':
        return PlaybackState.buffering;
      case 'playing':
        return PlaybackState.playing;
      case 'paused':
        return PlaybackState.paused;
      case 'completed':
        return PlaybackState.completed;
      case 'error':
        return PlaybackState.error;
      default:
        return _currentState;
    }
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _logger.info('ExoPlayerSurfaceViewAdapter ready', tag: 'Player');
  }

  @override
  Future<void> load(PlayableMediaSession session) async {
    await _loadUrl(session.stream.url, headers: session.stream.headers);
  }

  @override
  Future<void> playSession(PlayableSession session, {String? title}) async {
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
    await _loadUrl(session.streamUrl, headers: headers);
  }

  Future<void> _loadUrl(String url, {Map<String, String>? headers}) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute) {
      throw Exception('Invalid stream URL: $url');
    }
    clearLastError();
    final viewId = await _waitForPlatformView();
    final channel = _channel;
    if (channel == null) {
      throw Exception('ExoPlayer platform view is not ready (viewId: $viewId)');
    }
    await channel.invokeMethod<void>('load', <String, dynamic>{
      'url': url,
      'headers': headers ?? const <String, String>{},
    });
    _logger.info(
      'ExoPlayer loading source: ${SensitiveDataRedactor.redactUrl(url)}',
      tag: 'Player',
    );
  }

  /// Waits for the [PlatformViewLink] to mount and create the native view.
  ///
  /// The engine calls [playSession] as soon as the load flow starts; the player
  /// page mounts [buildPlayerWidget] during that same flow, so the platform
  /// view is created asynchronously. Sending the `load` command before the
  /// native side exists would be dropped, so we block until [viewId] arrives.
  Future<int> _waitForPlatformView() async {
    if (_viewReady.isCompleted) return _viewReady.future;
    return _viewReady.future.timeout(_viewMountTimeout, onTimeout: () {
      final message =
          'ExoPlayer platform view did not mount within $_viewMountTimeout';
      _setPlaybackState(PlaybackState.error);
      _errorController.add(message);
      _logger.error(message, tag: 'Player');
      throw Exception(message);
    });
  }

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>(method, args);
    } catch (e) {
      _logger.warning(
        'ExoPlayer $method failed',
        tag: 'Player',
        error: e,
      );
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
  Future<void> next() async {
    await stop();
  }

  @override
  Future<void> previous() async {
    await stop();
  }

  @override
  Future<void> retry() async {
    // The engine drives retries; ExoPlayer's DefaultMediaSourceFactory retries
    // connection attempts natively.
  }

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
  Future<List<dynamic>> getAvailableAudioTracks() => _getTracks('getAvailableAudioTracks');

  @override
  Future<List<dynamic>> getAvailableSubtitleTracks() =>
      _getTracks('getAvailableSubtitleTracks');

  Future<List<dynamic>> _getTracks(String method) async {
    final channel = _channel;
    if (channel == null) return const [];
    try {
      final result = await channel.invokeMethod<List<dynamic>>(method);
      return result ?? const [];
    } catch (e) {
      _logger.warning(
        'ExoPlayer $method failed',
        tag: 'Player',
        error: e,
      );
      return const [];
    }
  }

  @override
  Future<List<PlayerQuality>> getAvailableQualities() async {
    final channel = _channel;
    if (channel == null) return [PlayerQuality.auto];
    try {
      final result =
          await channel.invokeMethod<List<dynamic>>('getAvailableQualities');
      final qualities = <PlayerQuality>[PlayerQuality.auto];
      if (result != null) {
        for (final entry in result) {
          if (entry is Map && entry['quality'] is String) {
            final quality = _qualityFromLabel(entry['quality'] as String);
            if (quality != null && !qualities.contains(quality)) {
              qualities.add(quality);
            }
          }
        }
      }
      return qualities;
    } catch (e) {
      _logger.warning(
        'ExoPlayer getAvailableQualities failed',
        tag: 'Player',
        error: e,
      );
      return [PlayerQuality.auto];
    }
  }

  PlayerQuality? _qualityFromLabel(String label) {
    switch (label) {
      case '4K':
        return PlayerQuality.p2160;
      case '1080p':
        return PlayerQuality.p1080;
      case '720p':
        return PlayerQuality.p720;
      case '480p':
        return PlayerQuality.p480;
      case '360p':
        return PlayerQuality.p360;
      default:
        return null;
    }
  }

  @override
  Future<void> setAudioTrack(String trackId) =>
      _invoke('setAudioTrack', {'trackId': trackId});

  @override
  Future<void> setSubtitleTrack(String trackId) =>
      _invoke('setSubtitleTrack', {'trackId': trackId});

  @override
  Future<void> setSpeed(PlaybackSpeed speed) async {
    _currentSpeed = speed;
    await _invoke('setSpeed', {'speed': speed.value});
  }

  @override
  Future<void> setAspectRatio(AspectRatioMode mode) async {
    _currentAspectRatio = mode;
    await _invoke('setAspectRatio', {'mode': mode.name});
  }

  @override
  Future<void> setQuality(PlayerQuality quality) async {
    _currentQuality = quality;
    await _invoke('setQuality', {'quality': quality.displayName});
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
    if (!_viewReady.isCompleted) {
      _viewReady.completeError(Exception('Adapter disposed before platform view mounted'));
    }
    try {
      await _channel?.invokeMethod<void>('dispose');
    } catch (e) {
      _logger.warning(
        'ExoPlayer dispose failed',
        tag: 'Player',
        error: e,
      );
    }
    await _eventSub?.cancel();
    _eventSub = null;
    await _stateController.close();
    await _positionController.close();
    await _bufferController.close();
    await _errorController.close();
    await _subtitleController.close();
    _logger.info('ExoPlayerSurfaceViewAdapter disposed', tag: 'Player');
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
