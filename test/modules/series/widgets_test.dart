import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/modules/player/widgets/next_episode_overlay.dart';
import 'package:stream_hub/modules/player/widgets/skip_intro_button.dart';
import 'package:stream_hub/modules/series/widgets/episode_card.dart';
import 'package:stream_hub/modules/series/widgets/series_card.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

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

  testWidgets('EpisodeCard navigates with TV remote D-Pad between Card, Download, and Play buttons', (tester) async {
    final now = DateTime.now();
    final episode = MediaItem(
      id: 'ep-focus-test',
      title: 'Pilot',
      providerId: 'prov-1',
      providerType: MediaSourceType.xtream,
      mediaType: MediaType.episode,
      metadata: {
        'seasonNumber': 1,
        'episodeNumber': 1,
      },
      createdAt: now,
      updatedAt: now,
    );

    var playTapped = false;
    var downloadTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpisodeCard(
            episode: episode,
            episodeNumber: 'S01E01',
            onTap: () => playTapped = true,
            onDownload: () => downloadTapped = true,
          ),
        ),
      ),
    );

    // Initial state
    expect(playTapped, isFalse);
    expect(downloadTapped, isFalse);

    // 1. First focus lands on the Card Play Area
    final focusWidget = tester.widget<Focus>(
      find.descendant(
        of: find.byType(TvFocusable).first,
        matching: find.byType(Focus),
      ).first,
    );
    focusWidget.focusNode?.requestFocus();
    await tester.pumpAndSettle();

    // 2. Press Enter/Select on the card -> Triggers Play
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(playTapped, isTrue);

    // 3. Press Arrow Right -> Focus shifts to Download Button
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // 4. Press Enter/Select on Download Button -> Triggers Download
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(downloadTapped, isTrue);

    // 5. Press Arrow Right -> Focus shifts to Play Button
    playTapped = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // 6. Press Enter/Select on Play Button -> Triggers Play
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(playTapped, isTrue);

    // 7. Press Arrow Left -> Returns to Download Button
    downloadTapped = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(downloadTapped, isTrue);

    // 8. Press Arrow Left -> Returns to Card Play Area
    playTapped = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(playTapped, isTrue);
  });

  testWidgets('EpisodeCard does not overflow on narrow widths with long episodeNumber and duration', (tester) async {
    final now = DateTime.now();
    final episode = MediaItem(
      id: 'ep-overflow-test',
      title: 'Very Long Episode Title That Exceeds Normal Limits On Small Mobile Screens',
      subtitle: 'Season 1 Episode 12 - Extended Director Special Edition',
      description: 'An in-depth story synopsis that provides descriptive narrative context.',
      providerId: 'prov-1',
      providerType: MediaSourceType.xtream,
      mediaType: MediaType.episode,
      metadata: {
        'seasonNumber': 1,
        'episodeNumber': 12,
        'duration': 3600,
      },
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 250, // Extreme narrow width test
              child: EpisodeCard(
                episode: episode,
                episodeNumber: 'Season 1 Episode 12 Special Extended Edition',
                progressPercentage: 0.5,
                isNextUp: true,
                isCurrentlyPlaying: true,
                onDownload: () {},
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(EpisodeCard), findsOneWidget);
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
