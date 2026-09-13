import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/shared/dialogs/parental_pin_dialog.dart';

void main() {
  testWidgets('ParentalPinDialog in changePin mode allows toggling PIN visibility',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParentalPinDialog(
            mode: ParentalPinDialogMode.changePin,
            onChangePin: (curr, next) async => true,
          ),
        ),
      ),
    );

    // Initial state: 3 TextFields, all obscured
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(3));

    TextField currentField = tester.widget<TextField>(textFields.at(0));
    expect(currentField.obscureText, isTrue);

    TextField newField = tester.widget<TextField>(textFields.at(1));
    expect(newField.obscureText, isTrue);

    TextField confirmField = tester.widget<TextField>(textFields.at(2));
    expect(confirmField.obscureText, isTrue);

    // Find visibility icon buttons
    final visibilityButtons = find.byType(IconButton);
    expect(visibilityButtons, findsNWidgets(3));

    // Tap toggle for the first field (current PIN)
    await tester.tap(visibilityButtons.at(0));
    await tester.pump();

    // Verify first field is now unobscured, others remain obscured
    currentField = tester.widget<TextField>(textFields.at(0));
    expect(currentField.obscureText, isFalse);

    newField = tester.widget<TextField>(textFields.at(1));
    expect(newField.obscureText, isTrue);

    // Tap toggle for the second field (new PIN)
    await tester.tap(visibilityButtons.at(1));
    await tester.pump();

    newField = tester.widget<TextField>(textFields.at(1));
    expect(newField.obscureText, isFalse);

    // Tap toggle again to re-obscure first field
    await tester.tap(visibilityButtons.at(0));
    await tester.pump();

    currentField = tester.widget<TextField>(textFields.at(0));
    expect(currentField.obscureText, isTrue);
  });

  testWidgets('ParentalPinDialog in unlock mode does not overflow on landscape phone with keyboard',
      (tester) async {
    // 720 x 200 represents a landscape phone (e.g. 720x400) with a software keyboard open (takes ~200px)
    tester.view.physicalSize = const Size(720, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParentalPinDialog(
            mode: ParentalPinDialogMode.unlock,
            onValidate: (pin) async => pin == '1234',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Parental Lock'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
  });

  testWidgets('ParentalPinDialog does not overflow on the right in any mode on compact landscape viewports',
      (tester) async {
    final sizes = [
      const Size(280, 180),
      const Size(300, 160),
      const Size(500, 200),
      const Size(600, 220),
      const Size(640, 250),
      const Size(720, 200),
      const Size(800, 300),
      const Size(360, 640),
      const Size(320, 480),
    ];

    for (final size in sizes) {
      for (final mode in ParentalPinDialogMode.values) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ParentalPinDialog(
                mode: mode,
                title: 'Parental PIN Security Access Gate',
                message: 'Enter your 4-digit PIN to proceed with channel playback.',
                onValidate: (pin) async => true,
                onSetPin: (pin) async => true,
                onChangePin: (c, n) async => true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'Overflow occurred for mode $mode at size $size');
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('ParentalPinDialog submits on keyboard Enter / Done action',
      (tester) async {
    String? validatedPin;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParentalPinDialog(
            mode: ParentalPinDialogMode.unlock,
            onValidate: (pin) async {
              validatedPin = pin;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);

    // Enter 4 digits and submit via keyboard action
    await tester.enterText(textField, '5678');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(validatedPin, equals('5678'));
  });

  testWidgets('ParentalPinDialog in setPin mode advances focus and submits',
      (tester) async {
    String? savedPin;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParentalPinDialog(
            mode: ParentalPinDialogMode.setPin,
            onSetPin: (pin) async {
              savedPin = pin;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    // Type 4 digits in the first field -> auto advances or submits with enter
    await tester.enterText(textFields.at(0), '1122');
    await tester.pumpAndSettle();

    // Type matching 4 digits in confirm field and press Done
    await tester.enterText(textFields.at(1), '1122');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(savedPin, equals('1122'));
  });

  testWidgets('ParentalPinDialog in changePin mode advances focus across 3 fields and submits',
      (tester) async {
    String? capturedCurrentPin;
    String? capturedNewPin;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParentalPinDialog(
            mode: ParentalPinDialogMode.changePin,
            onChangePin: (curr, next) async {
              capturedCurrentPin = curr;
              capturedNewPin = next;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(3));

    // Field 0: Current PIN
    await tester.enterText(textFields.at(0), '1234');
    await tester.pumpAndSettle();

    // Field 1: New PIN
    await tester.enterText(textFields.at(1), '9999');
    await tester.pumpAndSettle();

    // Field 2: Confirm PIN + Done
    await tester.enterText(textFields.at(2), '9999');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(capturedCurrentPin, equals('1234'));
    expect(capturedNewPin, equals('9999'));
  });
}
