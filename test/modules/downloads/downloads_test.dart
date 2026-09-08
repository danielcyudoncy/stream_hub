import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/repositories/download_repository.dart';
import 'package:stream_hub/core/services/download_service.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/prepared_download.dart';
import 'package:stream_hub/data/models/download_item.dart';
import 'package:stream_hub/modules/downloads/controllers/downloads_controller.dart';
import 'package:stream_hub/modules/downloads/pages/downloads_page.dart';

class _FakeDownloadRepository implements DownloadRepository {
  final Map<String, DownloadItem> storage = {};
  final StreamController<List<DownloadItem>> _controller =
      StreamController<List<DownloadItem>>.broadcast();

  @override
  Future<List<DownloadItem>> getAllDownloads() async {
    final list = storage.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<DownloadItem?> getDownload(String id) async => storage[id];

  @override
  Future<void> saveDownload(DownloadItem item) async {
    storage[item.id] = item;
    _controller.add(await getAllDownloads());
  }

  @override
  Future<void> deleteDownload(String id) async {
    storage.remove(id);
    _controller.add(await getAllDownloads());
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadItem Model', () {
    test('serializes to and from Map correctly', () {
      final now = DateTime.now();
      final item = DownloadItem(
        id: 'dl_123',
        mediaItemId: 'item_456',
        title: 'Big Buck Bunny',
        posterUrl: 'https://example.com/poster.jpg',
        mediaType: 'movie',
        sourceUrl: 'https://example.com/video.mp4',
        localFilePath: '/tmp/video.mp4',
        fileExtension: 'mp4',
        status: DownloadStatus.downloading,
        progress: 0.45,
        downloadedBytes: 4500000,
        totalBytes: 10000000,
        speedBytesPerSecond: 1024000,
        createdAt: now,
        metadata: {'author': 'Blender Foundation'},
      );

      final map = item.toMap();
      final restored = DownloadItem.fromMap(map);

      expect(restored.id, 'dl_123');
      expect(restored.mediaItemId, 'item_456');
      expect(restored.title, 'Big Buck Bunny');
      expect(restored.posterUrl, 'https://example.com/poster.jpg');
      expect(restored.mediaType, 'movie');
      expect(restored.sourceUrl, 'https://example.com/video.mp4');
      expect(restored.localFilePath, '/tmp/video.mp4');
      expect(restored.fileExtension, 'mp4');
      expect(restored.status, DownloadStatus.downloading);
      expect(restored.progress, 0.45);
      expect(restored.downloadedBytes, 4500000);
      expect(restored.totalBytes, 10000000);
      expect(restored.speedBytesPerSecond, 1024000);
      expect(restored.isDownloading, isTrue);
      expect(restored.isCompleted, isFalse);
      expect(restored.metadata['author'], 'Blender Foundation');
    });

    test('copyWith updates specific fields properly', () {
      final item = DownloadItem(
        id: '1',
        mediaItemId: 'm1',
        title: 'Title',
        sourceUrl: 'url',
        localFilePath: 'path',
        createdAt: DateTime.now(),
      );

      final updated = item.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        downloadedBytes: 5000,
      );

      expect(updated.id, '1');
      expect(updated.status, DownloadStatus.completed);
      expect(updated.progress, 1.0);
      expect(updated.downloadedBytes, 5000);
      expect(updated.isCompleted, isTrue);
    });
  });

  group('DownloadService', () {
    late _FakeDownloadRepository repo;
    late Directory tempDir;
    late DownloadService service;

    setUp(() async {
      repo = _FakeDownloadRepository();
      tempDir = await Directory.systemTemp.createTemp('stream_hub_test_dl_');
      service = DownloadService(
        repository: repo,
        downloadsDirectory: tempDir,
      );
    });

    tearDown(() async {
      service.onClose();
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('enqueues a PreparedDownload successfully', () async {
      final session = PlayableSession(
        sessionId: 'test_s1',
        mediaItemId: 'm100',
        providerId: 'provider_1',
        providerType: MediaSourceType.xtream,
        streamUrl: 'https://example.com/stream.mp4',
        headers: {'User-Agent': 'StreamHub'},
        cookies: {},
        streamType: StreamType.mp4,
        supportsDownload: true,
        metadata: {'title': 'Sample Movie'},
      );

      final prepared = PreparedDownload(
        session: session,
        canDownload: true,
        fileExtension: 'mp4',
        expectedSizeBytes: 5000000,
      );

      final item = await service.enqueue(
        preparedDownload: prepared,
        title: 'Sample Movie',
        posterUrl: 'https://example.com/poster.png',
      );

      expect(item.mediaItemId, 'm100');
      expect(item.title, 'Sample Movie');
      expect(item.posterUrl, 'https://example.com/poster.png');
      expect(item.fileExtension, 'mp4');
      expect(item.totalBytes, 5000000);

      final saved = await repo.getDownload(item.id);
      expect(saved, isNotNull);
      expect(saved!.mediaItemId, 'm100');
    });

    test('rejects enqueuing when session does not support downloads', () async {
      final session = PlayableSession(
        sessionId: 'test_s2',
        mediaItemId: 'live_1',
        providerId: 'p1',
        providerType: MediaSourceType.m3u,
        streamUrl: 'https://example.com/live.m3u8',
        headers: {},
        cookies: {},
        streamType: StreamType.hls,
        supportsDownload: false,
        metadata: {},
      );

      final prepared = PreparedDownload(
        session: session,
        canDownload: false,
        reason: 'Live streams cannot be downloaded',
      );

      expect(
        () => service.enqueue(
          preparedDownload: prepared,
          title: 'Live News',
        ),
        throwsStateError,
      );
    });

    test('creates offline PlayableSession from completed DownloadItem', () {
      final item = DownloadItem(
        id: 'dl_offline_1',
        mediaItemId: 'movie_42',
        title: 'Offline Action',
        posterUrl: 'https://example.com/art.jpg',
        mediaType: 'movie',
        sourceUrl: 'https://remote.com/movie.mp4',
        localFilePath: '/storage/emulated/0/stream_hub/dl_offline_1.mp4',
        fileExtension: 'mp4',
        status: DownloadStatus.completed,
        progress: 1.0,
        downloadedBytes: 1500000,
        totalBytes: 1500000,
        createdAt: DateTime.now(),
      );

      final session = service.createOfflineSession(item);

      expect(session.mediaItemId, 'movie_42');
      expect(session.streamUrl, '/storage/emulated/0/stream_hub/dl_offline_1.mp4');
      expect(session.providerId, 'local_storage');
      expect(session.streamType, StreamType.mp4);
      expect(session.supportsSeeking, isTrue);
      expect(session.supportsPause, isTrue);
      expect(session.metadata['isOffline'], isTrue);
      expect(session.metadata['title'], 'Offline Action');
    });

    test('pause, resume, and cancel update download status correctly', () async {
      final item = DownloadItem(
        id: 'task_1',
        mediaItemId: 'm1',
        title: 'Title',
        sourceUrl: 'https://example.com/video.mp4',
        localFilePath: '${tempDir.path}/task_1.mp4',
        status: DownloadStatus.downloading,
        downloadedBytes: 200,
        totalBytes: 1000,
        createdAt: DateTime.now(),
      );
      await repo.saveDownload(item);

      await service.pauseDownload('task_1');
      var updated = await repo.getDownload('task_1');
      expect(updated?.status, DownloadStatus.paused);

      await service.resumeDownload('task_1');
      updated = await repo.getDownload('task_1');
      expect(updated?.status, DownloadStatus.queued);

      await service.cancelDownload('task_1');
      updated = await repo.getDownload('task_1');
      expect(updated?.status, DownloadStatus.cancelled);
    });
  });

  group('DownloadsController', () {
    late _FakeDownloadRepository repo;
    late DownloadService service;
    late DownloadsController controller;
    late Directory tempDir;

    setUp(() async {
      repo = _FakeDownloadRepository();
      tempDir = await Directory.systemTemp.createTemp('stream_hub_test_ctrl_');
      service = DownloadService(
        repository: repo,
        downloadsDirectory: tempDir,
      );

      // Seed initial data
      await repo.saveDownload(DownloadItem(
        id: '1',
        mediaItemId: 'item1',
        title: 'Movie 1',
        sourceUrl: 'url1',
        localFilePath: '${tempDir.path}/1.mp4',
        status: DownloadStatus.completed,
        progress: 1.0,
        downloadedBytes: 1024 * 1024 * 50, // 50MB
        totalBytes: 1024 * 1024 * 50,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ));

      await repo.saveDownload(DownloadItem(
        id: '2',
        mediaItemId: 'item2',
        title: 'Movie 2',
        sourceUrl: 'url2',
        localFilePath: '${tempDir.path}/2.mp4',
        status: DownloadStatus.downloading,
        progress: 0.3,
        downloadedBytes: 1024 * 1024 * 15,
        totalBytes: 1024 * 1024 * 50,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ));

      await repo.saveDownload(DownloadItem(
        id: '3',
        mediaItemId: 'item3',
        title: 'Movie 3',
        sourceUrl: 'url3',
        localFilePath: '${tempDir.path}/3.mp4',
        status: DownloadStatus.paused,
        progress: 0.6,
        downloadedBytes: 1024 * 1024 * 30,
        totalBytes: 1024 * 1024 * 50,
        createdAt: DateTime.now(),
      ));

      controller = DownloadsController(
        repository: repo,
        service: service,
      );
      await controller.loadDownloads();
    });

    tearDown(() async {
      service.onClose();
      controller.onClose();
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('loads downloads and calculates counts', () {
      expect(controller.downloads.length, 3);
      expect(controller.completedCount, 1);
      expect(controller.activeCount, 2); // 1 downloading + 1 paused
    });

    test('filters list based on selected filter', () {
      controller.setFilter(DownloadFilter.all);
      expect(controller.filteredDownloads.length, 3);

      controller.setFilter(DownloadFilter.completed);
      expect(controller.filteredDownloads.length, 1);
      expect(controller.filteredDownloads.first.id, '1');

      controller.setFilter(DownloadFilter.active);
      expect(controller.filteredDownloads.length, 2);
      expect(controller.filteredDownloads.map((e) => e.id), containsAll(['2', '3']));
    });

    test('formats byte sizes cleanly', () {
      expect(controller.formatBytes(0), '0 B');
      expect(controller.formatBytes(500), '500 B');
      expect(controller.formatBytes(1024), '1.0 KB');
      expect(controller.formatBytes(1024 * 1024 * 15), '15.0 MB');
      expect(controller.formatBytes(1024 * 1024 * 1024 * 2), '2.0 GB');
    });

    test('formats speeds cleanly', () {
      expect(controller.formatSpeed(0), '0 KB/s');
      expect(controller.formatSpeed(512 * 1024), '512 KB/s');
      expect(controller.formatSpeed(2.5 * 1024 * 1024), '2.5 MB/s');
    });

    test('deleteDownload removes item from list', () async {
      await controller.deleteDownload('2');
      expect(controller.downloads.length, 2);
      expect(controller.downloads.any((d) => d.id == '2'), isFalse);
    });

    test('clearAll removes all items', () async {
      await controller.clearAll();
      expect(controller.downloads.isEmpty, isTrue);
      expect(controller.completedCount, 0);
      expect(controller.activeCount, 0);
    });
  });

  group('DownloadsPage Widget', () {
    late _FakeDownloadRepository repo;
    late DownloadService service;
    late DownloadsController controller;
    late Directory tempDir;

    setUp(() async {
      Get.reset();
      repo = _FakeDownloadRepository();
      tempDir = await Directory.systemTemp.createTemp('stream_hub_test_page_');
      service = DownloadService(
        repository: repo,
        downloadsDirectory: tempDir,
      );
      controller = DownloadsController(
        repository: repo,
        service: service,
      );
      Get.put<DownloadsController>(controller);
    });

    tearDown(() async {
      service.onClose();
      repo.dispose();
      Get.reset();
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    testWidgets('renders empty state when no downloads exist', (tester) async {
      await controller.loadDownloads();
      await tester.pumpWidget(
        const GetMaterialApp(
          home: DownloadsPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('Offline Storage Used'), findsOneWidget);
      expect(find.text('No Downloads'), findsOneWidget);
      expect(find.text('All (0)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('renders items and responds to filter chips', (tester) async {
      await repo.saveDownload(DownloadItem(
        id: '1',
        mediaItemId: 'm1',
        title: 'Cyberpunk Edgerunners',
        sourceUrl: 'https://example.com/stream.mp4',
        localFilePath: '${tempDir.path}/1.mp4',
        status: DownloadStatus.completed,
        progress: 1.0,
        downloadedBytes: 1024 * 1024 * 350,
        totalBytes: 1024 * 1024 * 350,
        createdAt: DateTime.now(),
      ));
      await controller.loadDownloads();

      await tester.pumpWidget(
        const GetMaterialApp(
          home: DownloadsPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Cyberpunk Edgerunners'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('All (1)'), findsOneWidget);
      expect(find.text('Completed (1)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
