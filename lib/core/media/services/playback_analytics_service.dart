import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/player/playback_analytics.dart';

class PlaybackAnalyticsService {
  final LoggingService logger;
  final List<PlaybackAnalytics> _analytics = [];

  PlaybackAnalyticsService({LoggingService? logger})
      : logger = logger ?? LoggingService();

  void record(PlaybackAnalytics analytics) {
    _analytics.add(analytics);
    if (_analytics.length > 500) {
      _analytics.removeRange(0, _analytics.length - 500);
    }
    logger.info(
      'Analytics recorded: ${analytics.itemId}',
      tag: 'PlaybackAnalytics',
    );
  }

  List<PlaybackAnalytics> getRecent({int limit = 50}) {
    final sorted = List<PlaybackAnalytics>.from(_analytics);
    sorted.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sorted.take(limit).toList();
  }

  Map<String, double> getTotalWatchTimeByProvider() {
    final result = <String, double>{};
    for (final a in _analytics) {
      result[a.providerType] =
          (result[a.providerType] ?? 0.0) + a.totalWatchTime.inSeconds.toDouble();
    }
    return result;
  }

  double getAverageCompletionRate() {
    if (_analytics.isEmpty) return 0.0;
    final total = _analytics
        .map((a) => a.completionPercentage)
        .reduce((a, b) => a + b);
    return total / _analytics.length;
  }

  int get totalSessions => _analytics.length;
  int get totalErrors => _analytics.fold(0, (sum, a) => sum + a.errorCount);

  void clear() {
    _analytics.clear();
    logger.info('Analytics cleared', tag: 'PlaybackAnalytics');
  }
}
