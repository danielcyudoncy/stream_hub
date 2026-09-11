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
}
