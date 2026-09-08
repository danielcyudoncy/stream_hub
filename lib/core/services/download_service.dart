import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';
import 'package:stream_hub/core/repositories/download_repository.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/prepared_download.dart';
import 'package:stream_hub/data/models/download_item.dart';

/// Internal task tracking an in-flight download.
class _ActiveDownload {
  final String id;
  bool isPaused = false;
  bool isCancelled = false;
  HttpClientRequest? request;
  IOSink? sink;

  _ActiveDownload(this.id);

  void cancel() {
    isCancelled = true;
    try {
      request?.abort();
    } catch (_) {}
    try {
      sink?.close();
    } catch (_) {}
  }

  void pause() {
    isPaused = true;
    try {
      request?.abort();
    } catch (_) {}
    try {
      sink?.close();
    } catch (_) {}
  }
}

/// Service managing offline media downloads, queue processing, and local storage.
class DownloadService extends GetxService {
  final DownloadRepository _repository;
  final LoggingService? _logger;
  final HttpClient _httpClient;
  Directory _downloadsDirectory;
  final int maxConcurrentDownloads;

  final Map<String, _ActiveDownload> _activeDownloads = {};
  bool _isProcessingQueue = false;

  DownloadService({
    required DownloadRepository repository,
    LoggingService? logger,
    HttpClient? httpClient,
    Directory? downloadsDirectory,
    this.maxConcurrentDownloads = 2,
  })  : _repository = repository,
        _logger = logger,
        _httpClient = httpClient ?? createDohAwareHttpClient(),
        _downloadsDirectory = downloadsDirectory ??
            Directory('${Directory.systemTemp.path}/stream_hub_downloads');

  @override
  void onInit() {
    super.onInit();
    _initDirectory();
    _resumeInterruptedDownloads();
  }

  Future<void> _initDirectory() async {
    try {
      if (!_downloadsDirectory.existsSync()) {
        _downloadsDirectory.createSync(recursive: true);
      }
    } catch (e) {
      _log('Failed to create downloads directory, falling back to temp', error: e);
      _downloadsDirectory = Directory.systemTemp;
    }
  }

  void _log(String message, {Object? error}) {
    if (_logger != null) {
      if (error != null) {
        _logger.error(message, tag: 'DownloadService', error: error);
      } else {
        _logger.info(message, tag: 'DownloadService');
      }
    } else if (Get.isRegistered<LoggingService>()) {
      final l = Get.find<LoggingService>();
      if (error != null) {
        l.error(message, tag: 'DownloadService', error: error);
      } else {
        l.info(message, tag: 'DownloadService');
      }
    }
  }

  /// Mark any tasks that were downloading when app closed as paused so user can resume.
  Future<void> _resumeInterruptedDownloads() async {
    try {
      final all = await _repository.getAllDownloads();
      for (final item in all) {
        if (item.status == DownloadStatus.downloading) {
          await _repository.saveDownload(
            item.copyWith(status: DownloadStatus.paused),
          );
        }
      }
    } catch (e) {
      _log('Failed to sanitize interrupted downloads', error: e);
    }
  }

  /// Enqueues a download from a validated [PreparedDownload].
  Future<DownloadItem> enqueue({
    required PreparedDownload preparedDownload,
    required String title,
    String? posterUrl,
    String mediaType = 'vod',
  }) async {
    if (!preparedDownload.canDownload) {
      throw StateError(
        preparedDownload.reason ?? 'Stream does not support offline downloading.',
      );
    }

    final ext = preparedDownload.fileExtension ?? 'mp4';
    final id = 'dl_${DateTime.now().millisecondsSinceEpoch}_${preparedDownload.session.mediaItemId}';
    final localPath = '${_downloadsDirectory.path}/$id.$ext';

    final item = DownloadItem(
      id: id,
      mediaItemId: preparedDownload.session.mediaItemId,
      title: title,
      posterUrl: posterUrl,
      mediaType: mediaType,
      sourceUrl: preparedDownload.session.streamUrl,
      localFilePath: localPath,
      fileExtension: ext,
      status: DownloadStatus.queued,
      createdAt: DateTime.now(),
      totalBytes: preparedDownload.expectedSizeBytes ?? 0,
      metadata: {
        'providerId': preparedDownload.session.providerId,
        'headers': preparedDownload.session.headers,
        'cookies': preparedDownload.session.cookies,
      },
    );

    await _repository.saveDownload(item);
    _log('Enqueued download for ${item.title} ($id)');
    _processQueue();
    return item;
  }

  /// Enqueues a download directly from a [PlayableSession].
  Future<DownloadItem> enqueueSession({
    required PlayableSession session,
    required String title,
    String? posterUrl,
    String mediaType = 'vod',
  }) async {
    final prepared = PreparedDownload(
      session: session,
      canDownload: session.supportsDownload,
      fileExtension: _extensionFromType(session.streamType),
      reason: session.supportsDownload ? null : 'Downloads not supported for this session',
    );
    return enqueue(
      preparedDownload: prepared,
      title: title,
      posterUrl: posterUrl,
      mediaType: mediaType,
    );
  }

  String _extensionFromType(StreamType type) {
    switch (type) {
      case StreamType.mp4:
        return 'mp4';
      case StreamType.mkv:
        return 'mkv';
      case StreamType.hls:
      case StreamType.httpLive:
      case StreamType.httpsLive:
        return 'm3u8';
      case StreamType.dash:
        return 'mpd';
      case StreamType.mpegTs:
        return 'ts';
      default:
        return 'mp4';
    }
  }

  /// Pause an ongoing download.
  Future<void> pauseDownload(String id) async {
    final active = _activeDownloads[id];
    if (active != null) {
      active.pause();
      _activeDownloads.remove(id);
    }
    final item = await _repository.getDownload(id);
    if (item != null) {
      await _repository.saveDownload(
        item.copyWith(
          status: DownloadStatus.paused,
          speedBytesPerSecond: 0,
        ),
      );
    }
    _processQueue();
  }

  /// Resume a paused or failed download.
  Future<void> resumeDownload(String id) async {
    final item = await _repository.getDownload(id);
    if (item != null) {
      await _repository.saveDownload(
        item.copyWith(
          status: DownloadStatus.queued,
          error: null,
        ),
      );
      _processQueue();
    }
  }

  /// Cancel an active or queued download.
  Future<void> cancelDownload(String id) async {
    final active = _activeDownloads[id];
    if (active != null) {
      active.cancel();
      _activeDownloads.remove(id);
    }
    final item = await _repository.getDownload(id);
    if (item != null) {
      // Remove partially downloaded file
      try {
        final file = File(item.localFilePath);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}

      await _repository.saveDownload(
        item.copyWith(
          status: DownloadStatus.cancelled,
          progress: 0.0,
          downloadedBytes: 0,
          speedBytesPerSecond: 0,
        ),
      );
    }
    _processQueue();
  }

  /// Delete a download and remove its local file from disk.
  Future<void> deleteDownload(String id) async {
    final active = _activeDownloads[id];
    if (active != null) {
      active.cancel();
      _activeDownloads.remove(id);
    }
    final item = await _repository.getDownload(id);
    if (item != null) {
      try {
        final file = File(item.localFilePath);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        _log('Failed to delete file for download: $id', error: e);
      }
      await _repository.deleteDownload(id);
    }
    _processQueue();
  }

  /// Retry a failed download.
  Future<void> retryDownload(String id) async {
    await resumeDownload(id);
  }

  /// Calculates total bytes used by all completed or partial downloads.
  Future<int> getTotalStorageUsed() async {
    try {
      final all = await _repository.getAllDownloads();
      var total = 0;
      for (final item in all) {
        if (item.status == DownloadStatus.completed) {
          final file = File(item.localFilePath);
          if (file.existsSync()) {
            total += file.lengthSync();
          } else {
            total += item.downloadedBytes;
          }
        } else if (item.status == DownloadStatus.downloading ||
            item.status == DownloadStatus.paused) {
          total += item.downloadedBytes;
        }
      }
      return total;
    } catch (e) {
      _log('Failed to calculate storage used', error: e);
      return 0;
    }
  }

  /// Creates a [PlayableSession] from a completed download for offline playback.
  PlayableSession createOfflineSession(DownloadItem item) {
    StreamType streamType;
    switch (item.fileExtension.toLowerCase()) {
      case 'mp4':
        streamType = StreamType.mp4;
        break;
      case 'mkv':
        streamType = StreamType.mkv;
        break;
      case 'm3u8':
        streamType = StreamType.hls;
        break;
      case 'ts':
        streamType = StreamType.mpegTs;
        break;
      default:
        streamType = StreamType.mp4;
    }

    return PlayableSession(
      sessionId: 'offline_${item.id}',
      mediaItemId: item.mediaItemId,
      providerId: 'local_storage',
      providerType: MediaSourceType.xtream,
      streamUrl: item.localFilePath,
      headers: const {},
      cookies: const {},
      streamType: streamType,
      supportsSeeking: true,
      supportsPause: true,
      supportsPiP: true,
      supportsDownload: false,
      supportsCatchup: false,
      supportsTimeshift: false,
      metadata: {
        'title': item.title,
        'posterUrl': item.posterUrl,
        'isOffline': true,
        'mediaType': item.mediaType,
      },
    );
  }

  /// Internal queue runner.
  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      if (_activeDownloads.length >= maxConcurrentDownloads) return;

      final all = await _repository.getAllDownloads();
      final queued = all.where((d) => d.status == DownloadStatus.queued).toList();

      for (final item in queued) {
        if (_activeDownloads.length >= maxConcurrentDownloads) break;
        if (!_activeDownloads.containsKey(item.id)) {
          _startDownloadTask(item);
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  void _startDownloadTask(DownloadItem item) async {
    final active = _ActiveDownload(item.id);
    _activeDownloads[item.id] = active;

    await _repository.saveDownload(
      item.copyWith(status: DownloadStatus.downloading),
    );

    try {
      final file = File(item.localFilePath);
      final existingBytes = await file.exists() ? await file.length() : 0;

      final uri = Uri.parse(item.sourceUrl);
      final request = await _httpClient.getUrl(uri);
      active.request = request;

      // Apply headers and cookies from metadata
      final headers = item.metadata['headers'];
      if (headers is Map) {
        headers.forEach((k, v) {
          if (k.toString().toLowerCase() != 'range') {
            request.headers.set(k.toString(), v.toString());
          }
        });
      }

      // Resume support via HTTP Range header
      if (existingBytes > 0) {
        request.headers.set('Range', 'bytes=$existingBytes-');
      }

      final response = await request.close();
      if (active.isCancelled || active.isPaused) return;

      var totalBytes = response.contentLength;
      if (totalBytes != -1 && existingBytes > 0) {
        totalBytes += existingBytes;
      } else if (totalBytes == -1 && item.totalBytes > 0) {
        totalBytes = item.totalBytes;
      }

      // Append or create new file
      final sink = file.openWrite(
        mode: (existingBytes > 0 && response.statusCode == HttpStatus.partialContent)
            ? FileMode.append
            : FileMode.write,
      );
      active.sink = sink;

      var currentDownloaded = (response.statusCode == HttpStatus.partialContent)
          ? existingBytes
          : 0;

      var lastReportTime = DateTime.now();
      var bytesSinceLastReport = 0;
      var lastSpeed = 0.0;

      await for (final chunk in response) {
        if (active.isCancelled || active.isPaused) {
          await sink.flush();
          await sink.close();
          return;
        }

        sink.add(chunk);
        currentDownloaded += chunk.length;
        bytesSinceLastReport += chunk.length;

        final now = DateTime.now();
        final elapsed = now.difference(lastReportTime);
        if (elapsed.inMilliseconds >= 600) {
          lastSpeed = (bytesSinceLastReport / (elapsed.inMilliseconds / 1000.0));
          final progress = totalBytes > 0
              ? (currentDownloaded / totalBytes).clamp(0.0, 1.0)
              : 0.0;

          await _repository.saveDownload(
            item.copyWith(
              status: DownloadStatus.downloading,
              downloadedBytes: currentDownloaded,
              totalBytes: totalBytes > 0 ? totalBytes : currentDownloaded,
              progress: progress,
              speedBytesPerSecond: lastSpeed,
            ),
          );

          lastReportTime = now;
          bytesSinceLastReport = 0;
        }
      }

      await sink.flush();
      await sink.close();

      if (!active.isCancelled && !active.isPaused) {
        await _repository.saveDownload(
          item.copyWith(
            status: DownloadStatus.completed,
            downloadedBytes: currentDownloaded,
            totalBytes: currentDownloaded,
            progress: 1.0,
            speedBytesPerSecond: 0,
            completedAt: DateTime.now(),
          ),
        );
        _log('Download completed for ${item.title} ($currentDownloaded bytes)');
      }
    } catch (e) {
      if (!active.isCancelled && !active.isPaused) {
        _log('Download error for ${item.title}', error: e);
        await _repository.saveDownload(
          item.copyWith(
            status: DownloadStatus.failed,
            error: e.toString(),
            speedBytesPerSecond: 0,
          ),
        );
      }
    } finally {
      _activeDownloads.remove(item.id);
      _processQueue();
    }
  }

  @override
  void onClose() {
    for (final task in _activeDownloads.values) {
      task.cancel();
    }
    _activeDownloads.clear();
    _httpClient.close(force: true);
    super.onClose();
  }
}
