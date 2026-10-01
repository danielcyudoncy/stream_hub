import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/shared/widgets/search_bar.dart';

void main() {
  testWidgets('AppSearchBar allows D-pad escape when editing', (tester) async {
    final controller = TextEditingController();
    String query = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppSearchBar(
                controller: controller,
                onChanged: (val) => query = val,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {},
                child: const Text('Below Button'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(AppSearchBar), findsOneWidget);

    // Tap search bar to enter editing
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    // Type text
    await tester.enterText(find.byType(TextField), 'Sports');
    await tester.pumpAndSettle();
    expect(query, equals('Sports'));

    // Send arrowDown event while editing
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Send Escape event
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  });
}
