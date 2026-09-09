import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/services/cloud_sync_service.dart';

// ---------------------------------------------------------------------------
// These tests exercise CloudSyncService behaviour that does NOT require a
// real Hive Box, Firebase, or network connection.  The databaseService
// parameter is left null so that _effectiveDb returns null and all storage
// calls are silently skipped – matching the offline-first safety contract.
// ---------------------------------------------------------------------------
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    Get.put<LoggingService>(LoggingService());
  });

  tearDown(() {
    Get.reset();
  });

  group('CloudSyncService Unit Tests', () {
    test('initial state is disabled by default per privacy policy', () {
      // No DB → defaults are read from _initFromStorage which no-ops.
      final service = CloudSyncService();

      expect(service.isCloudSyncEnabled, isFalse);
      expect(service.isSyncing, isFalse);
      expect(service.lastSyncTime, isNull);
      expect(service.syncStatusMessage, isEmpty);
    });

    test('syncAll is a no-op when cloud sync is disabled', () async {
      final service = CloudSyncService();
      await service.syncAll();

      // Must remain idle – nothing written, nothing fetched.
      expect(service.isSyncing, isFalse);
      expect(service.lastSyncTime, isNull);
    });

    test('syncAll(force: true) exits early when no authenticated user', () async {
      // force=true bypasses the "enabled" gate but uid is still null,
      // so the method should log a debug message and return without throwing.
      final service = CloudSyncService();
      await expectLater(service.syncAll(force: true), completes);
      expect(service.isSyncing, isFalse);
      expect(service.lastSyncTime, isNull);
    });

    test('schedulePush is a no-op when cloud sync is disabled', () {
      final service = CloudSyncService();
      // Should not throw even when called multiple times.
      service.schedulePush();
      service.schedulePush();
      service.schedulePush();
      expect(service.isSyncing, isFalse);
    });

    test('disabling via setCloudSyncEnabled(false) returns true without auth',
        () async {
      final service = CloudSyncService();
      // Disable when already disabled – should succeed gracefully.
      final result = await service.setCloudSyncEnabled(false);
      expect(result, isTrue);
      expect(service.isCloudSyncEnabled, isFalse);
    });

    test('enabling via setCloudSyncEnabled(true) returns false when not authenticated',
        () async {
      // No FirebaseAuth → currentUser is null → enabling should fail.
      final service = CloudSyncService();
      final result = await service.setCloudSyncEnabled(true);
      expect(result, isFalse);
      expect(service.isCloudSyncEnabled, isFalse);
    });

    test('isSyncingRx, lastSyncTimeRx, and syncStatusMessageRx are observable',
        () {
      final service = CloudSyncService();
      expect(service.isSyncingRx, isA<RxBool>());
      expect(service.lastSyncTimeRx, isA<Rxn<DateTime>>());
      expect(service.syncStatusMessageRx, isA<RxString>());
    });
  });
}
