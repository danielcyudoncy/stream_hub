import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/shared/widgets/app_button.dart';

Widget _wrap(Widget button) {
  return MaterialApp(
    home: Scaffold(body: Center(child: button)),
  );
}

void main() {
  group('AppButton', () {
    testWidgets('fits a label wider than its fixed width without overflowing',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppButton.primary(
            text: 'Resend Verification Email',
            icon: Icons.mail_outline,
            width: 100,
            onPressed: () {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Resend Verification Email'), findsOneWidget);
    });

    testWidgets('renders a long label without an overflow when stretched',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppButton.primary(
            text: 'A very long button label that must not overflow',
            onPressed: () {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text('A very long button label that must not overflow'),
        findsOneWidget,
      );
    });
  });
}
