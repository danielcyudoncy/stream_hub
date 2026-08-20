import 'package:stream_hub/data/models/media_item.dart';

/// Represents primary watch action status for a Series.
enum SeriesWatchActionType {
  playFirst,
  resume,
  playNext,
  watchAgain,
}

/// Represents the calculated watch progress for an entire Series.
class SeriesProgress {
  final String seriesId;
  final int completedEpisodes;
  final int totalAvailableEpisodes;
  final MediaItem? currentEpisode;
  final Duration currentPosition;
  final Duration currentDuration;
  final double overallPercentage;
  final bool isCompleted;
  final SeriesWatchActionType actionType;
  final MediaItem? nextEpisodeToWatch;

  const SeriesProgress({
    required this.seriesId,
    required this.completedEpisodes,
    required this.totalAvailableEpisodes,
    this.currentEpisode,
    this.currentPosition = Duration.zero,
    this.currentDuration = Duration.zero,
    this.overallPercentage = 0.0,
    this.isCompleted = false,
    this.actionType = SeriesWatchActionType.playFirst,
    this.nextEpisodeToWatch,
  });

  String get actionLabel {
    switch (actionType) {
      case SeriesWatchActionType.playFirst:
        final ep = nextEpisodeToWatch ?? currentEpisode;
        if (ep != null) {
          final sNum = ep.metadata['seasonNumber'] ?? ep.metadata['seasonId'];
          final eNum = ep.metadata['episodeNumber'] ?? ep.metadata['streamId'];
          if (sNum != null && eNum != null) {
            final sStr = sNum.toString().padLeft(2, '0');
            final eStr = eNum.toString().padLeft(2, '0');
            return 'Play S${sStr}E$eStr';
          }
        }
        return 'Play First Episode';
      case SeriesWatchActionType.resume:
        final ep = currentEpisode;
        if (ep != null) {
          final sNum = ep.metadata['seasonNumber'] ?? ep.metadata['seasonId'];
          final eNum = ep.metadata['episodeNumber'] ?? ep.metadata['streamId'];
          final sStr = sNum != null ? sNum.toString().padLeft(2, '0') : '01';
          final eStr = eNum != null ? eNum.toString().padLeft(2, '0') : '01';
          if (currentPosition > Duration.zero) {
            final mins = currentPosition.inMinutes;
            final secs = (currentPosition.inSeconds % 60).toString().padLeft(2, '0');
            return 'Resume S${sStr}E$eStr ($mins:$secs)';
          }
          return 'Resume S${sStr}E$eStr';
        }
        return 'Resume';
      case SeriesWatchActionType.playNext:
        final ep = nextEpisodeToWatch;
        if (ep != null) {
          final sNum = ep.metadata['seasonNumber'] ?? ep.metadata['seasonId'];
          final eNum = ep.metadata['episodeNumber'] ?? ep.metadata['streamId'];
          if (sNum != null && eNum != null) {
            final sStr = sNum.toString().padLeft(2, '0');
            final eStr = eNum.toString().padLeft(2, '0');
            return 'Next: S${sStr}E$eStr';
          }
        }
        return 'Next Episode';
      case SeriesWatchActionType.watchAgain:
        return 'Watch Again';
    }
  }

  String? get summaryText {
    if (actionType == SeriesWatchActionType.resume &&
        currentDuration > currentPosition &&
        currentPosition > Duration.zero) {
      final remaining = currentDuration - currentPosition;
      final mins = remaining.inMinutes;
      if (mins > 60) {
        final hours = remaining.inHours;
        final m = mins % 60;
        return '${hours}h ${m}m left';
      }
      return '${mins}m left';
    }
    return null;
  }

  String get summaryLabel {
    if (totalAvailableEpisodes <= 0) return '0 Episodes';
    if (completedEpisodes == totalAvailableEpisodes) {
      return 'Completed ($totalAvailableEpisodes ${totalAvailableEpisodes == 1 ? 'ep' : 'eps'})';
    }
    if (completedEpisodes > 0) {
      return '$completedEpisodes of $totalAvailableEpisodes watched';
    }
    return '$totalAvailableEpisodes ${totalAvailableEpisodes == 1 ? 'episode' : 'episodes'}';
  }
}

