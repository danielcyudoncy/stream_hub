import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';

class MediaKitPlayerAdapter implements PlayerAdapter {
  mk.Player? _player;
  VideoController? _videoController;
  final LoggingService _logger;

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

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _bufferSub;
  StreamSubscription<double>? _volumeSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<Object>? _errorSub;
  StreamSubscription<mk.VideoParams>? _videoParamsSub;
  StreamSubscription<mk.Tracks>? _tracksSub;

  int _videoWidth = 0;
  int _videoHeight = 0;

  final bool _hardwareDecode;

  MediaKitPlayerAdapter({
    LoggingService? logger,
    bool hardwareDecode = true,
  })  : _logger = logger ?? LoggingService(),
        _hardwareDecode = hardwareDecode;

  mk.Player? get player => _player;
  VideoController? get videoController => _videoController;

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.mediaKit;

  /// True once media_kit has decoded a frame with real pixel dimensions.
  ///
  /// On some Android devices (e.g. Unisoc/Mali) the native decoder produces
  /// frames but Flutter's external-texture consumer never samples them and
  /// the screen stays black (logcat: `dequeueBuffer: BufferQueue has been
  /// abandoned`, codec output buffers never recycled). This flag lets the
  /// engine detect that silent failure and fall back to VLC, whose platform
  /// view does not use Flutter external textures.
  bool get hasVideoFrames => _videoWidth > 0 && _videoHeight > 0;

  @override
  bool get isInitialized => _player != null;

  @override
  Widget buildPlayerWidget() {
    final controller = _videoController;
    if (controller == null) return const SizedBox.shrink();
    return Video(controller: controller);
  }

  @override
  Future<void> initialize() async {
    if (_player != null) return;
    _player = mk.Player();
    _videoController = VideoController(
      _player!,
      configuration: VideoControllerConfiguration(
        hwdec: _hardwareDecode ? 'auto-safe' : 'no',
        enableHardwareAcceleration: _hardwareDecode,
      ),
    );
    _bindStreams();
    _logger.info('MediaKitPlayerAdapter initialized', tag: 'Player');
  }

  void _bindStreams() {
    _positionSub = _player!.stream.position.listen((pos) {
      _currentPosition = pos;
      _positionController.add(pos);
    });

    _bufferSub = _player!.stream.buffer.listen((buf) {
      _currentBuffer = buf;
      _bufferController.add(buf);
    });

    _videoParamsSub = _player!.stream.videoParams.listen((params) {
      _videoWidth = params.w ?? _videoWidth;
      _videoHeight = params.h ?? _videoHeight;
    });

    _volumeSub = _player!.stream.volume.listen((vol) {
      _currentVolume = vol;
    });

    _playingSub = _player!.stream.playing.listen((playing) {
      if (playing) {
        _setPlaybackState(PlaybackState.playing);
      } else if (_currentState == PlaybackState.playing ||
          _currentState == PlaybackState.buffering) {
        _setPlaybackState(PlaybackState.paused);
      }
    });

    _bufferingSub = _player!.stream.buffering.listen((buffering) {
      if (buffering) {
        _setPlaybackState(PlaybackState.buffering);
      } else {
        _syncStateFromPlayer();
      }
    });

    _completedSub = _player!.stream.completed.listen((completed) {
      if (completed) {
        _setPlaybackState(PlaybackState.completed);
      }
    });

    _tracksSub = _player!.stream.tracks.listen((tracks) {
      if (tracks.subtitle.length > 1) {
        final currentSub = _player!.state.track.subtitle;
        if (currentSub == mk.SubtitleTrack.no() ||
            currentSub.id == 'no' ||
            currentSub.id.isEmpty) {
          final firstSub = tracks.subtitle.firstWhere(
            (s) => s.id != 'no' && s.id != 'null' && s.id.isNotEmpty,
            orElse: () => mk.SubtitleTrack.auto(),
          );
          _player?.setSubtitleTrack(firstSub);
        }
      }
    });

    _errorSub = _player!.stream.error.listen((error) {
      _setPlaybackState(PlaybackState.error);
      _errorController.add(
        _describePlayerError(error),
      );
      _logger.error(
        'Player error: $error',
        tag: 'Player',
        error: error,
      );
    });
  }

  /// Normalizes a media_kit player error message for display.
  static String _describePlayerError(String error) {
    final detail = error.trim();
    if (detail.isEmpty) return 'Unknown player error.';
    return detail;
  }

  void _setPlaybackState(PlaybackState state) {
    if (state != _currentState) {
      _currentState = state;
      _stateController.add(state);
    }
  }

  /// Derives the playback state from the native player after buffering ends.
  ///
  /// media_kit's `buffering` stream only signals the transition into and out of
  /// the buffering state; the `playing` stream fires on its own transitions.
  /// Without reconciling here, a buffering event that arrives after the initial
  /// `playing` transition would leave the engine stuck in a buffering state
  /// while video plays underneath the UI overlay.
  void _syncStateFromPlayer() {
    if (_player == null) return;
    if (_player!.state.playing) {
      _setPlaybackState(PlaybackState.playing);
    } else if (_player!.state.completed) {
      _setPlaybackState(PlaybackState.completed);
    } else {
      _setPlaybackState(PlaybackState.paused);
    }
  }

  @override
  Future<void> dispose() async {
    await _positionSub?.cancel();
    await _bufferSub?.cancel();
    await _volumeSub?.cancel();
    await _playingSub?.cancel();
    await _bufferingSub?.cancel();
    await _completedSub?.cancel();
    await _tracksSub?.cancel();
    await _errorSub?.cancel();
    await _videoParamsSub?.cancel();
    await _player?.dispose();
    await _stateController.close();
    await _positionController.close();
    await _bufferController.close();
    await _errorController.close();
    await _subtitleController.close();
    _videoController = null;
    _player = null;
    _logger.info('MediaKitPlayerAdapter disposed', tag: 'Player');
  }

  @override
  Future<void> load(PlayableMediaSession session) async {
    if (_player == null) {
      await initialize();
    }
    final uri = Uri.tryParse(session.stream.url);
    if (uri == null || !uri.isAbsolute) {
      throw Exception('Invalid stream URL: ${session.stream.url}');
    }
    final media = mk.Media(session.stream.url,
        httpHeaders: session.stream.headers);
    await _player!.open(media);
    _currentDuration = Duration.zero;
  }

  @override
  Future<void> playSession(PlayableSession session, {String? title}) async {
    if (_player == null) {
      await initialize();
    }
    final uri = Uri.tryParse(session.streamUrl);
    if (uri == null || !uri.isAbsolute) {
      throw Exception('Invalid stream URL: ${session.streamUrl}');
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

    await _player!.open(mk.Media(session.streamUrl, httpHeaders: headers));
    _currentDuration = Duration.zero;
  }

  @override
  Future<void> play() async {
    await _player?.play();
  }

  @override
  Future<void> pause() async {
    await _player?.pause();
  }

  @override
  Future<void> resume() async {
    await _player?.play();
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player?.seek(position);
  }

  @override
  Future<void> replay() async {
    await _player?.seek(Duration.zero);
    await _player?.play();
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
  Future<void> retry() async {}

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
    return [
      {'id': 'default', 'label': 'Default', 'language': 'en'}
    ];
  }

  @override
  Future<List<dynamic>> getAvailableSubtitleTracks() async {
    final subs = _player?.state.tracks.subtitle ?? [];
    return subs
        .where((s) => s.id != 'no' && s.id != 'null' && s.id.isNotEmpty)
        .map((s) => {
              'id': s.id,
              'label': s.title ?? s.language ?? s.id,
              'language': s.language ?? 'und',
            })
        .toList();
  }

  @override
  Future<List<PlayerQuality>> getAvailableQualities() async {
    return [PlayerQuality.auto];
  }

  @override
  Future<void> setAudioTrack(String trackId) async {}

  @override
  Future<void> setSubtitleTrack(String trackId) async {
    if (_player == null) return;
    if (trackId.isEmpty || trackId == 'no' || trackId == 'none' || trackId == '-1') {
      await _player!.setSubtitleTrack(mk.SubtitleTrack.no());
    } else if (trackId == 'auto' || trackId == 'default') {
      await _player!.setSubtitleTrack(mk.SubtitleTrack.auto());
    } else {
      final tracks = _player!.state.tracks.subtitle;
      final matched = tracks.firstWhere(
        (s) => s.id == trackId,
        orElse: () => mk.SubtitleTrack.auto(),
      );
      await _player!.setSubtitleTrack(matched);
    }
  }

  @override
  Future<void> setSpeed(PlaybackSpeed speed) async {
    _currentSpeed = speed;
    await _player?.setRate(speed.value);
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
    await _player?.setVolume(_currentVolume);
  }

  @override
  Future<void> setMuted(bool muted) async {
    _currentMuted = muted;
    await _player?.setVolume(muted ? 0.0 : _currentVolume);
  }

  @override
  Future<BufferInfo> getBufferInfo() async {
    final buf = _currentBuffer;
    final dur = _currentDuration;
    return BufferInfo(
      currentBuffer: buf,
      totalDuration: dur,
      bufferPercentage: dur > Duration.zero
          ? (buf.inMilliseconds / dur.inMilliseconds * 100).clamp(0, 100)
          : 0.0,
      bufferHealthMs: buf.inMilliseconds,
      videoWidth: _videoWidth,
      videoHeight: _videoHeight,
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
