import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/services/device_environment_service.dart';
import 'package:stream_hub/modules/player/widgets/player_touch_gesture_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DeviceEnvironmentService().resetForTesting();
  });

  tearDown(() {
    DeviceEnvironmentService().resetForTesting();
  });

  group('PlayerTouchGestureOverlay Unit & Widget Tests', () {
    testWidgets('renders child and controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: PlayerTouchGestureOverlay(
                controls: const Text('ControlsOverlay'),
                child: const Text('VideoChild'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('VideoChild'), findsOneWidget);
      expect(find.text('ControlsOverlay'), findsOneWidget);
    });

    testWidgets('triggers onTap callback on single tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: PlayerTouchGestureOverlay(
                onTap: () => tapped = true,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('vertical drag on right side triggers onVolumeChanged', (tester) async {
      double? changedVolume;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: PlayerTouchGestureOverlay(
                initialVolume: 0.5,
                onVolumeChanged: (vol) => changedVolume = vol,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(PlayerTouchGestureOverlay)) as dynamic;
      const constraints = BoxConstraints(maxWidth: 400, maxHeight: 300);

      // Call start on right side (x = 300, y = 150)
      state.onVerticalDragStart(
        DragStartDetails(localPosition: const Offset(300, 150)),
        constraints,
      );
      // Call update (drag upwards to y = 50, deltaY = 100)
      state.onVerticalDragUpdate(
        DragUpdateDetails(
          delta: const Offset(0, -100),
          localPosition: const Offset(300, 50),
          globalPosition: const Offset(300, 50),
        ),
        constraints,
      );
      state.onVerticalDragEnd(DragEndDetails());
      await tester.pump();

      expect(changedVolume, isNotNull);
      expect(changedVolume!, greaterThan(0.5));
    });

    testWidgets('vertical drag on left side triggers onBrightnessChanged', (tester) async {
      double? changedBrightness;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: PlayerTouchGestureOverlay(
                initialBrightness: 0.5,
                onBrightnessChanged: (b) => changedBrightness = b,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(PlayerTouchGestureOverlay)) as dynamic;
      const constraints = BoxConstraints(maxWidth: 400, maxHeight: 300);

      // Call start on left side (x = 100, y = 150)
      state.onVerticalDragStart(
        DragStartDetails(localPosition: const Offset(100, 150)),
        constraints,
      );
      // Call update (drag upwards to y = 50, deltaY = 100)
      state.onVerticalDragUpdate(
        DragUpdateDetails(
          delta: const Offset(0, -100),
          localPosition: const Offset(100, 50),
          globalPosition: const Offset(100, 50),
        ),
        constraints,
      );
      state.onVerticalDragEnd(DragEndDetails());
      await tester.pump();

      expect(changedBrightness, isNotNull);
      expect(changedBrightness!, greaterThan(0.5));
    });
  });

  group('DeviceEnvironmentService Unit Tests', () {
    test('setVolume clamps and caches volume correctly', () async {
      final service = DeviceEnvironmentService();
      await service.setVolume(1.5);
      expect(await service.getVolume(), equals(1.0));

      await service.setVolume(-0.5);
      expect(await service.getVolume(), equals(0.0));

      await service.setVolume(0.42);
      expect(await service.getVolume(), equals(0.42));
    });

    test('setBrightness clamps and caches brightness correctly', () async {
      final service = DeviceEnvironmentService();
      await service.setBrightness(1.5);
      expect(await service.getBrightness(), equals(1.0));

      await service.setBrightness(-0.5);
      // Brightness minimum clamp is 0.01
      expect(await service.getBrightness(), equals(0.01));

      await service.setBrightness(0.75);
      expect(await service.getBrightness(), equals(0.75));
    });

    test('brightness claims tracking releases cleanly', () async {
      final service = DeviceEnvironmentService();
      service.acquireBrightnessClaim();
      service.acquireBrightnessClaim();
      await service.releaseBrightnessClaim();
      // Still 1 claim remaining, should not fail or throw
      await service.releaseBrightnessClaim();
      // Hits 0, restores system default
      await service.releaseBrightnessClaim(); // Edge case: underflow protection
    });
  });
}
