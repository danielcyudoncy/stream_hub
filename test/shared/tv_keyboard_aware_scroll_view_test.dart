import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stream_hub/shared/widgets/tv_keyboard_aware_scroll_view.dart';

void main() {
  group('shouldReserveKeyboardHeight', () {
    test('reserves only for Android TV with a focused field and no insets', () {
      expect(
        shouldReserveKeyboardHeight(
          isAndroid: true,
          isTvLayout: true,
          isDesktop: false,
          textFieldFocused: true,
          bottomInset: 0,
        ),
        isTrue,
      );
    });

    test('does not reserve when the platform reports keyboard insets', () {
      expect(
        shouldReserveKeyboardHeight(
          isAndroid: true,
          isTvLayout: true,
          isDesktop: false,
          textFieldFocused: true,
          bottomInset: 400,
        ),
        isFalse,
      );
    });

    test('does not reserve on desktop where a hardware keyboard is expected',
        () {
      expect(
        shouldReserveKeyboardHeight(
          isAndroid: false,
          isTvLayout: true,
          isDesktop: false,
          textFieldFocused: true,
          bottomInset: 0,
        ),
        isFalse,
      );
    });

    test('does not reserve when no text field is focused', () {
      expect(
        shouldReserveKeyboardHeight(
          isAndroid: true,
          isTvLayout: true,
          isDesktop: false,
          textFieldFocused: false,
          bottomInset: 0,
        ),
        isFalse,
      );
    });
  });

  group('TvKeyboardAwareScrollView', () {
    Future<void> pumpScrollView(
      WidgetTester tester, {
      required double viewWidth,
      required double viewHeight,
      required Widget child,
    }) async {
      tester.view.physicalSize = Size(viewWidth, viewHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvKeyboardAwareScrollView(
              padding: const EdgeInsets.all(16.0),
              child: child,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
        'focusing a field below the fold scrolls it into the visible viewport',
        (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);

      await pumpScrollView(
        tester,
        viewWidth: 800,
        viewHeight: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 700),
            TextField(focusNode: focus),
          ],
        ),
      );

      final field = find.byType(TextField);
      final bottomOfView = 600.0;
      expect(tester.getBottomLeft(field).dy, greaterThan(bottomOfView),
          reason: 'field starts below the visible viewport');

      focus.requestFocus();
      await tester.pumpAndSettle();

      final rect = tester.getRect(field);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(
        rect.bottom,
        lessThanOrEqualTo(bottomOfView),
        reason: 'focused field must be scrolled fully into view',
      );
    });
  });
}