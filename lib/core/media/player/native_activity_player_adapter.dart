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

/// [PlayerAdapter] backed by a fullscreen native Android ExoPlayer Activity.
///
/// On Unisoc/Mali devices (e.g. itel C671L) every video render path that goes
/// through Flutter's compositor is broken:
/// - External textures (media_kit, VLC): the GL consumer never samples frames
///   (`GL_INVALID_OPERATION` 0x505, see docs/PLAYBACK_ENGINEERING.md §1.1).
/// - Hybrid-composition platform views (ExoPlayerSurfaceViewAdapter): a
///   SurfaceView's frames reach SurfaceFlinger but are never composited, and a
///   TextureView never initializes its surface inside the platform-view wrapper.
///
/// This adapter instead launches [NativePlayerActivity] (registered through the
/// `stream_hub/native_player_launch` channel), a plain Android Activity hosting
/// ExoPlayer + TextureView. The video is an ordinary window surface composited
/// by Android with no Flutter involvement, which is the only path proven
/// to display video on the target device class.
///
/// State flows back through the `stream_hub/native_player_events` MethodChannel,
/// where this adapter registers the receiving handler.
///
/// Platform support: Android only ([isSupported]).
class NativeActivityPlayerAdapter implements PlayerAdapter, StructuredErrorReporter {
  static const MethodChannel _launchChannel =
      MethodChannel('stream_hub/native_player_launch');
  static const MethodChannel _eventsChannel =
      MethodChannel('stream_hub/native_player_events');

  static bool get isSupported => Platform.isAndroid;

  final LoggingService _logger;

  bool _initialized = false;
  bool _disposed = false;
  bool _inPip = false;

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
  final _pipController = StreamController<bool>.broadcast();

  PlaybackState _currentState = PlaybackState.idle;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  Duration _currentBuffer = Duration.zero;
  double _currentVolume = 1.0;
  bool _currentMuted = false;
  PlaybackSpeed _currentSpeed = PlaybackSpeed.speed1_0;
  AspectRatioMode _currentAspectRatio = AspectRatioMode.ratio16x9;
  PlayerQuality _currentQuality = PlayerQuality.auto;

  NativeActivityPlayerAdapter({LoggingService? logger})
      : _logger = logger ?? LoggingService();

  /// True once the native Activity has reported decoded video dimensions.
  bool get hasVideoFrames => _videoWidth > 0 && _videoHeight > 0;

  /// True when the native player is currently in Picture-in-Picture mode.
  @override
  bool get isInPip => _inPip;

  Stream<bool> get pipStream => _pipController.stream;

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.nativeActivity;

  @override
  bool get isInitialized => _initialized;

  /// The video is rendered by the native Activity, not inside the Flutter
  /// widget tree, so the player page shows an empty surface behind it.
  @override
  Widget buildPlayerWidget() => const SizedBox.shrink();

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _registerEventListener();
    _logger.info('NativeActivityPlayerAdapter ready', tag: 'Player');
  }

  /// Registers the native event handler. Idempotent and safe to call again
  /// before every launch.
  void _registerEventListener() {
    _eventsChannel.setMethodCallHandler(_onNativeEvent);
  }

  @override
  Future<void> load(PlayableMediaSession session) async {
    final url = session.stream.url;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute) {
      throw Exception('Invalid stream URL: $url');
    }
    _registerEventListener();
    clearLastError();
    final isLive = session.metadata.isLive;
    await _launch(
      url,
      session.stream.headers ?? const <String, String>{},
      title: session.metadata.title ?? session.mediaItem.title,
      channels: _cachedChannels,
      channelIndex: _cachedChannelIndex,
      isLive: isLive,
    );
  }

  @override
  Future<void> playSession(PlayableSession session, {String? title}) async {
    final url = session.streamUrl;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute) {
      throw Exception('Invalid stream URL: $url');
    }
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
    _registerEventListener();
    clearLastError();
    final isLive =
        !session.supportsSeeking || (session.metadata['isLive'] == true);
    await _launch(
      url,
      headers,
      title: title,
      channels: _cachedChannels,
      channelIndex: _cachedChannelIndex,
      isLive: isLive,
    );
  }

  List<Map<String, dynamic>>? _cachedChannels;
  int _cachedChannelIndex = -1;

  void Function()? onNextChannelRequested;
  void Function()? onPreviousChannelRequested;
  void Function(int index, String? channelId)? onSwitchChannelRequested;
  void Function()? onFetchChannelsRequested;

  Future<void> updateChannelList(
    List<Map<String, dynamic>> channels, {
    int currentIndex = -1,
  }) async {
    _cachedChannels = channels;
    if (currentIndex >= 0) {
      _cachedChannelIndex = currentIndex;
    }
    await _invoke('setChannelList', <String, dynamic>{
      'channels': channels,
      if (currentIndex >= 0) 'channelIndex': currentIndex,
    });
  }

  Future<void> _launch(
    String url,
    Map<String, String> headers, {
    String? title,
    List<Map<String, dynamic>>? channels,
    int channelIndex = -1,
    bool isLive = false,
  }) async {
    final ch = channels ?? _cachedChannels;
    final idx = channelIndex >= 0 ? channelIndex : _cachedChannelIndex;
    try {
      await _launchChannel.invokeMethod<void>('launch', <String, dynamic>{
        'url': url,
        'headers': headers,
        if (title != null && title.isNotEmpty) 'title': title,
        if (ch != null && ch.isNotEmpty) 'channels': ch,
        if (idx >= 0) 'channelIndex': idx,
        'isLive': isLive,
      });
      _logger.info(
        'Native player launched: '
        '${SensitiveDataRedactor.redactUrl(url)}',
        tag: 'Player',
      );
    } on PlatformException catch (e) {
      throw Exception('Failed to launch native player: ${e.message}');
    }
  }

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      await _launchChannel.invokeMethod<void>(method, args);
    } catch (e) {
      _logger.warning(
        'Native player $method failed',
        tag: 'Player',
        error: e,
      );
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
      case 'onPipChanged':
        final args = call.arguments as Map? ?? const <String, dynamic>{};
        _inPip = args['inPip'] as bool? ?? false;
        if (_pipController.hasListener) {
          _pipController.add(_inPip);
        }
      case 'onNextChannelRequested':
        onNextChannelRequested?.call();
      case 'onPreviousChannelRequested':
        onPreviousChannelRequested?.call();
      case 'onFetchChannelsRequested':
        onFetchChannelsRequested?.call();
      case 'onChannelChanged':
        final args = call.arguments as Map? ?? const <String, dynamic>{};
        final index = (args['index'] as num?)?.toInt() ?? -1;
        final channelId = args['channelId']?.toString();
        if (index >= 0) _cachedChannelIndex = index;
        _logger.info(
          'Native player channel changed: ${args['name']} (index: $index)',
          tag: 'Player',
        );
        onSwitchChannelRequested?.call(index, channelId);
      case 'onResolveChannelRequested':
        final args = call.arguments as Map? ?? const <String, dynamic>{};
        final index = (args['index'] as num?)?.toInt() ?? -1;
        final channelId = args['channelId']?.toString();
        if (index >= 0) _cachedChannelIndex = index;
        onSwitchChannelRequested?.call(index, channelId);
      case 'onError':
        final args = call.arguments as Map? ?? const <String, dynamic>{};
        final message = args['message']?.toString() ?? 'Native player error.';
        _lastErrorCategory = parseNativeErrorCategory(args['category']?.toString());
        _lastErrorHttpCode = (args['httpCode'] as num?)?.toInt();
        _setPlaybackState(PlaybackState.error);
        _errorController.add(message);
        _logger.error(
          'Native player error '
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
  Future<void> next() => _invoke('nextChannel');

  @override
  Future<void> previous() => _invoke('previousChannel');

  /// Triggers Picture-in-Picture mode on Android 8.0+.
  @override
  Future<void> enterPictureInPicture() => _invoke('enterPip');

  /// Switches to a specific channel index in the native player.
  Future<void> switchChannel(int index) =>
      _invoke('switchChannel', {'index': index});

  @override
  Future<void> retry() async {
    // The engine drives retries; relaunching is handled by playSession.
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
    await _pipController.close();
    _logger.info('NativeActivityPlayerAdapter disposed', tag: 'Player');
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
