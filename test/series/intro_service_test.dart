import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/streaming/series/intro_service.dart';
import 'package:stream_hub/data/models/intro_segment.dart';
import 'package:stream_hub/data/models/media_item.dart';

void main() {
  final introService = IntroService();

  tearDown(() {
    introService.clear();
  });

  test('extracts intro segment from episode metadata timestamps', () {
    final now = DateTime.now();
    final episode = MediaItem(
      id: 'ep-1',
      providerId: 'prov-1',
      providerType: MediaSourceType.xtream,
      mediaType: MediaType.episode,
      title: 'Episode 1',
      metadata: {
        'introStartMs': 90000, // 1m 30s
        'introEndMs': 150000,  // 2m 30s
        'introSource': 'provider',
      },
      createdAt: now,
      updatedAt: now,
    );

    final segment = introService.getIntroSegment(episode);

    expect(segment, isNotNull);
    expect(segment!.start, const Duration(milliseconds: 90000));
    expect(segment.end, const Duration(milliseconds: 150000));
    expect(segment.containsPosition(const Duration(minutes: 2)), isTrue);
    expect(segment.containsPosition(const Duration(seconds: 30)), isFalse);
    expect(segment.containsPosition(const Duration(minutes: 3)), isFalse);
  });

  test('registers and retrieves cached intro segments manually', () {
    final segment = const IntroSegment(
      start: Duration(seconds: 60),
      end: Duration(seconds: 120),
      episodeId: 'ep-manual',
    );

    introService.registerIntroSegment('ep-manual', segment);

    final now = DateTime.now();
    final episode = MediaItem(
      id: 'ep-manual',
      providerId: 'prov-1',
      providerType: MediaSourceType.xtream,
      mediaType: MediaType.episode,
      title: 'Manual Episode',
      createdAt: now,
      updatedAt: now,
    );

    final retrieved = introService.getIntroSegment(episode);
    expect(retrieved, equals(segment));
  });
}
