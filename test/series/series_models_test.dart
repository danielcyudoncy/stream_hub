import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/data/models/intro_segment.dart';
import 'package:stream_hub/data/models/season.dart';
import 'package:stream_hub/data/models/series_progress.dart';

void main() {
  group('Series Domain Models', () {
    test('Season model creation, serialization, and copyWith', () {
      final season = Season(
        id: 's1',
        seriesId: 'series_1',
        providerId: 'prov_1',
        providerType: MediaSourceType.xtream,
        seasonNumber: 1,
        title: 'Season One',
        episodeCount: 10,
      );

      expect(season.seasonNumber, 1);
      expect(season.title, 'Season One');
      expect(season.episodeCount, 10);

      final map = season.toMap();
      final fromMap = Season.fromMap(map);
      expect(fromMap.id, season.id);
      expect(fromMap.seasonNumber, 1);

      final copy = season.copyWith(episodeCount: 12);
      expect(copy.episodeCount, 12);
      expect(copy.title, 'Season One');
    });

    test('IntroSegment model containsPosition and serialization', () {
      final segment = IntroSegment(
        start: const Duration(seconds: 45),
        end: const Duration(seconds: 95),
        source: 'ai',
        confidence: 0.95,
        episodeId: 'ep_1',
      );

      expect(segment.duration, const Duration(seconds: 50));
      expect(segment.containsPosition(const Duration(seconds: 45)), isTrue);
      expect(segment.containsPosition(const Duration(seconds: 70)), isTrue);
      expect(segment.containsPosition(const Duration(seconds: 94)), isTrue);
      expect(segment.containsPosition(const Duration(seconds: 44)), isFalse);
      expect(segment.containsPosition(const Duration(seconds: 95)), isFalse);


      final map = segment.toMap();
      final fromMap = IntroSegment.fromMap(map);
      expect(fromMap.start, segment.start);
      expect(fromMap.end, segment.end);
      expect(fromMap.confidence, 0.95);
    });

    test('SeriesProgress summaryText formatting', () {
      final progress = SeriesProgress(
        seriesId: 'series_1',
        completedEpisodes: 4,
        totalAvailableEpisodes: 10,
        overallPercentage: 0.45,
        currentPosition: const Duration(minutes: 20),
        currentDuration: const Duration(minutes: 50),
        actionType: SeriesWatchActionType.resume,
      );

      expect(progress.summaryText, '30m left');
    });
  });
}
