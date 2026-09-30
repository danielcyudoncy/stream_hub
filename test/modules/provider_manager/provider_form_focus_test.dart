import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/helpers/platform_helper.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_enums.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_model.dart';
import 'package:stream_hub/modules/provider_manager/provider_form_page.dart';
import 'package:stream_hub/modules/provider_manager/provider_manager_controller.dart';

class _FakeProviderManagerController extends GetxController
    implements ProviderManagerController {
  @override
  final RxList<ProviderModel> providers = <ProviderModel>[].obs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    Get.reset();
    Get.put<ProviderManagerController>(_FakeProviderManagerController());
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
    'Notes field D-pad Down navigates to Scan to Add and escapes multiline trap',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ProviderFormPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Notes text field
      final notesFinder = find.ancestor(
        of: find.text('Notes'),
        matching: find.byType(TextFormField),
      );
      expect(notesFinder, findsOneWidget);

      // Focus the Notes field
      await tester.tap(notesFinder);
      await tester.pumpAndSettle();


      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_notes_field'),
      );

      // Press D-pad Down from Notes
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Focus should now have escaped to 'Scan to Add'
      expect(find.text('Scan to Add'), findsOneWidget);

      final primaryFocus = tester.binding.focusManager.primaryFocus;
      expect(primaryFocus?.debugLabel, equals('provider_scan_to_add_button'));

      // Press D-pad Up from 'Scan to Add' -> moves back up to Notes
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_notes_field'),
      );

      // Press D-pad Down back to 'Scan to Add'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_scan_to_add_button'),
      );

      // Press D-pad Left from 'Scan to Add' -> moves to 'Cancel'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_cancel_button'),
      );

      // Press D-pad Right from 'Cancel' -> moves back to 'Scan to Add'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_scan_to_add_button'),
      );

      // Press D-pad Right from 'Scan to Add' -> moves to 'Add Link'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_submit_button'),
      );
    },
  );

  testWidgets(
    'Edit Provider mode: Notes field D-pad Down navigates to Save Changes button',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testProvider = ProviderModel(
        id: 'p1',
        name: 'Existing Provider',
        providerType: ProviderType.m3u,
        serverUrl: 'http://example.com/playlist.m3u',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ProviderFormPage(provider: testProvider),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final notesFinder = find.ancestor(
        of: find.text('Notes'),
        matching: find.byType(TextFormField),
      );
      expect(notesFinder, findsOneWidget);

      await tester.tap(notesFinder);
      await tester.pumpAndSettle();

      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_notes_field'),
      );

      // Press D-pad Down from Notes in edit mode
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_submit_button'),
      );
    },
  );

  testWidgets(
    'TV mode: Notes field is readOnly until Select key is pressed and allows Up/Down navigation',
    (tester) async {
      PlatformHelper.forceTvMode = true;
      addTearDown(() => PlatformHelper.forceTvMode = false);

      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ProviderFormPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final notesFinder = find.ancestor(
        of: find.text('Notes'),
        matching: find.byType(TextFormField),
      );
      expect(notesFinder, findsOneWidget);

      // Verify TextField is readOnly initially in TV mode to suppress keyboard popup
      final textFieldFinder = find.descendant(
        of: notesFinder,
        matching: find.byType(TextField),
      );
      final initialField = tester.widget<TextField>(textFieldFinder);
      expect(initialField.readOnly, isTrue);

      // Focus Notes via focusNode.requestFocus() (mimicking remote D-pad arrival without touch tap)
      tester.widget<TextField>(textFieldFinder).focusNode!.requestFocus();
      await tester.pumpAndSettle();

      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_notes_field'),
      );

      // Notes is focused but still readOnly (keyboard not popped)
      final focusedField = tester.widget<TextField>(textFieldFinder);
      expect(focusedField.readOnly, isTrue);

      // Press D-pad Down -> navigates out to Scan to Add immediately
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_scan_to_add_button'),
      );

      // Press D-pad Up -> navigates back to Notes
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_notes_field'),
      );

      // Press Select/OK on remote -> activates edit mode
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      final editingField = tester.widget<TextField>(textFieldFinder);
      expect(editingField.readOnly, isFalse);

      // Pressing D-pad Down while in edit mode exits edit mode and navigates to Scan to Add
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_scan_to_add_button'),
      );
    },
  );
}
