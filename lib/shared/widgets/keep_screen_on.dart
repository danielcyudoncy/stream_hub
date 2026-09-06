import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../core/services/screen_awake_service.dart';

/// Keeps the device screen on while this widget is mounted.
///
/// Wraps any subtree (typically a `PlayerAdapter.buildPlayerWidget()` result)
/// in a reference-counted acquisition of the shared [ScreenAwakeService] wake
/// lock. Multiple [KeepScreenOn] widgets stack correctly thanks to the
/// reference count inside the service, so a movie page + mini player can
/// both claim the lock without one teardown releasing it while the other is
/// still playing.
///
/// The widget is intentionally a no-op when [ScreenAwakeService] is not
/// registered with GetX (e.g. in unit tests that do not bootstrap the app
/// bindings). In production `ScreenAwakeService` is registered as a permanent
/// service in `main.dart`, so the lock is always engaged.
class KeepScreenOn extends StatefulWidget {
  final Widget child;

  const KeepScreenOn({super.key, required this.child});

  @override
  State<KeepScreenOn> createState() => _KeepScreenOnState();
}

class _KeepScreenOnState extends State<KeepScreenOn> {
  bool _acquired = false;

  @override
  void initState() {
    super.initState();
    _ensureAcquired();
  }

  Future<void> _ensureAcquired() async {
    if (!Get.isRegistered<ScreenAwakeService>()) return;
    final ok = await Get.find<ScreenAwakeService>()
        .acquire(owner: 'KeepScreenOn');
    if (!mounted) {
      if (ok) {
        await Get.find<ScreenAwakeService>()
            .release(owner: 'KeepScreenOn.unmountedDuringAcquire');
      }
      return;
    }
    _acquired = ok;
  }

  @override
  void dispose() {
    if (_acquired && Get.isRegistered<ScreenAwakeService>()) {
      Get.find<ScreenAwakeService>()
          .release(owner: 'KeepScreenOn.dispose');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}