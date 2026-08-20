import 'package:stream_hub/core/streaming/series/next_episode_resolver.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playback_session_model.dart';
import 'package:stream_hub/data/models/series_progress.dart';

/// Calculates overall series watch progress and determines the primary action.
class SeriesProgressService {
  /// Default threshold (percentage 0.0 to 1.0) above which an episode is considered completed.
  final double completionThreshold;
  final NextEpisodeResolver resolver;

  const SeriesProgressService({
    this.completionThreshold = 0.90,
    this.resolver = const NextEpisodeResolver(),
  });

  /// Computes the complete [SeriesProgress] for a series given its [seasons] and the user's
  /// [watchSessions] map (keyed by episode item ID).
  SeriesProgress computeProgress({
    required MediaItem series,
    required List<SeasonGroup> seasons,
    required Map<String, PlaybackSessionModel> watchSessions,
  }) {
    if (seasons.isEmpty) {
      return SeriesProgress(
        seriesId: series.id,
        completedEpisodes: 0,
        totalAvailableEpisodes: 0,
        actionType: SeriesWatchActionType.playFirst,
      );
    }

    final sortedSeasons = resolver.normalizeAndSortSeasons(seasons);
    final allEpisodes = sortedSeasons.expand((s) => s.episodes).toList();
    final totalEpisodes = allEpisodes.length;

    if (totalEpisodes == 0) {
      return SeriesProgress(
        seriesId: series.id,
        completedEpisodes: 0,
        totalAvailableEpisodes: 0,
        actionType: SeriesWatchActionType.playFirst,
      );
    }

    final firstEpisode = allEpisodes.first;

    // Track completed, in-progress, and un-started episodes
    final completedEpisodeIds = <String>{};
    MediaItem? partiallyWatchedEpisode;
    PlaybackSessionModel? partiallyWatchedSession;
    DateTime? latestPartiallyWatchedTime;

    MediaItem? latestCompletedEpisode;
    DateTime? latestCompletedTime;

    for (final episode in allEpisodes) {
      final session = watchSessions[episode.id];
      if (session == null) continue;

      if (session.completionPercentage >= completionThreshold) {
        completedEpisodeIds.add(episode.id);
        if (latestCompletedTime == null || session.updatedAt.isAfter(latestCompletedTime)) {
          latestCompletedTime = session.updatedAt;
          latestCompletedEpisode = episode;
        }
      } else if (session.completionPercentage > 0.02) {
        // Partially watched episode
        if (latestPartiallyWatchedTime == null || session.updatedAt.isAfter(latestPartiallyWatchedTime)) {
          latestPartiallyWatchedTime = session.updatedAt;
          partiallyWatchedEpisode = episode;
          partiallyWatchedSession = session;
        }
      }
    }

    final completedCount = completedEpisodeIds.length;
    final isAllCompleted = completedCount >= totalEpisodes && totalEpisodes > 0;

    // Calculate overall percentage
    double partialContribution = 0.0;
    if (partiallyWatchedSession != null && totalEpisodes > 0) {
      partialContribution = (partiallyWatchedSession.completionPercentage / totalEpisodes);
    }
    final overallPercentage = totalEpisodes > 0
        ? ((completedCount / totalEpisodes) + partialContribution).clamp(0.0, 1.0)
        : 0.0;

    // 1. If all available episodes are completed -> Watch Again
    if (isAllCompleted) {
      return SeriesProgress(
        seriesId: series.id,
        completedEpisodes: completedCount,
        totalAvailableEpisodes: totalEpisodes,
        currentEpisode: firstEpisode,
        currentPosition: Duration.zero,
        overallPercentage: 1.0,
        isCompleted: true,
        actionType: SeriesWatchActionType.watchAgain,
        nextEpisodeToWatch: firstEpisode,
      );
    }

    // 2. If an episode is currently partially watched -> Resume that episode
    if (partiallyWatchedEpisode != null && partiallyWatchedSession != null) {
      return SeriesProgress(
        seriesId: series.id,
        completedEpisodes: completedCount,
        totalAvailableEpisodes: totalEpisodes,
        currentEpisode: partiallyWatchedEpisode,
        currentPosition: partiallyWatchedSession.resumePosition,
        currentDuration: partiallyWatchedSession.resumePosition.inSeconds > 0
            ? Duration(
                seconds: (partiallyWatchedSession.resumePosition.inSeconds /
                        (partiallyWatchedSession.completionPercentage.clamp(0.01, 1.0)))
                    .round(),
              )
            : Duration.zero,
        overallPercentage: overallPercentage,
        isCompleted: false,
        actionType: SeriesWatchActionType.resume,
        nextEpisodeToWatch: partiallyWatchedEpisode,
      );
    }

    // 3. If latest watched episode is completed, resolve the next unwatched episode
    if (latestCompletedEpisode != null) {
      final nextResult = resolver.resolveNext(
        currentEpisode: latestCompletedEpisode,
        seasons: sortedSeasons,
      );
      if (!nextResult.isSeriesCompleted && nextResult.nextEpisode != null) {
        return SeriesProgress(
          seriesId: series.id,
          completedEpisodes: completedCount,
          totalAvailableEpisodes: totalEpisodes,
          currentEpisode: latestCompletedEpisode,
          currentPosition: Duration.zero,
          overallPercentage: overallPercentage,
          isCompleted: false,
          actionType: SeriesWatchActionType.playNext,
          nextEpisodeToWatch: nextResult.nextEpisode,
        );
      }
    }

    // 4. If any episode is completed but no next episode was found (or non-sequential completion),
    // find the first unwatched episode in order
    if (completedCount > 0) {
      for (final ep in allEpisodes) {
        if (!completedEpisodeIds.contains(ep.id)) {
          return SeriesProgress(
            seriesId: series.id,
            completedEpisodes: completedCount,
            totalAvailableEpisodes: totalEpisodes,
            currentEpisode: ep,
            currentPosition: Duration.zero,
            overallPercentage: overallPercentage,
            isCompleted: false,
            actionType: SeriesWatchActionType.playNext,
            nextEpisodeToWatch: ep,
          );
        }
      }
    }

    // 5. Never watched -> Play First Episode
    return SeriesProgress(
      seriesId: series.id,
      completedEpisodes: 0,
      totalAvailableEpisodes: totalEpisodes,
      currentEpisode: firstEpisode,
      currentPosition: Duration.zero,
      overallPercentage: 0.0,
      isCompleted: false,
      actionType: SeriesWatchActionType.playFirst,
      nextEpisodeToWatch: firstEpisode,
    );
  }
}
