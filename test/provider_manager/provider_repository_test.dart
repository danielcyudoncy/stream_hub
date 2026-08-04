import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/data/services/database_service.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_enums.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProviderRepository persistence', () {
    late Directory tempDir;
    late ProviderRepository repository;

    setUp(() async {
      Get.reset();
      tempDir = await Directory.systemTemp.createTemp('provider_repo_test');
      Hive.init(tempDir.path);
      Get.put(LoggingService());
      Get.put(await Get.put(DatabaseService()).init());
      repository = Get.put(ProviderRepository());
    });

    tearDown(() async {
      await Hive.close();
      await Hive.deleteFromDisk();
      await tempDir.delete(recursive: true);
      Get.reset();
    });

    test('persists and restores account metadata fields', () async {
      final original = ProviderModel(
        id: 'p1',
        name: 'My Panel',
        providerType: ProviderType.xtream,
        serverUrl: 'http://panel.example:80',
        username: 'user',
        password: 'pass',
        createdAt: DateTime(2026, 7, 1, 10, 30),
        updatedAt: DateTime(2026, 7, 2, 11, 0),
        lastSync: DateTime(2026, 7, 3, 12, 0),
        status: ProviderStatus.active,
        accountCreatedAt: DateTime.fromMillisecondsSinceEpoch(1783507521000),
        accountExpiresAt: DateTime.fromMillisecondsSinceEpoch(1817721921000),
        accountStatus: 'Active',
        accountIsTrial: false,
        accountMaxConnections: 1,
      );

      await repository.createProvider(original);

      final restored = await repository.getProviderById('p1');
      expect(restored, isNotNull);
      expect(restored!.accountCreatedAt,
          DateTime.fromMillisecondsSinceEpoch(1783507521000));
      expect(restored.accountExpiresAt,
          DateTime.fromMillisecondsSinceEpoch(1817721921000));
      expect(restored.accountStatus, 'Active');
      expect(restored.accountIsTrial, isFalse);
      expect(restored.accountMaxConnections, 1);
      expect(restored.providerType, ProviderType.xtream);
      expect(restored.status, ProviderStatus.active);
    });

    test('restores legacy providers without account fields as null', () async {
      final legacy = ProviderModel(
        id: 'legacy',
        name: 'Old Playlist',
        providerType: ProviderType.m3u,
        createdAt: DateTime(2026, 6, 1, 8, 0),
        updatedAt: DateTime(2026, 6, 2, 9, 0),
        status: ProviderStatus.active,
      );

      await repository.createProvider(legacy);

      final restored = await repository.getProviderById('legacy');
      expect(restored, isNotNull);
      expect(restored!.id, 'legacy');
      expect(restored.providerType, ProviderType.m3u);
      expect(restored.accountCreatedAt, isNull);
      expect(restored.accountExpiresAt, isNull);
      expect(restored.accountStatus, isNull);
      expect(restored.accountIsTrial, isNull);
      expect(restored.accountMaxConnections, isNull);
    });
  });
}
