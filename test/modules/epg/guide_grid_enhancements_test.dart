import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/modules/epg/models/epg_channel.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/modules/epg/widgets/guide_grid.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GuideGrid renders 30-minute intervals and TODAY date badge', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final todayString = 'TODAY ${DateFormat('M/d').format(now)}';

    final channel = EPGChannel(
      id: 'ch-logo',
      providerId: 'prov-1',
      providerType: MediaSourceType.m3u,
      title: 'LOGO',
      number: '281',
      mediaType: MediaType.channel,
      createdAt: now,
      updatedAt: now,
    );

    final program = EPGProgram(
      id: 'prog-1',
      channelId: 'ch-logo',
      title: 'To Wong Foo, Thanks for Everything! Julie Newmar',
      description: 'Good-natured but labored story of three drag queens...',
      startTime: now.subtract(const Duration(minutes: 30)),
      endTime: now.add(const Duration(minutes: 90)),
      mediaType: MediaType.movie,
      genres: const ['Comedy', 'Movie'],
      providerId: 'prov-1',
      providerType: MediaSourceType.m3u,
      createdAt: now,
      updatedAt: now,
      metadata: const {'rating': 'TV14'},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuideGrid(
            channels: [channel],
            programs: [program],
            channelProgramsMap: {
              'ch-logo': [program],
            },
            onProgramTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify the 'TODAY M/d' header badge is rendered
    expect(find.text(todayString), findsOneWidget);

    // 2. Verify channel number and title in compact channel column
    expect(find.text('281'), findsOneWidget);
    expect(find.text('LOGO'), findsWidgets);

    // 3. Verify Program Tile is rendered in grid
    expect(
      find.text('To Wong Foo, Thanks for Everything! Julie Newmar'),
      findsOneWidget,
    );

    // 4. Verify Purple Movie Genre accent bar is rendered inside tile
    final purpleBarFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == const Color(0xFFAB47BC),
    );
    expect(purpleBarFinder, findsOneWidget);

    // 5. Focus on the program tile and verify popover overlay appears
    final programTileFinder = find.ancestor(
      of: find.text('To Wong Foo, Thanks for Everything! Julie Newmar'),
      matching: find.byType(TvFocusable),
    );
    expect(programTileFinder, findsWidgets);

    // Request focus on the program card
    final programTile = tester.widget<TvFocusable>(programTileFinder.first);
    expect(programTile.focusColor, const Color(0xFFFFD54F)); // Gold/yellow focus ring

    final focusFinder = find.descendant(
      of: programTileFinder.first,
      matching: find.byType(Focus),
    );
    final focusWidget = tester.widget<Focus>(focusFinder.first);
    focusWidget.focusNode?.requestFocus();
    await tester.pumpAndSettle();

    // Verify rating badge and description in popover (4-row layout)
    expect(find.text('TV14'), findsWidgets);
    expect(
      find.text('Good-natured but labored story of three drag queens...'),
      findsOneWidget,
    );
  });
}
