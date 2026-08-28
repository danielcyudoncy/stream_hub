import 'dart:async';
import 'dart:io';
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
  StreamSubscription<List<String>>? _subtitleSub;
  StreamSubscription<mk.Track>? _trackSub;

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
    return Video(
      controller: controller,
      subtitleViewConfiguration: const SubtitleViewConfiguration(
        style: TextStyle(
          height: 1.4,
          fontSize: 22.0,
          letterSpacing: 0.0,
          wordSpacing: 0.0,
          color: Color(0xffffffff),
          fontWeight: FontWeight.w600,
          backgroundColor: Color(0x99000000),
        ),
        textAlign: TextAlign.center,
        padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      ),
    );
  }

  @override
  Future<void> initialize() async {
    if (_player != null) return;
    _player = mk.Player(
      configuration: const mk.PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
      ),
    );

    // Apply libmpv properties required for live IPTV streams (MPEG-TS, HLS).
    // These must be set before any media is opened.
    if (_player is mk.NativePlayer) {
      final native = _player as mk.NativePlayer;
      try {
        // Increase probe buffer so libmpv can recognise MPEG-TS/HLS formats
        await native.setProperty('demuxer-lavf-probesize', '5000000');
        await native.setProperty('demuxer-lavf-analyzeduration', '5000000');
        // Network timeout (µs) — prevents hanging on slow/dead streams
        await native.setProperty('network-timeout', '10');
        // User-agent expected by many IPTV panels
        await native.setProperty(
            'user-agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/120.0.0.0 Safari/537.36');
        // Disable youtube-dl; not needed for direct IPTV URLs
        await native.setProperty('ytdl', 'no');
        // Increase read-ahead buffer for live streams
        await native.setProperty('demuxer-readahead-secs', '20');
        // Allow connecting to http sources from https context
        await native.setProperty('tls-verify', 'no');
        if (Platform.isAndroid) {
          await native.setProperty('hwdec', 'mediacodec-copy');
          await native.setProperty('vd-lavc-dr', 'no');
        }
      } catch (e) {
        _logger.warning(
          'Failed to set libmpv properties: $e',
          tag: 'Player',
        );
      }
    }

    _videoController = VideoController(
      _player!,
      configuration: VideoControllerConfiguration(
        hwdec: Platform.isAndroid
            ? 'mediacodec-copy'
            : (_hardwareDecode ? 'auto-safe' : 'no'),
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
      _currentVolume = (vol / 100.0).clamp(0.0, 1.0);
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

    _subtitleSub = _player!.stream.subtitle.listen((lines) {
      final text = lines.join('\n').trim();
      _subtitleController.add(text);
    });

    _tracksSub = _player!.stream.tracks.listen((tracks) {
      // Available tracks refreshed
    });

    _trackSub = _player!.stream.track.listen((track) {
      _logger.debug(
        'Active track changed: sub=${track.subtitle.id} (${track.subtitle.title ?? track.subtitle.language}), audio=${track.audio.id}',
        tag: 'Player',
      );
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
    await _subtitleSub?.cancel();
    await _trackSub?.cancel();
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
    await _player?.setVolume(_currentMuted ? 0.0 : (_currentVolume * 100.0));
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
    await _player?.setVolume(_currentMuted ? 0.0 : (_currentVolume * 100.0));
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
    final audios = _player?.state.tracks.audio ?? [];
    final currentAudioId = _player?.state.track.audio.id;
    return audios
        .where((a) => a.id != 'no' && a.id != 'null' && a.id.isNotEmpty)
        .map((a) => {
              'id': a.id,
              'label': (a.title != null && a.title!.isNotEmpty)
                  ? a.title!
                  : ((a.language != null && a.language!.isNotEmpty)
                      ? a.language!.toUpperCase()
                      : 'Track ${a.id}'),
              'language': a.language ?? 'und',
              'selected': a.id == currentAudioId,
            })
        .toList();
  }

  @override
  Future<List<dynamic>> getAvailableSubtitleTracks() async {
    final subs = _player?.state.tracks.subtitle ?? [];
    final currentSubId = _player?.state.track.subtitle.id;
    return subs
        .where((s) => s.id != 'no' && s.id != 'null' && s.id.isNotEmpty)
        .map((s) => {
              'id': s.id,
              'label': (s.title != null && s.title!.isNotEmpty)
                  ? s.title!
                  : ((s.language != null && s.language!.isNotEmpty)
                      ? s.language!.toUpperCase()
                      : 'Track ${s.id}'),
              'language': s.language ?? 'und',
              'selected': s.id == currentSubId,
            })
        .toList();
  }

  @override
  Future<List<PlayerQuality>> getAvailableQualities() async {
    return [PlayerQuality.auto];
  }

  @override
  Future<void> setAudioTrack(String trackId) async {
    if (_player == null) return;
    _logger.info('Setting audio track: $trackId', tag: 'Player');
    if (trackId.isEmpty || trackId == 'no' || trackId == 'none' || trackId == '-1') {
      await _player!.setAudioTrack(mk.AudioTrack.no());
    } else if (trackId == 'auto' || trackId == 'default') {
      await _player!.setAudioTrack(mk.AudioTrack.auto());
    } else {
      final tracks = _player!.state.tracks.audio;
      final matched = tracks.firstWhere(
        (a) =>
            a.id == trackId ||
            a.id.toLowerCase() == trackId.toLowerCase() ||
            (a.title != null && a.title!.toLowerCase() == trackId.toLowerCase()) ||
            (a.language != null && a.language!.toLowerCase() == trackId.toLowerCase()),
        orElse: () {
          final idx = int.tryParse(trackId);
          if (idx != null && idx >= 0 && idx < tracks.length) {
            return tracks[idx];
          }
          return mk.AudioTrack.auto();
        },
      );
      await _player!.setAudioTrack(matched);
    }
  }

  @override
  Future<void> setSubtitleTrack(String trackId) async {
    if (_player == null) return;
    _logger.info('Setting subtitle track: $trackId', tag: 'Player');
    if (trackId.isEmpty || trackId == 'no' || trackId == 'none' || trackId == '-1') {
      await _player!.setSubtitleTrack(mk.SubtitleTrack.no());
    } else if (trackId == 'auto' || trackId == 'default') {
      await _player!.setSubtitleTrack(mk.SubtitleTrack.auto());
    } else {
      final tracks = _player!.state.tracks.subtitle;
      final matched = tracks.firstWhere(
        (s) =>
            s.id == trackId ||
            s.id.toLowerCase() == trackId.toLowerCase() ||
            (s.title != null && s.title!.toLowerCase() == trackId.toLowerCase()) ||
            (s.language != null && s.language!.toLowerCase() == trackId.toLowerCase()),
        orElse: () {
          final idx = int.tryParse(trackId);
          if (idx != null && idx >= 0 && idx < tracks.length) {
            return tracks[idx];
          }
          return mk.SubtitleTrack.auto();
        },
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
    await _player?.setVolume(_currentMuted ? 0.0 : (_currentVolume * 100.0));
  }

  @override
  Future<void> setMuted(bool muted) async {
    _currentMuted = muted;
    await _player?.setVolume(muted ? 0.0 : (_currentVolume * 100.0));
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
