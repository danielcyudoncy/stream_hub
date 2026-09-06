import 'package:flutter_test/flutter_test.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import 'package:stream_hub/core/services/screen_awake_service.dart';

class _FakeWakelock extends WakelockPlusPlatformInterface {
  final List<bool> calls = [];
  bool current = false;

  @override
  Future<void> toggle({required bool enable}) async {
    calls.add(enable);
    current = enable;
  }

  @override
  Future<bool> get enabled async => current;
}

class _ThrowingWakelock extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {
    throw Exception('wakelock unavailable');
  }

  @override
  Future<bool> get enabled async => throw Exception('wakelock unavailable');
}

void main() {
  late _FakeWakelock fake;
  late ScreenAwakeService service;

  setUp(() {
    fake = _FakeWakelock();
    wakelockPlusPlatformInstance = fake;
    service = ScreenAwakeService();
  });

  test('keepScreenOn enables the OS wake lock', () async {
    await service.keepScreenOn();
    expect(fake.calls, [true]);
    expect(fake.current, isTrue);
    expect(service.isActive, isTrue);
  });

  test('allowScreenOff disables the OS wake lock', () async {
    await service.keepScreenOn();
    await service.allowScreenOff();
    expect(fake.calls, [true, false]);
    expect(fake.current, isFalse);
    expect(service.isActive, isFalse);
  });

  test('failures while enabling the wake lock are surfaced (not silent)',
      () async {
    wakelockPlusPlatformInstance = _ThrowingWakelock();
    final faulty = ScreenAwakeService();
    final ok = await faulty.keepScreenOn();
    expect(ok, isFalse);
    expect(faulty.isActive, isFalse);
    expect(faulty.lastAcquireFailed, isTrue);
  });

  test('reference counting only releases the wake lock when last claim is '
      'released', () async {
    await service.acquire(owner: 'A');
    await service.acquire(owner: 'B');
    expect(fake.calls, [true]);
    await service.release(owner: 'A');
    expect(fake.calls, [true]); // still held by B
    expect(service.isActive, isTrue);
    await service.release(owner: 'B');
    expect(fake.calls, [true, false]);
    expect(service.isActive, isFalse);
  });

  test('extra releases beyond the count are clamped at zero', () async {
    await service.release(owner: 'ghost');
    await service.release(owner: 'ghost');
    expect(service.isActive, isFalse);
    expect(fake.calls, isEmpty);
  });

  test('setEnabled(true) acquires; setEnabled(false) releases', () async {
    await service.setEnabled(true, owner: 'toggle');
    expect(fake.calls, [true]);
    await service.setEnabled(false, owner: 'toggle');
    expect(fake.calls, [true, false]);
  });

  test('setEnabled(true) called twice does not toggle the platform twice',
      () async {
    await service.setEnabled(true, owner: 'X');
    await service.setEnabled(true, owner: 'Y');
    expect(fake.calls, [true]);
  });
}