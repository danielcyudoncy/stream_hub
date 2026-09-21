import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/modules/live_tv/widgets/live_tv_category_bar.dart';
import 'package:stream_hub/shared/widgets/provider_selector_button.dart';

void main() {
  group('Live TV Focus Navigation Tests', () {
    testWidgets(
        'LiveTvCategoryBar invokes onMoveUp when Up Arrow is pressed on focused chip',
        (tester) async {
      bool moveUpCalled = false;
      FocusNode? focusedNode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveTvCategoryBar(
              categories: const ['News', 'Sports', 'Movies'],
              selectedCategory: 'News',
              showFavoritesOnly: false,
              favoritesCount: 0,
              onCategorySelected: (_) {},
              onFavoritesToggle: (_) {},
              onMoveUp: () {
                moveUpCalled = true;
              },
              onFocusCategory: (node) {
                focusedNode = node;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the first chip's FocusableActionDetector
      final detectorFinder = find.byType(FocusableActionDetector).first;
      expect(detectorFinder, findsOneWidget);
      final chipFocusNode =
          tester.widget<FocusableActionDetector>(detectorFinder).focusNode!;

      // Focus the chip
      chipFocusNode.requestFocus();
      await tester.pumpAndSettle();

      expect(chipFocusNode.hasFocus, isTrue);
      expect(focusedNode, equals(chipFocusNode));

      // Send Up Arrow key event
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(moveUpCalled, isTrue);
    });

    testWidgets(
        'ProviderSelectorButton invokes onMoveDown when Down Arrow is pressed',
        (tester) async {
      bool moveDownCalled = false;
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderSelectorButton(
              selectedProviderId: 'test-provider',
              onSelectProvider: (_) {},
              focusNode: focusNode,
              onMoveDown: () {
                moveDownCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Request focus on the provider button
      focusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue);

      // Send Down Arrow key event
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(moveDownCalled, isTrue);

      focusNode.dispose();
    });
  });
}
