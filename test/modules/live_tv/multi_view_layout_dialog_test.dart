import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/modules/live_tv/models/multi_view_layout_mode.dart';
import 'package:stream_hub/modules/live_tv/widgets/multi_view_layout_dialog.dart';

void main() {
  testWidgets('MultiViewLayoutDialog renders all 4 layouts and allows selection', (tester) async {
    MultiViewLayoutMode? selectedMode;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  selectedMode = await showMultiViewLayoutDialog(
                    context,
                    currentMode: MultiViewLayoutMode.dualHorizontal,
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      ),
    );

    // Tap button to open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify dialog title and all 4 modes are present
    expect(find.text('Choose Multi-View Layout'), findsOneWidget);
    expect(find.text('Dual (Side-by-Side)'), findsOneWidget);
    expect(find.text('Dual (Stacked)'), findsOneWidget);
    expect(find.text('Triple View'), findsOneWidget);
    expect(find.text('Quad View'), findsOneWidget);

    // Tap Triple View
    await tester.tap(find.text('Triple View'));
    await tester.pumpAndSettle();

    // Verify dialog dismissed and selectedMode was updated
    expect(find.text('Choose Multi-View Layout'), findsNothing);
    expect(selectedMode, equals(MultiViewLayoutMode.triple));
  });
}
