import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/services/parental_control_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/settings_model.dart';
import 'package:stream_hub/data/repositories/settings_repository.dart';
import 'package:stream_hub/data/services/settings_service.dart';

class _FakeSettingsService extends SettingsService {
  SettingsModel currentSettings;

  _FakeSettingsService(this.currentSettings) : super(_DummySettingsRepository());

  @override
  Future<SettingsModel> loadSettings() async {
    return currentSettings;
  }

  @override
  Future<void> updateParentalLock({required bool enabled, String? hashedPin}) async {
    currentSettings = currentSettings.copyWith(
      parentalLockEnabled: enabled,
      parentalPin: hashedPin ?? currentSettings.parentalPin,
      updatedAt: DateTime.now(),
    );
  }
}

class _DummySettingsRepository implements SettingsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSettingsService fakeSettingsService;
  late SettingsModel initialSettings;

  setUp(() {
    Get.reset();
    Get.put<LoggingService>(LoggingService());

    final now = DateTime.now();
    initialSettings = SettingsModel(
      id: 'default',
      parentalLockEnabled: false,
      parentalPin: null,
      createdAt: now,
      updatedAt: now,
    );
    fakeSettingsService = _FakeSettingsService(initialSettings);
  });

  tearDown(() {
    Get.reset();
  });

  group('ParentalControlService Unit Tests', () {
    test('SHA-256 PIN hashing is deterministic and irreversible (64 hex chars)', () {
      final hash1 = ParentalControlService.hashPin('1234');
      final hash2 = ParentalControlService.hashPin('1234');
      final hashDifferent = ParentalControlService.hashPin('4321');

      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals('1234')));
      expect(hash1.length, equals(64));
      expect(hash1, isNot(equals(hashDifferent)));
    });

    test('Initial state: unlocked when parentalLockEnabled is false', () {
      final service = ParentalControlService(
        settingsService: fakeSettingsService,
        initialSettings: initialSettings,
      );

      expect(service.isParentalLockEnabled, isFalse);
      expect(service.isUnlocked, isTrue);
      expect(service.isLocked, isFalse);
      expect(service.remainingGracePeriod, isNull);
    });

    test('Setting a new PIN hashes it and enables parental lock', () async {
      final service = ParentalControlService(
        settingsService: fakeSettingsService,
        initialSettings: initialSettings,
      );

      final success = await service.setPin('1234');
      expect(success, isTrue);

      expect(service.isParentalLockEnabled, isTrue);
      expect(fakeSettingsService.currentSettings.parentalLockEnabled, isTrue);
      expect(
        fakeSettingsService.currentSettings.parentalPin,
        equals(ParentalControlService.hashPin('1234')),
      );
      // Immediately after setting, user is unlocked for grace period
      expect(service.isUnlocked, isTrue);
    });

    test('Validating correct PIN unlocks the service; wrong PIN fails and keeps locked', () async {
      final hashed = ParentalControlService.hashPin('5678');
      fakeSettingsService.currentSettings = fakeSettingsService.currentSettings.copyWith(
        parentalLockEnabled: true,
        parentalPin: hashed,
      );

      final service = ParentalControlService(
        settingsService: fakeSettingsService,
        initialSettings: fakeSettingsService.currentSettings,
      );

      // Initially locked
      expect(service.isLocked, isTrue);

      // Wrong PIN
      final wrongResult = await service.validatePin('0000');
      expect(wrongResult, isFalse);
      expect(service.isLocked, isTrue);

      // Correct PIN
      final correctResult = await service.validatePin('5678');
      expect(correctResult, isTrue);
      expect(service.isUnlocked, isTrue);
      expect(service.remainingGracePeriod, isNotNull);
      expect(service.remainingGracePeriod!.inMinutes, lessThanOrEqualTo(5));
    });

    test('Calling lock() immediately clears grace period and engages lock', () async {
      final hashed = ParentalControlService.hashPin('1111');
      fakeSettingsService.currentSettings = fakeSettingsService.currentSettings.copyWith(
        parentalLockEnabled: true,
        parentalPin: hashed,
      );

      final service = ParentalControlService(
        settingsService: fakeSettingsService,
        initialSettings: fakeSettingsService.currentSettings,
      );

      await service.validatePin('1111');
      expect(service.isUnlocked, isTrue);

      service.lock();
      expect(service.isLocked, isTrue);
      expect(service.remainingGracePeriod, isNull);
    });

    test('Changing PIN requires valid current PIN first', () async {
      final hashed = ParentalControlService.hashPin('1234');
      fakeSettingsService.currentSettings = fakeSettingsService.currentSettings.copyWith(
        parentalLockEnabled: true,
        parentalPin: hashed,
      );

      final service = ParentalControlService(
        settingsService: fakeSettingsService,
        initialSettings: fakeSettingsService.currentSettings,
      );

      // Attempt change with invalid current PIN
      final failResult = await service.changePin(
        currentPin: '9999',
        newPin: '5678',
      );
      expect(failResult, isFalse);
      expect(
        fakeSettingsService.currentSettings.parentalPin,
        equals(hashed),
      );

      // Attempt change with valid current PIN
      final successResult = await service.changePin(
        currentPin: '1234',
        newPin: '5678',
      );
      expect(successResult, isTrue);
      expect(
        fakeSettingsService.currentSettings.parentalPin,
        equals(ParentalControlService.hashPin('5678')),
      );
    });

    test('Disabling parental lock requires valid current PIN', () async {
      final hashed = ParentalControlService.hashPin('4321');
      fakeSettingsService.currentSettings = fakeSettingsService.currentSettings.copyWith(
        parentalLockEnabled: true,
        parentalPin: hashed,
      );

      final service = ParentalControlService(
        settingsService: fakeSettingsService,
        initialSettings: fakeSettingsService.currentSettings,
      );

      // Wrong PIN cannot disable
      final fail = await service.disableParentalLock('0000');
      expect(fail, isFalse);
      expect(service.isParentalLockEnabled, isTrue);

      // Correct PIN disables lock
      final success = await service.disableParentalLock('4321');
      expect(success, isTrue);
      expect(service.isParentalLockEnabled, isFalse);
      expect(fakeSettingsService.currentSettings.parentalLockEnabled, isFalse);
    });

    test('isContentRestricted detects mature / adult content markers', () {
      final hashed = ParentalControlService.hashPin('1234');
      fakeSettingsService.currentSettings = fakeSettingsService.currentSettings.copyWith(
        parentalLockEnabled: true,
        parentalPin: hashed,
      );

      final service = ParentalControlService(
        settingsService: fakeSettingsService,
        initialSettings: fakeSettingsService.currentSettings,
      );

      final normalItem = MediaItem(
        id: '1',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.movie,
        title: 'Family Movie',
        genres: ['Family', 'Animation'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final adultGenreItem = MediaItem(
        id: '2',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.movie,
        title: 'Late Night Feature',
        genres: ['Adult', 'Drama'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final mpaaItem = MediaItem(
        id: '3',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.movie,
        title: 'Intense Action',
        genres: ['Action'],
        metadata: {'rating_mpaa': 'TV-MA'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final adultFlagItem = MediaItem(
        id: '4',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.movie,
        title: 'Restricted Title',
        metadata: {'adult': true},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(service.isContentRestricted(normalItem), isFalse);
      expect(service.isContentRestricted(adultGenreItem), isTrue);
      expect(service.isContentRestricted(mpaaItem), isTrue);
      expect(service.isContentRestricted(adultFlagItem), isTrue);
    });
  });
}
