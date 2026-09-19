// test/shared/tv_focusable_lifecycle_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/shared/dialogs/confirmation_dialog.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

Widget _wrap(Widget body) {
  return GetMaterialApp(home: Scaffold(body: body));
}

void main() {
  setUp(() {
    Get.reset();
  });

  group('TvFocusable lifecycle', () {
    testWidgets(
      'Enter/Select activation works after the key handler lifecycle change',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        int taps = 0;

        await tester.pumpWidget(
          _wrap(
            TvFocusable(
              autofocus: true,
              onTap: () => taps++,
              child: const Text('Activate Me'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Force a rebuild so the handler must survive didUpdateWidget/build.
        await tester.pumpWidget(
          _wrap(
            TvFocusable(
              autofocus: true,
              onTap: () => taps++,
              child: const Text('Activate Me'),
            ),
          ),
        );
        await tester.pump();

        expect(taps, 0);

        // Enter must activate the focused TvFocusable.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(taps, 1);

        // Select must also activate it.
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(taps, 2);
      },
    );

    testWidgets(
      'internal FocusNode survives parent subtree rebuilds without recreation',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final notifier = ValueNotifier<int>(0);

        await tester.pumpWidget(
          _wrap(
            ValueListenableBuilder<int>(
              valueListenable: notifier,
              builder: (context, value, _) => Column(
                children: [
                  TvFocusable(
                    autofocus: true,
                    onTap: () {},
                    child: Text('Item $value'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final focusBefore = FocusManager.instance.primaryFocus;
        expect(focusBefore, isNotNull);
        expect(find.text('Item 0'), findsOneWidget);

        // Multiple rapid rebuilds (simulating async content refresh).
        notifier.value = 1;
        await tester.pump();
        notifier.value = 2;
        await tester.pump();
        notifier.value = 3;
        await tester.pumpAndSettle();

        final focusAfter = FocusManager.instance.primaryFocus;
        expect(
          focusAfter,
          same(focusBefore),
          reason: 'FocusNode must not be recreated across parent rebuilds',
        );
        expect(find.text('Item 3'), findsOneWidget);

        notifier.dispose();
      },
    );

    testWidgets(
      'switching between external and internal focus node disposes cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final external = FocusNode(debugLabel: 'External');

        await tester.pumpWidget(
          _wrap(
            TvFocusable(
              focusNode: external,
              onTap: () {},
              child: const Text('External Node'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Replace with internally owned node.
        await tester.pumpWidget(
          _wrap(TvFocusable(onTap: () {}, child: const Text('Internal Node'))),
        );
        await tester.pumpAndSettle();

        // Replace with a different external node.
        final external2 = FocusNode(debugLabel: 'External2');
        await tester.pumpWidget(
          _wrap(
            TvFocusable(
              focusNode: external2,
              onTap: () {},
              child: const Text('External Node 2'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tear everything down; must not throw or leak.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        external.dispose();
        external2.dispose();
      },
    );

    testWidgets('native autofocus still lands on TvFocusable', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final otherNode = FocusNode(debugLabel: 'other');

      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              TvFocusable(
                focusNode: otherNode,
                onTap: () {},
                child: const Text('Other'),
              ),
              TvFocusable(
                autofocus: true,
                onTap: () {},
                child: const Text('CTA'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        FocusManager.instance.primaryFocus,
        isNot(equals(otherNode)),
        reason: 'autofocus must target the CTA, not the first sibling',
      );
      expect(FocusManager.instance.primaryFocus, isNotNull);

      otherNode.dispose();
    });
  });

  group('ConfirmationDialog focus', () {
    testWidgets('uses a FocusTraversalGroup so D-pad stays inside the dialog', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final pageNode = FocusNode(debugLabel: 'page');

      await tester.pumpWidget(
        _wrap(
          Focus(
            focusNode: pageNode,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ConfirmationDialog(
                    title: 'Confirm',
                    message: 'Are you sure?',
                    onConfirm: () {},
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmationDialog), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is FocusTraversalGroup && w.policy is OrderedTraversalPolicy,
        ),
        findsWidgets,
        reason: 'Dialog must scope directional focus with an ordered group',
      );

      // Focus moved from the underlying page into the dialog.
      expect(
        FocusManager.instance.primaryFocus,
        isNot(equals(pageNode)),
        reason: 'Opening a dialog must move primary focus into the dialog',
      );

      // Hammer directional keys: focus must move around but NEVER escape back
      // onto the underlying page's focusable.
      var moved = false;
      FocusNode? previous = FocusManager.instance.primaryFocus;
      for (final key in [
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowLeft,
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pump();
        final current = FocusManager.instance.primaryFocus;
        expect(
          current,
          isNot(equals(pageNode)),
          reason: 'D-pad navigation must remain inside the dialog ($key)',
        );
        expect(current, isNotNull);
        if (current != previous) moved = true;
        previous = current;
      }

      expect(
        moved,
        isTrue,
        reason: 'Directional keys should move focus between the dialog buttons',
      );

      pageNode.dispose();
    });
  });

  group('TvFocusable without activation handler', () {
    testWidgets(
      'ignores Select/Enter instead of swallowing it (no dead remote target)',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final node = FocusNode(debugLabel: 'decorative');

        await tester.pumpWidget(
          _wrap(
            TvFocusable(
              focusNode: node,
              child: const Text('Decorative wrapper'),
            ),
          ),
        );
        await tester.pump();

        final enterResult = node.onKeyEvent!(
          node,
          KeyDownEvent(
            logicalKey: LogicalKeyboardKey.enter,
            physicalKey: PhysicalKeyboardKey.enter,
            timeStamp: Duration.zero,
          ),
        );
        final selectResult = node.onKeyEvent!(
          node,
          KeyDownEvent(
            logicalKey: LogicalKeyboardKey.select,
            physicalKey: PhysicalKeyboardKey.select,
            timeStamp: Duration.zero,
          ),
        );

        expect(
          enterResult,
          KeyEventResult.ignored,
          reason:
              'A wrapper with no handler must not consume Enter; an interactive '
              'descendant may need to activate',
        );
        expect(selectResult, KeyEventResult.ignored);

        node.dispose();
      },
    );

    testWidgets(
      'still activates Select/Enter when an onTap handler exists',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final node = FocusNode(debugLabel: 'actionable');
        var taps = 0;

        await tester.pumpWidget(
          _wrap(
            TvFocusable(
              focusNode: node,
              onTap: () => taps++,
              child: const Text('Actionable'),
            ),
          ),
        );
        await tester.pump();

        final result = node.onKeyEvent!(
          node,
          KeyDownEvent(
            logicalKey: LogicalKeyboardKey.enter,
            physicalKey: PhysicalKeyboardKey.enter,
            timeStamp: Duration.zero,
          ),
        );

        expect(result, KeyEventResult.handled);
        expect(taps, 1);

        node.dispose();
      },
    );
  });
}
