import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/media/player/buffer_info.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/services/parental_control_service.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/core/repositories/download_repository.dart';
import 'package:stream_hub/core/services/download_service.dart';
import 'package:stream_hub/data/models/download_item.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/modules/downloads/controllers/downloads_controller.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';

class _FakePlayerAdapter implements PlayerAdapter {
  int initializeCount = 0;
  int playSessionCount = 0;
  final List<PlayableSession> playedSessions = [];

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.mediaKit;

  @override
  bool get isInitialized => true;

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
  Future<void> enterPictureInPicture() async {}

  @override
  bool get isInPip => false;

  @override
  Stream<String> get errorStream => const Stream.empty();

  @override
  Stream<String> get subtitleStream => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStreamRepository implements StreamRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummyDownloadRepository implements DownloadRepository {
  @override
  Stream<List<DownloadItem>> watchDownloads() => const Stream.empty();

  @override
  Future<List<DownloadItem>> getAllDownloads() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummyDownloadService implements DownloadService {
  @override
  Future<int> getTotalStorageUsed() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeParentalControlService extends ParentalControlService {
  bool mockIsLocked = false;
  bool mockPromptResult = false;
  int promptCalls = 0;

  @override
  bool get isLocked => mockIsLocked;

  @override
  Future<bool> promptPinUnlock({
    BuildContext? context,
    String title = 'Parental Lock',
    String message = 'Enter your 4-digit PIN to proceed.',
  }) async {
    promptCalls++;
    if (mockPromptResult) {
      mockIsLocked = false;
    }
    return mockPromptResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePlayerAdapter fakeAdapter;
  late _FakeStreamRepository fakeStreamRepo;
  late _FakeParentalControlService fakeParentalService;

  setUp(() {
    Get.reset();
    Get.put<LoggingService>(LoggingService());
    fakeAdapter = _FakePlayerAdapter();
    fakeStreamRepo = _FakeStreamRepository();
    fakeParentalService = _FakeParentalControlService();
  });

  tearDown(() {
    Get.reset();
  });

  group('Parental Control Playback Gate Tests', () {
    test('Playback proceeds without prompt when parental control is not locked', () async {
      fakeParentalService.mockIsLocked = false;

      final controller = PlayerController(
        adapter: fakeAdapter,
        streamRepository: fakeStreamRepo,
        parentalControlService: fakeParentalService,
      );

      final item = MediaItem(
        id: 'movie_1',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.movie,
        title: 'Movie Title',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final session = PlayableSession(
        sessionId: 's1',
        streamUrl: 'http://stream.example/1.m3u8',
        mediaItemId: 'movie_1',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        streamType: StreamType.hls,
      );

      await controller.playWithSession(item, session);

      expect(fakeParentalService.promptCalls, equals(0));
      expect(fakeAdapter.playSessionCount, equals(1));
    });

    test('Playback is BLOCKED when parental lock is active and PIN entry is cancelled/failed', () async {
      fakeParentalService.mockIsLocked = true;
      fakeParentalService.mockPromptResult = false; // user cancelled or wrong PIN

      final controller = PlayerController(
        adapter: fakeAdapter,
        streamRepository: fakeStreamRepo,
        parentalControlService: fakeParentalService,
      );

      final item = MediaItem(
        id: 'movie_2',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.movie,
        title: 'Locked Movie',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final session = PlayableSession(
        sessionId: 's2',
        streamUrl: 'http://stream.example/2.m3u8',
        mediaItemId: 'movie_2',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        streamType: StreamType.hls,
      );

      await controller.playWithSession(item, session);

      // Gate prompted the user
      expect(fakeParentalService.promptCalls, equals(1));
      // Playback was blocked (adapter never called)
      expect(fakeAdapter.playSessionCount, equals(0));
    });

    test('Playback is ALLOWED when parental lock is active and PIN entry succeeds', () async {
      fakeParentalService.mockIsLocked = true;
      fakeParentalService.mockPromptResult = true; // user entered correct PIN

      final controller = PlayerController(
        adapter: fakeAdapter,
        streamRepository: fakeStreamRepo,
        parentalControlService: fakeParentalService,
      );

      final item = MediaItem(
        id: 'movie_3',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.movie,
        title: 'Unlocked Movie',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final session = PlayableSession(
        sessionId: 's3',
        streamUrl: 'http://stream.example/3.m3u8',
        mediaItemId: 'movie_3',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        streamType: StreamType.hls,
      );

      await controller.playWithSession(item, session);

      expect(fakeParentalService.promptCalls, equals(1));
      expect(fakeAdapter.playSessionCount, equals(1));
    });

    test('playMediaItem gates playback and does not start when PIN is cancelled', () async {
      fakeParentalService.mockIsLocked = true;
      fakeParentalService.mockPromptResult = false; // blocked

      final controller = PlayerController(
        adapter: fakeAdapter,
        streamRepository: fakeStreamRepo,
        parentalControlService: fakeParentalService,
      );

      final item = MediaItem(
        id: 'ch_1',
        providerId: 'p1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'Live TV Channel',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await controller.playMediaItem(item);

      expect(fakeParentalService.promptCalls, equals(1));
      expect(fakeAdapter.playSessionCount, equals(0));
    });

    test('Downloads playback is gated by ParentalControlService', () async {
      Get.put<ParentalControlService>(fakeParentalService);
      fakeParentalService.mockIsLocked = true;
      fakeParentalService.mockPromptResult = false; // blocked

      final downloadsCtrl = DownloadsController(
        repository: _DummyDownloadRepository(),
        service: _DummyDownloadService(),
      );

      final downloadItem = DownloadItem(
        id: 'dl_1',
        mediaItemId: 'm_1',
        title: 'Offline Download',
        mediaType: 'movie',
        sourceUrl: 'http://example.com/1',
        localFilePath: '/data/user/dl_1.mp4',
        totalBytes: 1000,
        downloadedBytes: 1000,
        status: DownloadStatus.completed,
        createdAt: DateTime.now(),
      );

      await downloadsCtrl.playDownload(downloadItem);

      expect(fakeParentalService.promptCalls, equals(1));
    });
  });
}
