import 'package:flutter/foundation.dart';

/// Status of a download task.
enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

/// Represents a media item downloaded or being downloaded for offline playback.
@immutable
class DownloadItem {
  final String id;
  final String mediaItemId;
  final String title;
  final String? posterUrl;
  final String mediaType; // 'movie', 'series', 'vod', 'episode'
  final String sourceUrl;
  final String localFilePath;
  final String fileExtension;
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0
  final int downloadedBytes;
  final int totalBytes;
  final double speedBytesPerSecond;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? error;
  final Map<String, dynamic> metadata;

  const DownloadItem({
    required this.id,
    required this.mediaItemId,
    required this.title,
    this.posterUrl,
    this.mediaType = 'vod',
    required this.sourceUrl,
    required this.localFilePath,
    this.fileExtension = 'mp4',
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.speedBytesPerSecond = 0.0,
    required this.createdAt,
    this.completedAt,
    this.error,
    this.metadata = const {},
  });

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isPaused => status == DownloadStatus.paused;
  bool get isFailed => status == DownloadStatus.failed;
  bool get isQueued => status == DownloadStatus.queued;
  bool get isCancelled => status == DownloadStatus.cancelled;

  DownloadItem copyWith({
    String? id,
    String? mediaItemId,
    String? title,
    String? posterUrl,
    String? mediaType,
    String? sourceUrl,
    String? localFilePath,
    String? fileExtension,
    DownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    double? speedBytesPerSecond,
    DateTime? createdAt,
    DateTime? completedAt,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      mediaItemId: mediaItemId ?? this.mediaItemId,
      title: title ?? this.title,
      posterUrl: posterUrl ?? this.posterUrl,
      mediaType: mediaType ?? this.mediaType,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      localFilePath: localFilePath ?? this.localFilePath,
      fileExtension: fileExtension ?? this.fileExtension,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mediaItemId': mediaItemId,
      'title': title,
      'posterUrl': posterUrl,
      'mediaType': mediaType,
      'sourceUrl': sourceUrl,
      'localFilePath': localFilePath,
      'fileExtension': fileExtension,
      'status': status.name,
      'progress': progress,
      'downloadedBytes': downloadedBytes,
      'totalBytes': totalBytes,
      'speedBytesPerSecond': speedBytesPerSecond,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'error': error,
      'metadata': metadata,
    };
  }

  factory DownloadItem.fromMap(Map<dynamic, dynamic> map) {
    return DownloadItem(
      id: map['id'] as String? ?? '',
      mediaItemId: map['mediaItemId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      posterUrl: map['posterUrl'] as String?,
      mediaType: map['mediaType'] as String? ?? 'vod',
      sourceUrl: map['sourceUrl'] as String? ?? '',
      localFilePath: map['localFilePath'] as String? ?? '',
      fileExtension: map['fileExtension'] as String? ?? 'mp4',
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => DownloadStatus.queued,
      ),
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      speedBytesPerSecond: (map['speedBytesPerSecond'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'] as String)
          : null,
      error: map['error'] as String?,
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : const {},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          status == other.status &&
          downloadedBytes == other.downloadedBytes;

  @override
  int get hashCode => id.hashCode ^ status.hashCode ^ downloadedBytes.hashCode;
}
