import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/repositories/download_repository.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/core/services/download_service.dart';
import 'package:stream_hub/core/services/parental_control_service.dart';
import 'package:stream_hub/data/models/download_item.dart';
import 'package:stream_hub/data/models/media_item.dart';

enum DownloadFilter {
  all,
  active,
  completed,
}

class DownloadsController extends GetxController {
  final DownloadRepository _repository;
  final DownloadService _service;

  final RxList<DownloadItem> downloads = <DownloadItem>[].obs;
  final Rx<DownloadFilter> selectedFilter = DownloadFilter.all.obs;
  final RxInt storageUsedBytes = 0.obs;
  final RxBool isLoading = false.obs;

  StreamSubscription<List<DownloadItem>>? _subscription;

  DownloadsController({
    required DownloadRepository repository,
    required DownloadService service,
  })  : _repository = repository,
        _service = service;

  @override
  void onInit() {
    super.onInit();
    _subscribe();
    loadDownloads();
  }

  void _subscribe() {
    _subscription = _repository.watchDownloads().listen((items) {
      downloads.assignAll(items);
      _updateStorageUsed();
    });
  }

  Future<void> loadDownloads() async {
    isLoading.value = true;
    try {
      final items = await _repository.getAllDownloads();
      downloads.assignAll(items);
      await _updateStorageUsed();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _updateStorageUsed() async {
    final used = await _service.getTotalStorageUsed();
    storageUsedBytes.value = used;
  }

  List<DownloadItem> get filteredDownloads {
    switch (selectedFilter.value) {
      case DownloadFilter.active:
        return downloads
            .where((d) =>
                d.status == DownloadStatus.downloading ||
                d.status == DownloadStatus.queued ||
                d.status == DownloadStatus.paused)
            .toList();
      case DownloadFilter.completed:
        return downloads
            .where((d) => d.status == DownloadStatus.completed)
            .toList();
      case DownloadFilter.all:
        return downloads;
    }
  }

  int get activeCount => downloads
      .where((d) =>
          d.status == DownloadStatus.downloading ||
          d.status == DownloadStatus.queued ||
          d.status == DownloadStatus.paused)
      .length;

  int get completedCount =>
      downloads.where((d) => d.status == DownloadStatus.completed).length;

  void setFilter(DownloadFilter filter) {
    selectedFilter.value = filter;
  }

  Future<void> pauseDownload(String id) async {
    await _service.pauseDownload(id);
    await loadDownloads();
  }

  Future<void> resumeDownload(String id) async {
    await _service.resumeDownload(id);
    await loadDownloads();
  }

  Future<void> cancelDownload(String id) async {
    await _service.cancelDownload(id);
    await loadDownloads();
  }

  Future<void> deleteDownload(String id) async {
    await _service.deleteDownload(id);
    await loadDownloads();
  }

  Future<void> retryDownload(String id) async {
    await _service.retryDownload(id);
    await loadDownloads();
  }

  Future<void> clearAll() async {
    for (final item in downloads.toList()) {
      await _service.deleteDownload(item.id);
    }
    await _repository.clearAll();
    await loadDownloads();
  }

  Future<void> playDownload(DownloadItem item) async {
    if (!item.isCompleted) return;

    final parentalService = Get.isRegistered<ParentalControlService>()
        ? Get.find<ParentalControlService>()
        : null;
    if (parentalService != null && parentalService.isLocked) {
      final unlocked = await parentalService.promptPinUnlock(
        title: 'Parental Lock',
        message: 'Enter PIN to play downloaded content "${item.title}".',
      );
      if (!unlocked) return;
    }

    final mediaItem = MediaItem(
      id: item.mediaItemId,
      providerId: 'local_storage',
      providerType: MediaSourceType.xtream,
      mediaType: item.mediaType == 'series' ? MediaType.series : MediaType.movie,
      title: item.title,
      poster: item.posterUrl,
      createdAt: item.createdAt,
      updatedAt: DateTime.now(),
      metadata: {'isOffline': true, 'localFilePath': item.localFilePath},
    );

    Get.toNamed(
      AppRoutes.fullscreenPlayer,
      arguments: {
        'items': [mediaItem],
        'currentId': mediaItem.id,
        'itemId': mediaItem.id,
        'streamUrl': item.localFilePath,
      },
    );
  }

  String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i > 0 ? 1 : 0)} ${suffixes[i]}';
  }

  String formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '0 KB/s';
    if (bytesPerSec >= 1024 * 1024) {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
