import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:stream_hub/core/constants/app_constants.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/services/free_tv_slot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FreeTvSlotService service;

  setUp(() async {
    Get.reset();
    Get.put<LoggingService>(LoggingService());

    tempDir = await Directory.systemTemp.createTemp('free_tv_slot_test_');
    Hive.init(tempDir.path);
    await Hive.openBox(AppConstants.boxFreeTvSlots);

    service = FreeTvSlotService();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    Get.reset();
  });

  group('FreeTvSlotService', () {
    test('initial state has 0 used slots and 10 remaining slots', () {
      expect(service.usedSlots, equals(0));
      expect(service.remainingSlots, equals(10));
      expect(service.isFull, isFalse);
      expect(service.selectedChannelIds, isEmpty);
    });

    test('addChannel adds channels up to max limit (10)', () async {
      for (int i = 1; i <= 10; i++) {
        final added = await service.addChannel('channel_$i');
        expect(added, isTrue);
        expect(service.usedSlots, equals(i));
        expect(service.remainingSlots, equals(10 - i));
        expect(service.isChannelSelected('channel_$i'), isTrue);
      }

      expect(service.isFull, isTrue);

      // Attempting to add 11th channel should fail
      final addedEleventh = await service.addChannel('channel_11');
      expect(addedEleventh, isFalse);
      expect(service.usedSlots, equals(10));
      expect(service.isChannelSelected('channel_11'), isFalse);
    });

    test('addChannel does not duplicate if channel already selected', () async {
      await service.addChannel('channel_1');
      expect(service.usedSlots, equals(1));

      final addedAgain = await service.addChannel('channel_1');
      expect(addedAgain, isTrue);
      expect(service.usedSlots, equals(1));
    });

    test('isChannelUnlocked returns true only for selected channels when not VIP', () async {
      await service.addChannel('channel_1');
      await service.addChannel('channel_2');

      expect(service.isChannelUnlocked('channel_1'), isTrue);
      expect(service.isChannelUnlocked('channel_2'), isTrue);
      expect(service.isChannelUnlocked('channel_3'), isFalse);
    });

    test('isChannelUnlocked returns true for ALL channels when VIP is active', () async {
      service.isVipActive.value = true;

      expect(service.isVip, isTrue);
      expect(service.isGatingActive, isFalse);
      expect(service.isChannelUnlocked('channel_unselected_999'), isTrue);
    });

    test('removeChannel frees up a slot', () async {
      await service.addChannel('channel_1');
      await service.addChannel('channel_2');
      expect(service.usedSlots, equals(2));

      await service.removeChannel('channel_1');
      expect(service.usedSlots, equals(1));
      expect(service.isChannelSelected('channel_1'), isFalse);
      expect(service.isChannelSelected('channel_2'), isTrue);
      expect(service.remainingSlots, equals(9));
    });

    test('swapChannel replaces an existing channel in-place', () async {
      await service.addChannel('channel_1');
      await service.addChannel('channel_2');

      final swapped = await service.swapChannel(
        oldChannelId: 'channel_1',
        newChannelId: 'channel_replacement',
      );

      expect(swapped, isTrue);
      expect(service.usedSlots, equals(2));
      expect(service.isChannelSelected('channel_1'), isFalse);
      expect(service.isChannelSelected('channel_replacement'), isTrue);
    });

    test('clearAll resets all slots', () async {
      for (int i = 1; i <= 5; i++) {
        await service.addChannel('ch_$i');
      }
      expect(service.usedSlots, equals(5));

      await service.clearAll();
      expect(service.usedSlots, equals(0));
      expect(service.remainingSlots, equals(10));
      expect(service.selectedChannelIds, isEmpty);
    });
  });
}
