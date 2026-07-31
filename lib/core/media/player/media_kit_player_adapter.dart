import 'dart:async';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/logging/logging_service.dart';

class MediaKitPlayerAdapter implements PlayerAdapter {
  mk.Player? _player;
  VideoController? _videoController;
  final LoggingService _logger;

  final _stateController = StreamController<PlaybackState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _bufferController = StreamController<Duration>.broadcast();
  final _errorController = StreamController<PlaybackState>.broadcast();
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

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _bufferSub;
  StreamSubscription<double>? _volumeSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<Object>? _errorSub;

  MediaKitPlayerAdapter({LoggingService? logger})
      : _logger = logger ?? LoggingService();

  mk.Player? get player => _player;
  VideoController? get videoController => _videoController;

  @override
  Future<void> initialize() async {
    _player = mk.Player();
    _videoController = VideoController(_player!);
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
      }
    });

    _completedSub = _player!.stream.completed.listen((completed) {
      if (completed) {
        _setPlaybackState(PlaybackState.completed);
      }
    });

    _errorSub = _player!.stream.error.listen((error) {
      _setPlaybackState(PlaybackState.error);
      _errorController.add(PlaybackState.error);
      _logger.error(
        'Player error: $error',
        tag: 'Player',
        error: error,
      );
    });
  }

  void _setPlaybackState(PlaybackState state) {
    if (state != _currentState) {
      _currentState = state;
      _stateController.add(state);
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
    await _errorSub?.cancel();
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
    if (_player == null) return;
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
    return [
      {'id': 'default', 'label': 'Default', 'language': 'en'}
    ];
  }

  @override
  Future<List<PlayerQuality>> getAvailableQualities() async {
    return [PlayerQuality.auto];
  }

  @override
  Future<void> setAudioTrack(String trackId) async {}

  @override
  Future<void> setSubtitleTrack(String trackId) async {}

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
  Stream<PlaybackState> get errorStream => _errorController.stream;

  @override
  Stream<String> get subtitleStream => _subtitleController.stream;
}
