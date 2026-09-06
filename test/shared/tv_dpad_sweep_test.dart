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

/// A page-shaped body simulating Provider Manager's column:
/// [Add Provider bar] -> [search/filter row] -> [provider list].
Widget _providerManagerLikeBody(List<FocusNode> addProvider) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            const Expanded(child: Text('Connect your IPTV provider to get started.')),
            TvFocusable(
              focusNode: addProvider[0],
              autofocus: true,
              onTap: () {},
              child: const Text('Add Provider'),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TvFocusable(
              focusNode: addProvider[1],
              onTap: () {},
              child: const Icon(Icons.tune),
            ),
            const SizedBox(width: 8),
            TvFocusable(
              focusNode: addProvider[2],
              onTap: () {},
              child: const Icon(Icons.sort),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          children: [
            for (var i = 3; i < addProvider.length; i++)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TvFocusable(
                  focusNode: addProvider[i],
                  onTap: () {},
                  child: SizedBox(width: double.infinity, child: Text('Provider Row $i')),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

void main() {
  setUp(() {
    Get.reset();
  });

  group('D-pad reaches every body button', () {
    testWidgets('Provider Manager-shaped body: every focusable is on the traversal route',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final nodes = <FocusNode>[
        for (var i = 0; i < 8; i++) FocusNode(debugLabel: 'PM_$i'),
      ];

      await tester.pumpWidget(_wrap(_providerManagerLikeBody(nodes)));
      await tester.pumpAndSettle();

      // The primary CTA must be focused on open (autofocus).
      expect(
        FocusManager.instance.primaryFocus,
        nodes[0],
        reason: 'Add Provider CTA must be autofocused on open',
      );

      // Start a tab tour from the CTA using D-pad Down + Left/Right to reach each.
      // Walk Down through the search/filter row then into the list, asserting
      // every focusable is eventually highlighted (visited) via D-pad only.
      final visited = <FocusNode>{nodes[0]};

      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pump();
        final f = FocusManager.instance.primaryFocus;
        if (f != null) {
          visited.add(f);
        }
      }

      // Down: CTA -> tune filter icon.
      await press(LogicalKeyboardKey.arrowDown);
      expect(FocusManager.instance.primaryFocus, nodes[1]);
      // Right: tune -> sort.
      await press(LogicalKeyboardKey.arrowRight);
      expect(FocusManager.instance.primaryFocus, nodes[2]);
      // Down: sort -> first provider row.
      await press(LogicalKeyboardKey.arrowDown);
      expect(
        FocusManager.instance.primaryFocus,
        nodes[3],
        reason: 'Down from top bar must enter the provider list',
      );
      // Down through the rest of the rows.
      for (var i = 4; i < nodes.length; i++) {
        await press(LogicalKeyboardKey.arrowDown);
      }

      // Every focusable must have been highlighted via D-pad alone.
      expect(
        visited.length,
        nodes.length,
        reason: 'All buttons should be reachable by D-pad. Missed: ${nodes.where((n) => !visited.contains(n)).map((n) => n.debugLabel).toList()}',
      );

      for (final n in nodes) {
        n.dispose();
      }
    });

    testWidgets('home-style single welcome CTA is the only reachable target and is focused first',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cta = FocusNode(debugLabel: 'Home_CTA');

      await tester.pumpWidget(
        _wrap(
          Center(
            child: TvFocusable(
              focusNode: cta,
              autofocus: true,
              onTap: () {},
              child: const Text('Add Media Source'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(FocusManager.instance.primaryFocus, cta);
      expect(find.text('Add Media Source'), findsOneWidget);

      cta.dispose();
    });

    testWidgets('every sidebar nav item is reachable via D-pad Down/Up', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Body with one focusable so we can enter the sidebar from the body.
      final bodyCta = FocusNode(debugLabel: 'BodyCTA');
      await tester.pumpWidget(
        _wrap(
          Center(
            child: TvFocusable(
              focusNode: bodyCta,
              autofocus: true,
              onTap: () {},
              child: const Text('Body'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, bodyCta);

      // Left from body opens sidebar and focuses the ACTIVE nav item (Home).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(bodyCta.hasFocus, isFalse);

      // Home nav item should now hold focus.
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'Nav_1',
        reason: 'Left from body focuses the active sidebar nav item (Home)',
      );

      // Walk Down and Up through the sidebar; the primary focus must always
      // remain on a real nav item (never fall off the list or get stuck).
      final debugLabels = <String>{};
      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        final f = FocusManager.instance.primaryFocus;
        expect(f, isNotNull, reason: 'Down in sidebar must keep something focused');
        if (f != null) {
          expect(f.debugLabel?.startsWith('Nav_'), isTrue,
              reason: 'sidebar traversal must focus a nav item, got ${f.debugLabel}');
          debugLabels.add(f.debugLabel!);
        }
      }
      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        final f = FocusManager.instance.primaryFocus;
        expect(f, isNotNull, reason: 'Up in sidebar must keep something focused');
        if (f != null) {
          expect(f.debugLabel?.startsWith('Nav_'), isTrue,
              reason: 'sidebar traversal must focus a nav item, got ${f.debugLabel}');
        }
      }

      // We should have visited at least the top nav items (Search, Home, Live TV).
      expect(
        debugLabels.contains('Nav_1'),
        isTrue,
        reason: 'Home nav item should be visited during traversal',
      );
      expect(
        debugLabels.contains('Nav_0'),
        isTrue,
        reason: 'Search nav item should be visited during traversal',
      );

      bodyCta.dispose();
    });
  });
}