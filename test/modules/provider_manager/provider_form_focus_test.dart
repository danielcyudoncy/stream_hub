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

  testWidgets(
    'TV mode: Name and Server URL fields are readOnly until Select, and full D-pad chain works',
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

      // On launch in TV mode, Name field is autofocused
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_name_field'),
      );

      // Verify Name field is readOnly (no keyboard pop)
      final nameFinder = find.ancestor(
        of: find.text('Provider Name'),
        matching: find.byType(TextFormField),
      );
      final nameTextField = tester.widget<TextField>(
        find.descendant(of: nameFinder, matching: find.byType(TextField)),
      );
      expect(nameTextField.readOnly, isTrue);

      // Press D-pad Down -> moves to M3U ChoiceChip
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_type_m3u'),
      );

      // Press D-pad Right -> moves to Xtream ChoiceChip
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_type_xtream'),
      );

      // Press D-pad Up -> moves back to Provider Name
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_name_field'),
      );

      // Press Select on Provider Name -> enters edit mode
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      final editingName = tester.widget<TextField>(
        find.descendant(of: nameFinder, matching: find.byType(TextField)),
      );
      expect(editingName.readOnly, isFalse);

      // Press D-pad Down while editing Name -> exits edit mode and moves to M3U chip
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_type_m3u'),
      );

      // Press D-pad Down from chip -> moves to Server URL
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_server_url_field'),
      );

      // Verify Server URL is readOnly
      final serverFinder = find.ancestor(
        of: find.text('Server URL'),
        matching: find.byType(TextFormField),
      );
      final serverTextField = tester.widget<TextField>(
        find.descendant(of: serverFinder, matching: find.byType(TextField)),
      );
      expect(serverTextField.readOnly, isTrue);

      // Press D-pad Down from Server URL -> moves to Notes
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_notes_field'),
      );

      // Press D-pad Up from Notes -> moves back to Server URL
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_server_url_field'),
      );
    },
  );

  testWidgets(
    'TV mode: Xtream provider type reveals Username and Password in D-pad chain',
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

      // Navigate down to M3U chip
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Navigate right to Xtream chip and select it
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_type_xtream'),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      // Navigate down to Server URL
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_server_url_field'),
      );

      // Navigate down to Username
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_username_field'),
      );

      // Navigate down to Password
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_password_field'),
      );

      // Navigate down to Notes
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_notes_field'),
      );

      // Navigate up back to Password
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('provider_password_field'),
      );
    },
  );
}
