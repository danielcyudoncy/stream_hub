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

  group('TvScaffold CTA focus', () {
    testWidgets('autofocused CTA in body receives initial focus', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final ctaNode = FocusNode(debugLabel: 'CTA');

      await tester.pumpWidget(
        _wrap(
          Center(
            child: TvFocusable(
              focusNode: ctaNode,
              autofocus: true,
              onTap: () {},
              child: const Text('Add Media Source'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        FocusManager.instance.primaryFocus,
        ctaNode,
        reason: 'autofocused CTA (not the invisible body container) should be focused',
      );

      ctaNode.dispose();
    });

    testWidgets('D-pad Right from sidebar exits to the CTA, not the bare body node',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final ctaNode = FocusNode(debugLabel: 'CTA');

      await tester.pumpWidget(
        _wrap(
          Center(
            child: TvFocusable(
              focusNode: ctaNode,
              autofocus: true,
              onTap: () {},
              child: const Text('Add Media Source'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, ctaNode);

      // Move Left to enter the sidebar (focus leaves the body).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(ctaNode.hasFocus, isFalse);

      // Press Right: must land on the actionable CTA, never the body container.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        ctaNode.hasFocus,
        isTrue,
        reason: 'Right from sidebar must land back on the actionable CTA',
      );

      ctaNode.dispose();
    });

    testWidgets('sidebar exit with no prior body focus lands on the first body focusable',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final ctaNode = FocusNode(debugLabel: 'CTA');
      final cardNode = FocusNode(debugLabel: 'Card');

      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              TvFocusable(
                focusNode: ctaNode,
                onTap: () {},
                child: const Text('Add Media Source'),
              ),
              const SizedBox(height: 40),
              TvFocusable(
                focusNode: cardNode,
                onTap: () {},
                child: const Text('A Card'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus is NOT in the body initially (e.g. app just opened on the sidebar
      // or focus landed nowhere visible). Simulate: focus the sidebar Home item
      // then press Right.
      final sidebarHome = FocusManager.instance.primaryFocus;
      // Move into the sidebar via Left (there is no prior body focus).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      // Press Right: should exit sidebar to the first registered body focusable.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        ctaNode.hasFocus,
        isTrue,
        reason: 'Sidebar Right must land on the FIRST actionable body focusable',
      );

      ctaNode.dispose();
      cardNode.dispose();
      expect(sidebarHome, isNotNull);
    });

    testWidgets('body container node can never be the primary focus (no invisible target)',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cardNode = FocusNode(debugLabel: 'Card');

      await tester.pumpWidget(
        _wrap(
          Center(
            child: TvFocusable(
              focusNode: cardNode,
              onTap: () {},
              child: const Text('Only Card'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      cardNode.requestFocus();
      await tester.pump();
      expect(cardNode.hasFocus, isTrue);

      // Traverse down/right repeatedly; focus must never get "stuck" on an
      // invisible container, and pressing Left at the card should open the
      // sidebar (the normal boundary behavior), never leave nothing focused.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(cardNode.hasFocus, isFalse, reason: 'Left at boundary opens the sidebar');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        cardNode.hasFocus,
        isTrue,
        reason: 'Right from sidebar returns to the real focusable card',
      );

      cardNode.dispose();
    });
  });
}