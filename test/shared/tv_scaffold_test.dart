import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';
import 'package:stream_hub/shared/widgets/tv_scaffold.dart';

Widget _wrap(Widget body) {
  return GetMaterialApp(
    home: TvScaffold(body: body),
  );
}

void main() {
  setUp(() {
    Get.reset();
  });
  group('TvScaffold Remote Navigation', () {
    testWidgets('renders all sidebar navigation items and body', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          const Text('Main TV Body'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Main TV Body'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Live TV'), findsOneWidget);
      expect(find.text('Free TV'), findsOneWidget);
      expect(find.text('VOD Movies'), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Multi-View'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets(
        'allows moving left between cards before exiting to sidebar at left boundary',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final node1 = FocusNode(debugLabel: 'Card_1');
      final node2 = FocusNode(debugLabel: 'Card_2');

      await tester.pumpWidget(
        _wrap(
          Row(
            children: [
              TvFocusable(
                focusNode: node1,
                child: const SizedBox(width: 200, height: 100, child: Text('Card 1')),
              ),
              const SizedBox(width: 20),
              TvFocusable(
                focusNode: node2,
                child: const SizedBox(width: 200, height: 100, child: Text('Card 2')),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially focus Card 2
      node2.requestFocus();
      await tester.pump();
      expect(node2.hasFocus, isTrue);

      // Press Left: moves to Card 1 within the body
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(node1.hasFocus, isTrue);

      // Press Left again from Card 1: at leftmost boundary, opens sidebar and focuses Home
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      // Home nav item should now have focus
      expect(node1.hasFocus, isFalse);

      // Press Right: exits sidebar and returns focus back to body
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(node1.hasFocus, isTrue);

      node1.dispose();
      node2.dispose();
    });

    testWidgets('escape/back collapses expanded sidebar and restores focus to body',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cardNode = FocusNode(debugLabel: 'Single_Card');

      await tester.pumpWidget(
        _wrap(
          TvFocusable(
            focusNode: cardNode,
            child: const SizedBox(width: 200, height: 100, child: Text('Single Card')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      cardNode.requestFocus();
      await tester.pump();
      expect(cardNode.hasFocus, isTrue);

      // Press Left: transitions into sidebar
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(cardNode.hasFocus, isFalse);

      // Press Escape: collapses sidebar and restores focus
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(cardNode.hasFocus, isTrue);

      cardNode.dispose();
    });
  });
}
