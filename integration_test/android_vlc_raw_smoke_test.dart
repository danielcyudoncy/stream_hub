import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Debug isolation test: raw flutter_vlc_player flow (no StreamHub adapter).
/// Mounts the [VlcPlayer] widget with a controller, waits for the platform
/// view to report ready, then calls initialize().
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'raw VlcPlayer mounts, reports ready and initializes',
    (tester) async {
      final controller = VlcPlayerController.network(
        'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        autoPlay: true,
        autoInitialize: false,
        hwAcc: HwAcc.auto,
        allowBackgroundPlayback: false,
      );
      addTearDown(() async {
        try {
          await controller.dispose();
        } catch (e) {
          debugPrint('RAW dispose error: $e');
        }
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ColoredBox(
            color: Colors.black,
            child: Center(
              child: VlcPlayer(
                controller: controller,
                aspectRatio: 16 / 9,
                placeholder: Container(color: const Color(0xFF000000)),
              ),
            ),
          ),
        ),
      );

      var ready = false;
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (!ready && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 250));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        ready = controller.isReadyToInitialize == true;
      }
      debugPrint('RAW isReadyToInitialize=$ready viewId=${controller.viewId}');

      await controller.initialize();
      debugPrint('RAW initialize() completed');

      final engaged = await _pumpUntil(
        tester,
        'value.isInitialized',
        () => controller.value.isInitialized,
        timeout: const Duration(seconds: 15),
      );
      debugPrint('RAW initialized=$engaged '
          'playing=${controller.value.isPlaying} '
          'state=${controller.value.playingState}');
      expect(engaged, isTrue,
          reason: 'native VLC must initialize after the platform view mounts');
    },
  );
}

Future<bool> _pumpUntil(
  WidgetTester tester,
  String description,
  FutureOr<bool> Function() condition, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) {
      debugPrint('RAW condition met: $description');
      return true;
    }
    await tester.pump(const Duration(milliseconds: 250));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  debugPrint('RAW timeout waiting for: $description');
  return false;
}
