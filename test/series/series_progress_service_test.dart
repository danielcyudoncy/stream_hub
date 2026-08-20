import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/streaming/series/next_episode_resolver.dart';
import 'package:stream_hub/core/streaming/series/series_progress_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playback_session_model.dart';
import 'package:stream_hub/data/models/series_progress.dart';

void main() {
  const service = SeriesProgressService();

  MediaItem makeSeries(String id) {
    final now = DateTime.now();
    return MediaItem(
      id: id,
      providerId: 'prov-1',
      providerType: MediaSourceType.xtream,
      mediaType: MediaType.series,
      title: 'Breaking Bad',
      createdAt: now,
      updatedAt: now,
    );
  }

  MediaItem makeEpisode({
    required String id,
    required String seriesId,
    required int seasonNumber,
    required int episodeNumber,
  }) {
    final now = DateTime.now();
    return MediaItem(
      id: id,
      providerId: 'prov-1',
      providerType: MediaSourceType.xtream,
      mediaType: MediaType.episode,
      title: 'Episode $episodeNumber',
      metadata: {
        'seriesId': seriesId,
        'seasonNumber': seasonNumber,
        'episodeNumber': episodeNumber,
      },
      createdAt: now,
      updatedAt: now,
    );
  }

  group('SeriesProgressService', () {
    final series = makeSeries('series-1');
    final s1e1 = makeEpisode(id: 's1e1', seriesId: 'series-1', seasonNumber: 1, episodeNumber: 1);
    final s1e2 = makeEpisode(id: 's1e2', seriesId: 'series-1', seasonNumber: 1, episodeNumber: 2);
    final s1e3 = makeEpisode(id: 's1e3', seriesId: 'series-1', seasonNumber: 1, episodeNumber: 3);

    final season1 = SeasonGroup(number: 1, name: 'Season 1', episodes: [s1e1, s1e2, s1e3]);
    final allSeasons = [season1];

    test('returns playFirst when no episodes have watch sessions', () {
      final progress = service.computeProgress(
        series: series,
        seasons: allSeasons,
        watchSessions: {},
      );

      expect(progress.actionType, SeriesWatchActionType.playFirst);
      expect(progress.actionLabel, 'Play S01E01');
      expect(progress.completedEpisodes, 0);
      expect(progress.totalAvailableEpisodes, 3);
      expect(progress.overallPercentage, 0.0);
      expect(progress.nextEpisodeToWatch?.id, s1e1.id);
    });

    test('returns resume when an episode is partially watched', () {
      final now = DateTime.now();
      final sessions = {
        s1e1.id: PlaybackSessionModel(
          id: 'sess-1',
          itemId: s1e1.id,
          providerType: 'xtream',
          resumePosition: const Duration(minutes: 15),
          completionPercentage: 0.35,
          updatedAt: now,
        ),
      };

      final progress = service.computeProgress(
        series: series,
        seasons: allSeasons,
        watchSessions: sessions,
      );

      expect(progress.actionType, SeriesWatchActionType.resume);
      expect(progress.actionLabel.startsWith('Resume S01E01'), isTrue);
      expect(progress.currentPosition, const Duration(minutes: 15));
      expect(progress.nextEpisodeToWatch?.id, s1e1.id);
    });

    test('returns playNext when the first episode is completed', () {
      final now = DateTime.now();
      final sessions = {
        s1e1.id: PlaybackSessionModel(
          id: 'sess-1',
          itemId: s1e1.id,
          providerType: 'xtream',
          resumePosition: const Duration(minutes: 45),
          completionPercentage: 0.95, // Above 90%
          updatedAt: now,
        ),
      };

      final progress = service.computeProgress(
        series: series,
        seasons: allSeasons,
        watchSessions: sessions,
      );

      expect(progress.actionType, SeriesWatchActionType.playNext);
      expect(progress.actionLabel, 'Next: S01E02');
      expect(progress.completedEpisodes, 1);
      expect(progress.nextEpisodeToWatch?.id, s1e2.id);

    });

    test('returns watchAgain when all episodes are completed', () {
      final now = DateTime.now();
      final sessions = {
        s1e1.id: PlaybackSessionModel(
          id: 'sess-1',
          itemId: s1e1.id,
          providerType: 'xtream',
          resumePosition: const Duration(minutes: 45),
          completionPercentage: 0.95,
          updatedAt: now,
        ),
        s1e2.id: PlaybackSessionModel(
          id: 'sess-2',
          itemId: s1e2.id,
          providerType: 'xtream',
          resumePosition: const Duration(minutes: 45),
          completionPercentage: 0.92,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
        s1e3.id: PlaybackSessionModel(
          id: 'sess-3',
          itemId: s1e3.id,
          providerType: 'xtream',
          resumePosition: const Duration(minutes: 45),
          completionPercentage: 0.98,
          updatedAt: now.add(const Duration(minutes: 2)),
        ),
      };

      final progress = service.computeProgress(
        series: series,
        seasons: allSeasons,
        watchSessions: sessions,
      );

      expect(progress.isCompleted, isTrue);
      expect(progress.actionType, SeriesWatchActionType.watchAgain);
      expect(progress.actionLabel, 'Watch Again');
      expect(progress.completedEpisodes, 3);
      expect(progress.overallPercentage, 1.0);
      expect(progress.nextEpisodeToWatch?.id, s1e1.id);
    });
  });
}
