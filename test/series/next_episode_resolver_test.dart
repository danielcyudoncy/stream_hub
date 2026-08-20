import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/streaming/series/next_episode_resolver.dart';
import 'package:stream_hub/data/models/media_item.dart';

void main() {
  const resolver = NextEpisodeResolver();

  MediaItem makeEpisode({
    required String id,
    required String title,
    required int seasonNumber,
    required int episodeNumber,
  }) {
    final now = DateTime.now();
    return MediaItem(
      id: id,
      providerId: 'provider-1',
      providerType: MediaSourceType.xtream,
      mediaType: MediaType.episode,
      title: title,
      metadata: {
        'seriesId': 'series-1',
        'seasonNumber': seasonNumber,
        'episodeNumber': episodeNumber,
      },
      createdAt: now,
      updatedAt: now,
    );
  }

  group('NextEpisodeResolver', () {
    final s1e1 = makeEpisode(id: 's1e1', title: 'Pilot', seasonNumber: 1, episodeNumber: 1);
    final s1e2 = makeEpisode(id: 's1e2', title: 'Cat’s in the Bag', seasonNumber: 1, episodeNumber: 2);
    final s1e3 = makeEpisode(id: 's1e3', title: '...And the Bag’s in the River', seasonNumber: 1, episodeNumber: 3);

    final s2e1 = makeEpisode(id: 's2e1', title: 'Seven Thirty-Seven', seasonNumber: 2, episodeNumber: 1);
    final s2e2 = makeEpisode(id: 's2e2', title: 'Grilled', seasonNumber: 2, episodeNumber: 2);

    final season1 = SeasonGroup(number: 1, name: 'Season 1', episodes: [s1e1, s1e2, s1e3]);
    final season2 = SeasonGroup(number: 2, name: 'Season 2', episodes: [s2e1, s2e2]);
    final allSeasons = [season1, season2];

    test('resolves next episode within the same season', () {
      final result = resolver.resolveNext(
        currentEpisode: s1e1,
        seasons: allSeasons,
      );

      expect(result.isSeriesCompleted, isFalse);
      expect(result.nextEpisode?.id, s1e2.id);
      expect(result.nextSeason?.number, 1);
    });

    test('resolves next episode across season boundary (S1 end -> S2 start)', () {
      final result = resolver.resolveNext(
        currentEpisode: s1e3,
        seasons: allSeasons,
      );

      expect(result.isSeriesCompleted, isFalse);
      expect(result.nextEpisode?.id, s2e1.id);
      expect(result.nextSeason?.number, 2);
    });

    test('detects series completion at the final episode of the final season', () {
      final result = resolver.resolveNext(
        currentEpisode: s2e2,
        seasons: allSeasons,
      );

      expect(result.isSeriesCompleted, isTrue);
      expect(result.nextEpisode, isNull);
    });

    test('resolves previous episode within same season', () {
      final prev = resolver.resolvePrevious(
        currentEpisode: s1e2,
        seasons: allSeasons,
      );

      expect(prev?.id, s1e1.id);
    });

    test('resolves previous episode across season boundary (S2 start -> S1 end)', () {
      final prev = resolver.resolvePrevious(
        currentEpisode: s2e1,
        seasons: allSeasons,
      );

      expect(prev?.id, s1e3.id);
    });

    test('returns null for previous episode on the very first episode', () {
      final prev = resolver.resolvePrevious(
        currentEpisode: s1e1,
        seasons: allSeasons,
      );

      expect(prev, isNull);
    });

    test('handles out-of-order and non-contiguous seasons and episodes gracefully', () {
      final s3e5 = makeEpisode(id: 's3e5', title: 'Ep 5', seasonNumber: 3, episodeNumber: 5);
      final s3e2 = makeEpisode(id: 's3e2', title: 'Ep 2', seasonNumber: 3, episodeNumber: 2);
      final s1 = SeasonGroup(number: 1, name: 'S1', episodes: [s1e1]);
      final s3 = SeasonGroup(number: 3, name: 'S3', episodes: [s3e5, s3e2]); // Out of order

      final result1 = resolver.resolveNext(
        currentEpisode: s1e1,
        seasons: [s3, s1], // Seasons out of order
      );

      expect(result1.nextEpisode?.id, s3e2.id); // S3E2 before S3E5

      final result2 = resolver.resolveNext(
        currentEpisode: s3e2,
        seasons: [s3, s1],
      );

      expect(result2.nextEpisode?.id, s3e5.id);
    });
  });
}
