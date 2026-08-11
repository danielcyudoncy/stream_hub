import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';

/// [PlayerAdapter] backed by VLC (`libvlc` via `flutter_vlc_player`).
///
/// VLC is the resilience layer for live TV, RTSP/UDP/RTP relays and HLS
/// streams on devices where media_kit shows black video after buffering.
///
/// Render path on Android
/// - `flutter_vlc_player` renders through a `TextureView` (FlutterVlcPlayer
///   registers its SurfaceTexture with Flutter's TextureRegistry). The
///   `virtualDisplay:false` flag (set in [buildPlayerWidget]) forces hybrid
///   composition (`PlatformViewLink` + `initSurfaceAndroidView`), where
///   Android's view system composites the TextureView instead of Flutter's
///   external-texture sampler. This bypasses the dead external-texture
///   consumer that black-screens both media_kit and VLC on Unisoc/Mali
///   devices when VLC uses the default `virtualDisplay:true` path.
///
/// Platform support: Android and iOS only. On other platforms [isSupported]
/// returns `false` and the factory falls back to MediaKit.
///
/// Limitations
/// - VLC 7.4.4 does not support arbitrary HTTP header injection. User-Agent,
///   Referer and Cookie headers are mapped onto VLC access options; Bearer
///   tokens must be embedded in the stream URL by the Stream Engine.
/// - Playback begins once the [VlcPlayer] widget mounts and the platform view
///   initializes; the controller is created lazily by [playSession].
class VlcPlayerAdapter implements PlayerAdapter {
  /// Whether VLC is available on the current platform.
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  final bool _hardwareDecode;
  final LoggingService _logger;

  VlcPlayerController? _controller;

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
  AspectRatioMode _currentAspectRatio = AspectRatioMode.fit;
  PlayerQuality _currentQuality = PlayerQuality.auto;

  VlcPlayerAdapter({
    LoggingService? logger,
    bool hardwareDecode = true,
  })  : _hardwareDecode = hardwareDecode,
        _logger = logger ?? LoggingService();

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.vlc;

  @override
  bool get isInitialized => _controller != null;

  @override
  Widget buildPlayerWidget() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return ValueListenableBuilder<VlcPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) => VlcPlayer(
        controller: controller,
        aspectRatio: value.aspectRatio,
        placeholder: Container(color: const Color(0xFF000000)),
        // Android: virtualDisplay:false selects hybrid composition
        // (PlatformViewLink + initSurfaceAndroidView). With the default
        // virtualDisplay:true the plugin renders through an AndroidView whose
        // SurfaceTexture is registered with Flutter's TextureRegistry
        // (FlutterVlcPlayer.java:113) and sampled by Flutter's GL compositor -
        // the same dead external-texture consumer that black-screens media_kit
        // on Unisoc/Mali devices (GL_INVALID_OPERATION 0x505 on
        // GLConsumer.bindTextureImage, see docs/PLAYBACK_ENGINEERING.md §1.1).
        // NOTE: hybrid composition has NOT been validated on-device (the 2026-08
        // log was auto-selection/media_kit). It is a best-effort path, not a
        // confirmed fix; this device class is documented as unsupported for
        // Flutter external-texture video.
        virtualDisplay: false,
      ),
    );
  }

  @override
  Future<void> initialize() async {
    if (_controller != null) return;
    // The VLC controller requires a data source, so it is created lazily by
    // playSession/load once the stream is known.
    _logger.info('VlcPlayerAdapter ready', tag: 'Player');
  }

  @override
  Future<void> load(PlayableMediaSession session) async {
    await _playUrl(session.stream.url, headers: session.stream.headers);
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

    await _playUrl(session.streamUrl, headers: headers);
  }

  /// Maximum time to wait for the [VlcPlayer] widget to mount its platform
  /// view before VLC initialization can start.
  static const Duration _initTimeout = Duration(seconds: 10);

  Future<void> _playUrl(
    String url, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute) {
      throw Exception('Invalid stream URL: $url');
    }

    final existing = _controller;
    if (existing != null) {
      if (existing.value.isInitialized) {
        await existing.setMediaFromNetwork(url, autoPlay: true, hwAcc: _hwAcc);
        _currentPosition = Duration.zero;
        _currentDuration = Duration.zero;
        _logger.info('VLC switched media source: $url', tag: 'Player');
        return;
      }
      await _disposeController(existing);
      _controller = null;
    }

    final controller = VlcPlayerController.network(
      url,
      autoPlay: true,
      autoInitialize: false,
      hwAcc: _hwAcc,
      options: _buildOptions(headers),
      allowBackgroundPlayback: false,
    );
    _controller = controller;
    controller.addListener(_onValueChanged);
    _currentPosition = Duration.zero;
    _currentDuration = Duration.zero;
    _logger.info('VLC preparing source: $url', tag: 'Player');

    try {
      await _initializeController(controller);
    } catch (e, st) {
      _controller = null;
      controller.removeListener(_onValueChanged);
      await _disposeController(controller);
      _logger.error(
        'VLC initialization failed for $url: $e',
        tag: 'Player',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    _logger.info('VLC initialized: $url', tag: 'Player');
  }

  /// Drives VLC initialization explicitly and waits for it to complete.
  ///
  /// `flutter_vlc_player` initializes lazily inside the platform view's
  /// `onPlatformViewCreated` callback; failures there surface as *unhandled*
  /// async errors that never reach the PlaybackEngine, so its Auto fallback
  /// cannot engage and playback hangs with an empty buffer. By disabling
  /// `autoInitialize` and awaiting [VlcPlayerController.initialize] here, init
  /// failures (e.g. an unavailable native VLC) propagate through `playSession`
  /// into the engine's fallback path instead.
  Future<void> _initializeController(VlcPlayerController controller) async {
    final deadline = DateTime.now().add(_initTimeout);
    while (controller.isReadyToInitialize != true) {
      if (DateTime.now().isAfter(deadline)) {
        throw Exception(
          'VLC platform view did not mount within $_initTimeout',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await controller.initialize();
  }

  /// Disposes [controller], swallowing channel errors that occur when the
  /// native VLC side never initialized.
  Future<void> _disposeController(VlcPlayerController controller) async {
    try {
      await controller.dispose();
    } catch (e) {
      _logger.warning(
        'VLC controller dispose failed',
        tag: 'Player',
        error: e,
      );
    }
  }

  HwAcc get _hwAcc =>
      _hardwareDecode ? HwAcc.auto : HwAcc.disabled;

  /// Maps the headers produced by the Stream Engine onto VLC access options.
  ///
  /// VLC does not expose arbitrary header injection, so only User-Agent,
  /// Referer and Cookie are honored here; other headers (e.g. Authorization)
  /// must be embedded in the URL by the Stream Engine.
  VlcPlayerOptions _buildOptions(Map<String, String>? headers) {
    final httpOptions = <String>[
      VlcHttpOptions.httpReconnect(true),
      VlcHttpOptions.httpForwardCookies(true),
    ];
    final extras = <String>[];

    (headers ?? const <String, String>{}).forEach((key, value) {
      switch (key.toLowerCase()) {
        case 'user-agent':
          httpOptions.add(VlcHttpOptions.httpUserAgent(value));
        case 'referer':
          httpOptions.add(VlcHttpOptions.httpReferrer(value));
        case 'cookie':
          extras.add('--http-cookie=$value');
      }
    });

    return VlcPlayerOptions(
      advanced: VlcAdvancedOptions([
        VlcAdvancedOptions.networkCaching(1500),
        VlcAdvancedOptions.liveCaching(1000),
        VlcAdvancedOptions.clockSynchronization(1),
      ]),
      http: VlcHttpOptions(httpOptions),
      video: VlcVideoOptions([
        VlcVideoOptions.dropLateFrames(true),
        VlcVideoOptions.skipFrames(true),
      ]),
      audio: VlcAudioOptions([VlcAudioOptions.audioTimeStretch(true)]),
      rtp: VlcRtpOptions([VlcRtpOptions.rtpOverRtsp(true)]),
      extras: extras,
    );
  }

  void _onValueChanged() {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;

    _currentDuration = value.duration;
    _currentPosition = value.position;
    _currentBuffer = value.duration > Duration.zero
        ? Duration(
            milliseconds: (value.duration.inMilliseconds *
                    value.bufferPercent /
                    100)
                .round(),
          )
        : Duration.zero;

    if (value.hasError) {
      _setPlaybackState(PlaybackState.error);
      _errorController.add(
        value.errorDescription.isNotEmpty
            ? value.errorDescription
            : 'VLC playback error.',
      );
      _logger.error(
        'VLC playback error: ${value.errorDescription}',
        tag: 'Player',
        error: value.errorDescription,
      );
    }

    switch (value.playingState) {
      case PlayingState.buffering:
        if (value.isBuffering) _setPlaybackState(PlaybackState.buffering);
      case PlayingState.playing:
        if (value.isPlaying) _setPlaybackState(PlaybackState.playing);
      case PlayingState.paused:
        _setPlaybackState(PlaybackState.paused);
      case PlayingState.ended:
        _setPlaybackState(PlaybackState.completed);
      case PlayingState.stopped:
        _setPlaybackState(PlaybackState.stopped);
      case PlayingState.error:
        _setPlaybackState(PlaybackState.error);
      case PlayingState.initializing:
      case PlayingState.initialized:
      case PlayingState.recording:
        break;
    }

    if (_positionController.hasListener) {
      _positionController.add(value.position);
    }
    if (_bufferController.hasListener) {
      _bufferController.add(_currentBuffer);
    }
  }

  void _setPlaybackState(PlaybackState state) {
    if (state != _currentState) {
      _currentState = state;
      _stateController.add(state);
    }
  }

  @override
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onValueChanged);
      await _disposeController(controller);
    }
    await _stateController.close();
    await _positionController.close();
    await _bufferController.close();
    await _errorController.close();
    await _subtitleController.close();
    _logger.info('VlcPlayerAdapter disposed', tag: 'Player');
  }

  @override
  Future<void> play() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isInitialized) {
      await controller.play();
    }
  }

  @override
  Future<void> pause() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.pause();
  }

  @override
  Future<void> resume() async {
    await play();
  }

  @override
  Future<void> stop() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.seekTo(position);
  }

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
    // The engine drives retries; VLC reconnects via --http-reconnect.
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
  Future<List<dynamic>> getAvailableAudioTracks() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return const [];
    final tracks = await controller.getAudioTracks();
    return tracks.entries
        .map((e) => {'id': e.key, 'label': e.value, 'language': ''})
        .toList();
  }

  @override
  Future<List<dynamic>> getAvailableSubtitleTracks() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return const [];
    final tracks = await controller.getSpuTracks();
    return tracks.entries
        .map((e) => {'id': e.key, 'label': e.value, 'language': ''})
        .toList();
  }

  @override
  Future<List<PlayerQuality>> getAvailableQualities() async {
    return [PlayerQuality.auto];
  }

  @override
  Future<void> setAudioTrack(String trackId) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final index = int.tryParse(trackId);
    if (index != null) {
      await controller.setAudioTrack(index);
    }
  }

  @override
  Future<void> setSubtitleTrack(String trackId) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final index = int.tryParse(trackId);
    if (index != null) {
      await controller.setSpuTrack(index);
    }
  }

  @override
  Future<void> setSpeed(PlaybackSpeed speed) async {
    _currentSpeed = speed;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.setPlaybackSpeed(speed.value);
  }

  @override
  Future<void> setAspectRatio(AspectRatioMode mode) async {
    _currentAspectRatio = mode;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    switch (mode) {
      case AspectRatioMode.ratio16x9:
        await controller.setVideoAspectRatio('16:9');
      case AspectRatioMode.ratio4x3:
        await controller.setVideoAspectRatio('4:3');
      case AspectRatioMode.fit:
      case AspectRatioMode.fill:
      case AspectRatioMode.stretch:
      case AspectRatioMode.original:
      case AspectRatioMode.zoom:
        break;
    }
  }

  @override
  Future<void> setQuality(PlayerQuality quality) async {
    _currentQuality = quality;
  }

  @override
  Future<void> setVolume(double volume) async {
    _currentVolume = volume.clamp(0.0, 1.0);
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.setVolume((_currentVolume * 100).round());
  }

  @override
  Future<void> setMuted(bool muted) async {
    _currentMuted = muted;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.setVolume(muted ? 0 : (_currentVolume * 100).round());
  }

  @override
  Future<BufferInfo> getBufferInfo() async {
    return BufferInfo(
      currentBuffer: _currentBuffer,
      totalDuration: _currentDuration,
      bufferPercentage: _currentDuration > Duration.zero
          ? (_currentBuffer.inMilliseconds / _currentDuration.inMilliseconds * 100)
              .clamp(0, 100)
          : 0.0,
      bufferHealthMs: _currentBuffer.inMilliseconds,
      measuredAt: DateTime.now(),
    );
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
