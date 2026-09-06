import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/iptv/models/stream_analysis.dart';
import 'package:stream_hub/core/iptv/models/stream_protocol.dart';
import 'package:stream_hub/core/iptv/negotiation/capability_detector.dart';
import 'package:stream_hub/core/iptv/negotiation/stream_negotiation_engine.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/media/player/pip_floating_capable.dart';
import 'package:stream_hub/core/media/player/playback_controller.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/media/player/ijk_player_adapter.dart';
import 'package:stream_hub/core/media/player/vlc_player_adapter.dart';
import 'package:stream_hub/core/media/player/exo_player_surface_view_adapter.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';

class _TrackingPlayerAdapter implements PlayerAdapter {
  bool pipEntered = false;
  bool isPipActive = false;
  List<dynamic> audioTracks = [
    {'id': '1', 'label': 'English', 'selected': true},
    {'id': '2', 'label': 'Spanish', 'selected': false},
  ];
  List<dynamic> subtitleTracks = [
    {'id': '10', 'label': 'English CC', 'selected': true},
  ];
  String selectedAudio = '';
  String selectedSub = '';

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.mediaKit;

  @override
  bool get isInitialized => true;

  @override
  Widget buildPlayerWidget() => const SizedBox.shrink();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> load(PlayableMediaSession session) async {}

  @override
  Future<void> playSession(PlayableSession session, {String? title}) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> replay() async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> retry() async {}

  @override
  PlaybackState get state => PlaybackState.playing;

  @override
  Duration get position => Duration.zero;

  @override
  Duration get duration => const Duration(minutes: 10);

  @override
  Duration get bufferPosition => Duration.zero;

  @override
  double get volume => 1.0;

  @override
  bool get isMuted => false;

  @override
  PlaybackSpeed get speed => PlaybackSpeed.speed1_0;

  @override
  AspectRatioMode get aspectRatio => AspectRatioMode.ratio16x9;

  @override
  PlayerQuality get currentQuality => PlayerQuality.auto;

  @override
  Future<List<dynamic>> getAvailableAudioTracks() async => audioTracks;

  @override
  Future<List<dynamic>> getAvailableSubtitleTracks() async => subtitleTracks;

  @override
  Future<List<PlayerQuality>> getAvailableQualities() async => [PlayerQuality.auto];

  @override
  Future<void> setAudioTrack(String trackId) async {
    selectedAudio = trackId;
  }

  @override
  Future<void> setSubtitleTrack(String trackId) async {
    selectedSub = trackId;
  }

  @override
  Future<void> setSpeed(PlaybackSpeed speed) async {}

  @override
  Future<void> setAspectRatio(AspectRatioMode mode) async {}

  @override
  Future<void> setQuality(PlayerQuality quality) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<BufferInfo> getBufferInfo() async => BufferInfo(
        currentBuffer: const Duration(seconds: 10),
        totalDuration: const Duration(minutes: 10),
        bufferPercentage: 100,
        bufferHealthMs: 10000,
        measuredAt: DateTime.now(),
      );

  @override
  Stream<PlaybackState> get stateStream => const Stream.empty();

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Stream<Duration> get bufferStream => const Stream.empty();

  @override
  Stream<String> get errorStream => const Stream.empty();

  @override
  Stream<String> get subtitleStream => const Stream.empty();

  @override
  Future<void> enterPictureInPicture() async {
    pipEntered = true;
    isPipActive = true;
  }

  @override
  bool get isInPip => isPipActive;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Capability System — Picture-in-Picture', () {
    test('StreamCapabilities exposes supportsPiP with expected defaults', () {
      const defaultCaps = StreamCapabilities();
      expect(defaultCaps.supportsPiP, isTrue);

      const liveCaps = StreamCapabilities.live();
      expect(liveCaps.supportsPiP, isTrue);

      const vodCaps = StreamCapabilities.vod();
      expect(vodCaps.supportsPiP, isTrue);

      final modified = defaultCaps.copyWith(supportsPiP: false);
      expect(modified.supportsPiP, isFalse);
    });

    test('CapabilityDetector includes supportsPiP in detected capabilities', () {
      const detector = CapabilityDetector();
      final caps = detector.detect(
        StreamProtocol.hls,
        metadata: {'audioTracks': true, 'subtitles': true},
        analysis: const StreamAnalysis(
          container: 'm3u8',
          videoCodec: 'h264',
          audioCodec: 'aac',
        ),
      );

      expect(caps.supportsPiP, isTrue);
    });

    test('StreamNegotiationEngine merges supportsPiP from session and detected', () async {
      final negotiationEngine = StreamNegotiationEngine();
      final session = PlayableSession(
        sessionId: 'sess_1',
        mediaItemId: 'item_1',
        providerId: 'prov_1',
        providerType: MediaSourceType.xtream,
        streamUrl: 'https://example.com/live/1.m3u8',
        streamType: StreamType.hls,
        supportsPiP: true,
      );

      final negotiated = await negotiationEngine.negotiate(session: session, withAnalysis: false);
      expect(negotiated.capabilities.supportsPiP, isTrue);

      final restrictedSession = session.copyWith(supportsPiP: false);
      final negotiatedRestricted =
          await negotiationEngine.negotiate(session: restrictedSession, withAnalysis: false);
      expect(negotiatedRestricted.capabilities.supportsPiP, isFalse);
    });

    test('PlaybackEngine respects session supportsPiP in PlaybackCapabilities', () async {
      final adapter = _TrackingPlayerAdapter();
      final controller = PlaybackController(adapter: adapter);

      final session = PlayableSession(
        sessionId: 'sess_test',
        mediaItemId: 'media_test',
        providerId: 'prov_test',
        providerType: MediaSourceType.xtream,
        streamUrl: 'https://example.com/test.m3u8',
        streamType: StreamType.mp4,
        supportsPiP: true,
      );

      final mediaSession = await controller.playSession(session);
      expect(mediaSession.capabilities.canPictureInPicture, isTrue);

      final noPipSession = session.copyWith(supportsPiP: false);
      final noPipMediaSession = await controller.playSession(noPipSession);
      expect(noPipMediaSession.capabilities.canPictureInPicture, isFalse);

      controller.dispose();
    });
  });

  group('Player Pipeline — Track Wiring and PiP Execution', () {
    test('PlaybackController wires getAvailableAudioTracks and getAvailableSubtitleTracks to engine and adapter', () async {
      final adapter = _TrackingPlayerAdapter();
      final controller = PlaybackController(adapter: adapter);

      final audio = await controller.getAvailableAudioTracks();
      expect(audio.length, 2);
      expect(audio.first['label'], 'English');

      final subs = await controller.getAvailableSubtitleTracks();
      expect(subs.length, 1);
      expect(subs.first['label'], 'English CC');

      await controller.setAudioTrack('2');
      expect(adapter.selectedAudio, '2');

      await controller.setSubtitleTrack('10');
      expect(adapter.selectedSub, '10');

      controller.dispose();
    });

    test('PlaybackController delegates enterPictureInPicture and exposes isInPip', () async {
      final adapter = _TrackingPlayerAdapter();
      final controller = PlaybackController(adapter: adapter);

      expect(controller.isInPip, isFalse);
      await controller.enterPictureInPicture();
      expect(adapter.pipEntered, isTrue);
      expect(controller.isInPip, isTrue);

      controller.dispose();
    });

    test('All concrete adapters implement PipFloatingCapable or handle enterPictureInPicture gracefully', () async {
      final vlc = VlcPlayerAdapter();
      expect(vlc, isA<PipFloatingCapable>());
      expect(vlc.isInPip, isFalse);
      // Safe to call without floating attached
      await vlc.enterPictureInPicture();
      expect(vlc.isInPip, isFalse);

      final exo = ExoPlayerSurfaceViewAdapter();
      expect(exo, isA<PipFloatingCapable>());
      expect(exo.isInPip, isFalse);
      await exo.enterPictureInPicture();

      final ijk = IjkPlayerAdapter();
      expect(ijk.isInPip, isFalse);
      await ijk.enterPictureInPicture();
    });
  });
}
