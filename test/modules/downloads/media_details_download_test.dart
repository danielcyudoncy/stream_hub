import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/repositories/playback_repository.dart';
import 'package:stream_hub/core/repositories/download_repository.dart';
import 'package:stream_hub/core/services/download_service.dart';
import 'package:stream_hub/data/models/download_item.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playback_session_model.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/modules/movies/movie_details_controller.dart';
import 'package:stream_hub/modules/series/widgets/episode_card.dart';

class _FakeDownloadRepository implements DownloadRepository {
  final Map<String, DownloadItem> storage = {};
  final StreamController<List<DownloadItem>> _controller =
      StreamController<List<DownloadItem>>.broadcast();

  @override
  Future<List<DownloadItem>> getAllDownloads() async => storage.values.toList();

  @override
  Future<DownloadItem?> getDownload(String id) async {
    if (storage.containsKey(id)) return storage[id];
    return storage.values.where((d) => d.mediaItemId == id).firstOrNull;
  }

  @override
  Future<void> saveDownload(DownloadItem item) async {
    storage[item.id] = item;
    _controller.add(storage.values.toList());
  }

  @override
  Future<void> deleteDownload(String id) async {
    storage.remove(id);
    _controller.add(storage.values.toList());
  }

  @override
  Future<void> clearAll() async {
    storage.clear();
    _controller.add([]);
  }

  @override
  Stream<List<DownloadItem>> watchDownloads() => _controller.stream;

  void dispose() {
    _controller.close();
  }
}

class _StubCatalogRepository implements CatalogRepository {
  final List<MediaItem> items;
  _StubCatalogRepository([this.items = const []]);

  @override
  Future<List<MediaItem>> getAllItems() async => items;

  @override
  Future<List<MediaItem>> getByType(MediaType type) async => items;

  @override
  Future<MediaItem?> getItem(String id) async =>
      items.where((i) => i.id == id).firstOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubFavoriteRepository implements FavoriteRepository {
  @override
  Future<bool> isFavorite(String id) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubPlaybackRepository implements PlaybackRepository {
  @override
  Future<Duration?> getWatchProgress(String itemId) async => null;

  @override
  Future<PlaybackSessionModel?> getWatchSession(String itemId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubMediaLibrary implements MediaLibrary {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Media Details Download Wiring Tests', () {
    late _FakeDownloadRepository fakeRepo;
    late DownloadService downloadService;

    setUp(() {
      Get.reset();
      Get.testMode = true;
      fakeRepo = _FakeDownloadRepository();
      downloadService = DownloadService(repository: fakeRepo);
      Get.put<DownloadRepository>(fakeRepo);
      Get.put<DownloadService>(downloadService);
    });

    tearDown(() {
      fakeRepo.dispose();
      Get.reset();
    });

    test('MovieDetailsController triggers download enqueue and tracks state',
        () async {
      final testMovie = MediaItem(
        id: 'movie-download-1',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.movie,
        title: 'Interstellar',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        metadata: {'streamUrl': 'https://example.com/movie.mp4'},
      );

      Get.parameters = {};
      Get.routing.args = testMovie;

      final controller = MovieDetailsController(
        catalogRepository: _StubCatalogRepository([testMovie]),
        favoriteRepository: _StubFavoriteRepository(),
        playbackRepository: _StubPlaybackRepository(),
        mediaLibrary: _StubMediaLibrary(),
      );

      controller.onInit();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.movie, isNotNull);
      expect(controller.movie!.id, 'movie-download-1');
      expect(controller.downloadStatus.value, isNull);

      await controller.downloadMovie();

      final downloads = await fakeRepo.getAllDownloads();
      expect(downloads.length, 1);
      expect(downloads.first.mediaItemId, 'movie-download-1');
      expect(downloads.first.title, 'Interstellar');

      // Emulate download complete
      await fakeRepo.saveDownload(
        downloads.first.copyWith(
          progress: 1.0,
          status: DownloadStatus.completed,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.downloadStatus.value, DownloadStatus.completed);
      expect(controller.downloadProgress.value, 1.0);

      controller.onClose();
    });

    testWidgets('EpisodeCard renders download button and fires onDownload',
        (WidgetTester tester) async {
      bool downloadTapped = false;

      final episode = MediaItem(
        id: 'ep-1',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.series,
        title: 'Pilot Episode',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        metadata: {
          'episode_num': 1,
          'season_num': 1,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeCard(
              episode: episode,
              episodeNumber: '1',
              isDownloaded: false,
              isDownloading: false,
              onTap: () {},
              onDownload: () {
                downloadTapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      expect(find.byIcon(Icons.download_done_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.download_rounded));
      await tester.pump();

      expect(downloadTapped, isTrue);
    });

    testWidgets('EpisodeCard displays completed state when isDownloaded is true',
        (WidgetTester tester) async {
      final episode = MediaItem(
        id: 'ep-2',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.series,
        title: 'Second Episode',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        metadata: {
          'episode_num': 2,
          'season_num': 1,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeCard(
              episode: episode,
              episodeNumber: '2',
              isDownloaded: true,
              isDownloading: false,
              onTap: () {},
              onDownload: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.download_done_rounded), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsNothing);
    });

    testWidgets('EpisodeCard displays downloading state when isDownloading is true',
        (WidgetTester tester) async {
      final episode = MediaItem(
        id: 'ep-3',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.series,
        title: 'Third Episode',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        metadata: {
          'episode_num': 3,
          'season_num': 1,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeCard(
              episode: episode,
              episodeNumber: '3',
              isDownloaded: false,
              isDownloading: true,
              onTap: () {},
              onDownload: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.downloading_rounded), findsOneWidget);
    });
  });
}
