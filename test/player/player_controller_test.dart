import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/media/player/playback_controller.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/prepared_download.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';

class _FakePlayerAdapter implements PlayerAdapter {
  int initializeCount = 0;
  int playSessionCount = 0;
  final List<PlayableSession> playedSessions = [];

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.mediaKit;

  @override
  bool get isInitialized => false;

  @override
  Widget buildPlayerWidget() => const SizedBox.shrink();

  @override
  Future<void> initialize() async {
    initializeCount++;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> load(PlayableMediaSession session) async {}

  @override
  Future<void> playSession(PlayableSession session, {String? title}) async {
    playSessionCount++;
    playedSessions.add(session);
  }

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
  PlaybackState get state => PlaybackState.idle;

  @override
  Duration get position => Duration.zero;

  @override
  Duration get duration => Duration.zero;

  @override
  Duration get bufferPosition => Duration.zero;

  @override
  double get volume => 1.0;

  @override
  bool get isMuted => false;

  @override
  PlaybackSpeed get speed => PlaybackSpeed.speed1_0;

  @override
  AspectRatioMode get aspectRatio => AspectRatioMode.fit;

  @override
  PlayerQuality get currentQuality => PlayerQuality.auto;

  List<dynamic> subtitleTracks = [];
  List<dynamic> audioTracks = [];
  String? lastSubtitleTrack;
  String? lastAudioTrack;

  @override
  Future<List<dynamic>> getAvailableAudioTracks() async => audioTracks;

  @override
  Future<List<dynamic>> getAvailableSubtitleTracks() async => subtitleTracks;

  @override
  Future<List<PlayerQuality>> getAvailableQualities() async =>
      const [PlayerQuality.auto];

  @override
  Future<void> setAudioTrack(String trackId) async {
    lastAudioTrack = trackId;
  }

  @override
  Future<void> setSubtitleTrack(String trackId) async {
    lastSubtitleTrack = trackId;
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
        currentBuffer: Duration.zero,
        totalDuration: Duration.zero,
        bufferPercentage: 0,
        bufferHealthMs: 0,
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
  Future<void> enterPictureInPicture() async {}

  @override
  bool get isInPip => false;
}

class _FakeStreamRepository implements StreamRepository {
  int resolvePlaybackCount = 0;
  Object? errorToThrow;

  @override
  Future<PlayableSession> resolvePlayback({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
    bool useCache = true,
    bool validate = true,
  }) async {
    resolvePlaybackCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return PlayableSession(
      sessionId: 'session_$mediaItemId',
      mediaItemId: mediaItemId,
      providerId: providerId ?? 'provider',
      providerType: providerType,
      streamUrl: 'https://example.com/live/stream.m3u8',
      streamType: StreamType.hls,
    );
  }

  @override
  Future<PlayableSession> resolveStream({
    required String mediaItemId,
    required String url,
    required ProviderSession providerSession,
    Map<String, dynamic> itemMetadata = const {},
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<PreparedDownload> prepareDownload({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
    bool validate = true,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> validate(PlayableSession session) async => true;

  @override
  Future<PlayableSession> selectWorking(PlayableSession session) async =>
      session;

  @override
  Future<void> startBackgroundTasks() async {}

  @override
  Future<void> stopBackgroundTasks() async {}
}

void main() {
  group('PlaybackController engine lifecycle', () {
    test('exposes a ready engine without GetX lifecycle hooks', () {
      // Regression: PlaybackController is composed manually inside
      // PlayerController (never registered with GetX), so onInit() never runs.
      // The engine must be usable immediately instead of throwing
      // LateInitializationError.
      final controller = PlaybackController();
      expect(controller.engine, isNotNull);
      expect(controller.engine.currentState, PlaybackState.idle);
      expect(controller.engine.adapter, isNotNull);
    });

    test('failPlayback surfaces a message and enters error state', () async {
      final controller = PlaybackController();
      controller.engine.failPlayback('boom');
      expect(controller.engine.currentState, PlaybackState.error);
      expect(controller.engine.errorMessageRx.value, 'boom');
      await controller.engine.dispose();
    });

    test('leaving the error state clears the error message', () async {
      final controller = PlaybackController();
      controller.engine.failPlayback('boom');
      expect(controller.engine.errorMessageRx.value, 'boom');
      await controller.engine.stop();
      expect(controller.engine.errorMessageRx.value, isEmpty);
    });
  });

  group('PlayerController channel playback', () {
    test('setChannelList triggers playback without engine access failures',
        () async {
      final adapter = _FakePlayerAdapter();
      final repository = _FakeStreamRepository();
      final controller = PlayerController(
        adapter: adapter,
        streamRepository: repository,
      );

      final item = MediaItem(
        id: 'chan-1',
        providerId: 'provider-1',
        providerType: MediaSourceType.stalker,
        mediaType: MediaType.channel,
        title: 'News',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      controller.setChannelList([item], currentId: item.id);
      await pumpEventQueue();

      expect(repository.resolvePlaybackCount, 1);
      expect(adapter.playSessionCount, 1);
      expect(adapter.playedSessions.first.mediaItemId, 'chan-1');
      expect(controller.state, PlaybackState.playing);

      await controller.playbackController.stop();
      await controller.playbackController.engine.dispose();
    });

    test('resolution failure surfaces through the engine error state',
        () async {
      final adapter = _FakePlayerAdapter();
      final repository = _FakeStreamRepository()..errorToThrow = 'dns failed';
      final controller = PlayerController(
        adapter: adapter,
        streamRepository: repository,
      );

      final item = MediaItem(
        id: 'chan-2',
        providerId: 'provider-1',
        providerType: MediaSourceType.stalker,
        mediaType: MediaType.channel,
        title: 'Movies',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      controller.setChannelList([item], currentId: item.id);
      await pumpEventQueue();

      expect(repository.resolvePlaybackCount, 1);
      expect(adapter.playSessionCount, 0);
      expect(controller.state, PlaybackState.error);
      expect(
        controller.playbackController.engine.errorMessageRx.value,
        contains('chan-2'),
      );

      await controller.playbackController.engine.dispose();
    });

    test('switchToNextChannel and switchToPreviousChannel continuously cycle through channels',
        () async {
      final adapter = _FakePlayerAdapter();
      final repository = _FakeStreamRepository();
      final controller = PlayerController(
        adapter: adapter,
        streamRepository: repository,
      );

      final item1 = MediaItem(
        id: 'chan-1',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.channel,
        title: 'Channel 1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final item2 = MediaItem(
        id: 'chan-2',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.channel,
        title: 'Channel 2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      controller.setChannelList([item1, item2], currentId: item1.id);
      await pumpEventQueue();

      expect(adapter.playedSessions.last.mediaItemId, 'chan-1');

      // Next -> Channel 2
      await controller.switchToNextChannel();
      await pumpEventQueue();
      expect(adapter.playedSessions.last.mediaItemId, 'chan-2');

      // Next -> wraps to Channel 1
      await controller.switchToNextChannel();
      await pumpEventQueue();
      expect(adapter.playedSessions.last.mediaItemId, 'chan-1');

      // Previous -> wraps to Channel 2
      await controller.switchToPreviousChannel();
      await pumpEventQueue();
      expect(adapter.playedSessions.last.mediaItemId, 'chan-2');

      await controller.playbackController.engine.dispose();
    });

    test('getAvailableSubtitleTracks and setSubtitleTrack update player state and observable',
        () async {
      final adapter = _FakePlayerAdapter();
      adapter.subtitleTracks = [
        {'id': '1', 'label': 'English', 'language': 'eng'},
        {'id': '2', 'label': 'Spanish', 'language': 'spa'},
      ];
      final repository = _FakeStreamRepository();
      final controller = PlayerController(
        adapter: adapter,
        streamRepository: repository,
      );

      final tracks = await controller.getAvailableSubtitleTracks();
      expect(tracks, hasLength(2));
      expect(tracks.first['label'], 'English');

      await controller.setSubtitleTrack('1');
      expect(controller.selectedSubtitleTrackRx.value, '1');
      expect(adapter.lastSubtitleTrack, '1');

      await controller.setSubtitleTrack('no');
      expect(controller.selectedSubtitleTrackRx.value, 'no');
      expect(adapter.lastSubtitleTrack, 'no');

      await controller.playbackController.engine.dispose();
    });

    test('getAvailableAudioTracks and setAudioTrack update player state and observable',
        () async {
      final adapter = _FakePlayerAdapter();
      adapter.audioTracks = [
        {'id': '1', 'label': 'English (AAC)', 'language': 'eng'},
        {'id': '2', 'label': 'French (AC3)', 'language': 'fra'},
      ];
      final repository = _FakeStreamRepository();
      final controller = PlayerController(
        adapter: adapter,
        streamRepository: repository,
      );

      final tracks = await controller.getAvailableAudioTracks();
      expect(tracks, hasLength(2));

      await controller.setAudioTrack('2');
      expect(controller.selectedAudioTrackRx.value, '2');
      expect(adapter.lastAudioTrack, '2');

      await controller.playbackController.engine.dispose();
    });
  });
}
