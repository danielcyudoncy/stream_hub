import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/profile_model.dart';
import 'package:stream_hub/data/models/settings_model.dart';
import 'package:stream_hub/data/repositories/profile_repository.dart';
import 'package:stream_hub/data/repositories/settings_repository.dart';
import 'package:stream_hub/data/services/active_profile_service.dart';
import 'package:stream_hub/data/services/profile_service.dart';
import 'package:stream_hub/data/services/settings_service.dart';
import 'package:stream_hub/data/services/cache_service.dart';
import 'package:stream_hub/modules/profiles/profile_controller.dart';
import 'package:stream_hub/modules/profiles/profile_page.dart';
import 'package:stream_hub/modules/settings/settings_controller.dart';

class _FakeProfileRepository implements ProfileRepository {
  final List<ProfileModel> _profiles = [];

  _FakeProfileRepository([List<ProfileModel>? initial]) {
    if (initial != null) _profiles.addAll(initial);
  }

  @override
  Future<List<ProfileModel>> getAllProfiles() async => List.of(_profiles);

  @override
  Future<ProfileModel?> getProfileById(String id) async =>
      _profiles.firstWhereOrNull((p) => p.id == id);

  @override
  Future<ProfileModel> createProfile(ProfileModel profile) async {
    _profiles.add(profile);
    return profile;
  }

  @override
  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    final idx = _profiles.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) _profiles[idx] = profile;
    return profile;
  }

  @override
  Future<void> deleteProfile(String id) async {
    _profiles.removeWhere((p) => p.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettingsRepository implements SettingsRepository {
  String? activeProfileId;
  String language = 'en';
  String themeMode = 'system';

  Future<String?> getActiveProfileId() async => activeProfileId;

  @override
  Future<void> updateActiveProfileId(String? id) async => activeProfileId = id;

  @override
  Future<void> updateLanguage(String lang) async => language = lang;

  @override
  Future<void> updateThemeMode(String mode) async => themeMode = mode;

  @override
  Future<SettingsModel?> getSettings() async => SettingsModel(
        id: 'settings',
        language: language,
        themeMode: themeMode,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  @override
  Future<SettingsModel> saveSettings(SettingsModel settings) async {
    language = settings.language;
    themeMode = settings.themeMode;
    return settings;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeProfileRepository fakeProfileRepo;
  late _FakeSettingsRepository fakeSettingsRepo;
  late ProfileService profileService;
  late SettingsService settingsService;

  setUp(() {
    Get.reset();
    Get.put<LoggingService>(LoggingService());

    fakeProfileRepo = _FakeProfileRepository([
      ProfileModel(
        id: 'p1',
        displayName: 'Profile 1',
        photoUrl: '0',
        language: 'en',
        themeMode: 'system',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ProfileModel(
        id: 'p2',
        displayName: 'Profile 2',
        photoUrl: '1',
        language: 'fr',
        themeMode: 'dark',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);
    profileService = ProfileService(fakeProfileRepo);
    fakeSettingsRepo = _FakeSettingsRepository();
    settingsService = SettingsService(fakeSettingsRepo);

    Get.put<ProfileService>(profileService);
    Get.put<SettingsService>(settingsService);

    final activeService = ActiveProfileService();
    Get.put<ActiveProfileService>(activeService);

    final settingsCtrl = SettingsController(
      settingsService: settingsService,
      profileService: profileService,
      cacheService: CacheService(fakeSettingsRepo),
    );
    Get.put<SettingsController>(settingsCtrl);

    final profileCtrl = ProfileController(
      profileService: profileService,
      settingsService: settingsService,
    );
    Get.put<ProfileController>(profileCtrl);
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('renders ProfilePage and displays profiles', (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        home: ProfilePage(),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.text('Your Profiles'), findsOneWidget);
    expect(find.text('Profile 1'), findsNWidgets(2)); // Chip and edit text field
    expect(find.text('Profile 2'), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
  });

  testWidgets('selecting another profile updates active profile, text, and theme', (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        home: ProfilePage(),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    // Tap on Profile 2 chip
    await tester.tap(find.text('Profile 2'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    final profileCtrl = Get.find<ProfileController>();
    final settingsCtrl = Get.find<SettingsController>();

    expect(profileCtrl.activeProfile.value?.displayName, 'Profile 2');
    expect(settingsCtrl.themeMode.value, ThemeMode.dark);
    expect(find.text('Profile 2'), findsNWidgets(2)); // Chip + TextField
  });

  testWidgets('tapping an avatar updates photoUrl immediately', (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        home: ProfilePage(),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    final profileCtrl = Get.find<ProfileController>();
    expect(profileCtrl.photoUrl.value, '0');

    // Tap on a preset circle avatar in the avatar picker
    final circleAvatars = find.byType(CircleAvatar);
    expect(circleAvatars, findsWidgets);

    // Tap one of the avatar presets
    await tester.tap(circleAvatars.at(3));
    await tester.pump();

    // photoUrl should immediately update
    expect(profileCtrl.photoUrl.value.isNotEmpty, isTrue);
  });

  testWidgets('TV D-pad can enter and exit display name text field without getting stuck', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const GetMaterialApp(
        home: ProfilePage(),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.text('Enter your display name (Press OK to edit)'), findsOneWidget);

    final tileFinder = find.byWidgetPredicate(
      (w) => w is TvFocusable && w.focusNode?.debugLabel == 'Profile_DisplayName_Tile',
    );
    expect(tileFinder, findsOneWidget);

    final tile = tester.widget<TvFocusable>(tileFinder);
    tile.focusNode!.requestFocus();
    await tester.pump();
    expect(tile.focusNode!.hasFocus, isTrue);

    // Tap tile to enter editing
    await tester.tap(tileFinder);
    await tester.pump();

    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);
    final textField = tester.widget<TextField>(textFieldFinder);
    expect(textField.focusNode?.hasFocus, isTrue);

    // Press ArrowDown to navigate down and exit editing
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(textField.focusNode?.hasFocus, isFalse);
  });
}
