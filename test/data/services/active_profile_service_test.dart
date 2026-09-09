import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/services/active_profile_service.dart';

void main() {
  group('ActiveProfileService', () {
    late ActiveProfileService service;

    setUp(() {
      Get.reset();
      Get.put<LoggingService>(LoggingService());
      service = ActiveProfileService();
    });

    tearDown(() {
      Get.reset();
    });

    test('initial state has empty profileId and hasActiveProfile is false', () {
      expect(service.currentProfileId, equals(''));
      expect(service.hasActiveProfile, isFalse);
    });

    test('setActiveProfile updates profileId and hasActiveProfile', () {
      service.setActiveProfile('prof_123');
      expect(service.currentProfileId, equals('prof_123'));
      expect(service.hasActiveProfile, isTrue);
    });

    test('setActiveProfile does not notify or change if setting identical id', () {
      service.setActiveProfile('prof_123');
      var callCount = 0;
      service.profileId.listen((_) => callCount++);

      service.setActiveProfile('prof_123');
      expect(callCount, equals(0));
    });

    test('clearActiveProfile resets profileId to empty string', () {
      service.setActiveProfile('prof_123');
      expect(service.hasActiveProfile, isTrue);

      service.clearActiveProfile();
      expect(service.currentProfileId, equals(''));
      expect(service.hasActiveProfile, isFalse);
    });
  });
}
