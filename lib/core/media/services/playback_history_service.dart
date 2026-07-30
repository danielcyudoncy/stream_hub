import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';

class PlaybackHistoryService {
  final LoggingService logger;
  final List<MediaItem> _recentItems = [];
  final Map<String, Duration> _watchPositions = {};
  final Map<String, double> _completionPercentages = {};

  PlaybackHistoryService({LoggingService? logger})
      : logger = logger ?? LoggingService();

  void recordWatchStart(MediaItem item) {
    _recentItems.removeWhere((i) => i.id == item.id);
    _recentItems.add(item);
    if (_recentItems.length > 100) {
      _recentItems.removeRange(0, _recentItems.length - 100);
    }
    logger.info('Recorded watch start: ${item.title}', tag: 'PlaybackHistory');
  }

  void recordWatchProgress(
    MediaItem item,
    Duration position,
    Duration duration,
  ) {
    _watchPositions[item.id] = position;
    if (duration > Duration.zero) {
      _completionPercentages[item.id] =
          (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    }
  }

  void recordWatchEnd(MediaItem item) {
    _recentItems.removeWhere((i) => i.id == item.id);
    _recentItems.add(item.copyWith(updatedAt: DateTime.now()));
    _completionPercentages[item.id] = 1.0;
    logger.info('Recorded watch end: ${item.title}', tag: 'PlaybackHistory');
  }

  Duration? getSavedPosition(String itemId) {
    return _watchPositions[itemId];
  }

  double? getCompletionPercentage(String itemId) {
    return _completionPercentages[itemId];
  }

  List<MediaItem> getContinueWatching({int limit = 20}) {
    final items = List<MediaItem>.from(_recentItems);
    items.retainWhere(
      (item) => (_completionPercentages[item.id] ?? 0.0) < 0.95,
    );
    items.sort((a, b) {
      final aComp = _completionPercentages[a.id] ?? 0.0;
      final bComp = _completionPercentages[b.id] ?? 0.0;
      if (aComp > 0.0 && bComp == 0.0) return -1;
      if (bComp > 0.0 && aComp == 0.0) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return items.take(limit).toList();
  }

  List<MediaItem> getRecentlyWatched({int limit = 50}) {
    final sorted = List<MediaItem>.from(_recentItems);
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(limit).toList();
  }

  void clearHistory() {
    _recentItems.clear();
    _watchPositions.clear();
    _completionPercentages.clear();
    logger.info('Playback history cleared', tag: 'PlaybackHistory');
  }
}
