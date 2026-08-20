import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/modules/player/widgets/next_episode_overlay.dart';
import 'package:stream_hub/modules/player/widgets/skip_intro_button.dart';
import 'package:stream_hub/modules/series/widgets/episode_card.dart';
import 'package:stream_hub/modules/series/widgets/series_card.dart';

void main() {
  testWidgets('SeriesCard renders title, seasons, rating, and handles tap', (tester) async {
    final now = DateTime.now();
    final item = MediaItem(
      id: 'series-1',
      title: 'Stranger Things',
      providerId: 'prov-1',
      providerType: MediaSourceType.xtream,
      mediaType: MediaType.series,
      rating: 8.7,
      genres: const ['Drama', 'Sci-Fi'],
      metadata: {'seasonsCount': 4},
      createdAt: now,
      updatedAt: now,
    );

    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeriesCard(
            item: item,
            onTap: () => tapped = true,
            progressPercentage: 0.5,
          ),
        ),
      ),
    );

    expect(find.text('Stranger Things'), findsOneWidget);
    expect(find.text('4 Seasons'), findsOneWidget);
    expect(find.text('8.7'), findsOneWidget);

    await tester.tap(find.byType(SeriesCard));
    expect(tapped, isTrue);
  });

  testWidgets('EpisodeCard renders episode details, badges, and progress bar', (tester) async {
    final now = DateTime.now();
    final episode = MediaItem(
      id: 'ep-1',
      title: 'Chapter One: The Vanishing',
      providerId: 'prov-1',
      providerType: MediaSourceType.xtream,
      mediaType: MediaType.episode,
      metadata: {
        'seasonNumber': 1,
        'episodeNumber': 1,
        'duration': 50,
      },
      createdAt: now,
      updatedAt: now,
    );

    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpisodeCard(
            episode: episode,
            episodeNumber: 'S01E01',
            progressPercentage: 0.75,
            isNextUp: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Chapter One: The Vanishing'), findsOneWidget);
    expect(find.text('S01E01'), findsOneWidget);
    expect(find.text('50 min'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);

    await tester.tap(find.byType(EpisodeCard));
    expect(tapped, isTrue);
  });

  testWidgets('NextEpisodeOverlay renders countdown and buttons', (tester) async {
    final now = DateTime.now();
    final nextEp = MediaItem(
      id: 'ep-2',
      title: 'The Weirdo on Maple Street',
      providerId: 'prov-1',
      providerType: MediaSourceType.xtream,
      mediaType: MediaType.episode,
      metadata: {'seasonNumber': 1, 'episodeNumber': 2},
      createdAt: now,
      updatedAt: now,
    );

    var playPressed = false;
    var cancelPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              NextEpisodeOverlay(
                nextEpisode: nextEp,
                onPlayNow: () => playPressed = true,
                onCancel: () => cancelPressed = true,
                countdownSeconds: 10,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('The Weirdo on Maple Street'), findsOneWidget);
    expect(find.text('Play Now'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Play Now'));
    expect(playPressed, isTrue);

    await tester.tap(find.text('Cancel'));
    expect(cancelPressed, isTrue);
  });

  testWidgets('SkipIntroButton renders and triggers onSkip', (tester) async {
    var skipped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              SkipIntroButton(
                onSkip: () => skipped = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Skip Intro'), findsOneWidget);

    await tester.tap(find.text('Skip Intro'));
    expect(skipped, isTrue);
  });
}
