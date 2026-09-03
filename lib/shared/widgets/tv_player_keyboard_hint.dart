import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A comprehensive keyboard & TV remote focus wrapper for embedded video players.
///
/// Handles:
/// * Direct hardware Media Play/Pause keys (`mediaPlayPause`, `mediaPlay`, `mediaPause`).
/// * Direct hardware Stop key (`mediaStop`).
/// * Direct hardware Channel Up / Down keys (`channelUp`, `channelDown`, `pageUp`, `pageDown`, `mediaTrackNext`, `mediaTrackPrevious`).
/// * Back key (`escape`, `back`) for hierarchy-aware closing (e.g. closing drawers before exiting fullscreen).
/// * Restores (keeps visible) controls on any D-pad / arrow key press.
/// * Toggles controls on remote Enter/Select key.
class TvPlayerKeyboard extends StatelessWidget {
  /// The [child] is typically the player's touch gesture overlay.
  final Widget child;

  /// Called when any directional (D-pad / arrow) key is pressed, used to keep
  /// the controls visible so the user can navigate them.
  final VoidCallback onAnyKey;

  /// Called when the remote Select / Enter key is pressed, used to toggle the
  /// visibility of the controls.
  final VoidCallback onToggleControls;

  /// Called when a hardware Play, Pause, or Play/Pause key is pressed.
  final VoidCallback? onPlayPause;

  /// Called when a hardware Stop key is pressed.
  final VoidCallback? onStop;

  /// Called when a hardware Channel Up or Page Up key is pressed.
  final VoidCallback? onChannelUp;

  /// Called when a hardware Channel Down or Page Down key is pressed.
  final VoidCallback? onChannelDown;

  /// Called when a hardware Back or Escape key is pressed. Return true if handled.
  final bool Function()? onBack;

  const TvPlayerKeyboard({
    super.key,
    required this.child,
    required this.onAnyKey,
    required this.onToggleControls,
    this.onPlayPause,
    this.onStop,
    this.onChannelUp,
    this.onChannelDown,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        // 1. Hardware Back / Escape (e.g. close drawer before exiting fullscreen)
        final isBack = event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack ||
            event.logicalKey == LogicalKeyboardKey.gameButtonB;
        if (isBack && onBack != null) {
          final handled = onBack!();
          if (handled) return KeyEventResult.handled;
        }

        // 2. Hardware Play / Pause
        final isPlayPause = event.logicalKey == LogicalKeyboardKey.mediaPlayPause ||
            event.logicalKey == LogicalKeyboardKey.mediaPlay ||
            event.logicalKey == LogicalKeyboardKey.mediaPause;
        if (isPlayPause && onPlayPause != null) {
          onPlayPause!();
          return KeyEventResult.handled;
        }

        // 3. Hardware Stop
        if (event.logicalKey == LogicalKeyboardKey.mediaStop && onStop != null) {
          onStop!();
          return KeyEventResult.handled;
        }

        // 4. Hardware Channel Up (CH+, Page Up, Next Track)
        final isChannelUp = event.logicalKey == LogicalKeyboardKey.channelUp ||
            event.logicalKey == LogicalKeyboardKey.pageUp ||
            event.logicalKey == LogicalKeyboardKey.mediaTrackNext;
        if (isChannelUp && onChannelUp != null) {
          onChannelUp!();
          return KeyEventResult.handled;
        }

        // 5. Hardware Channel Down (CH-, Page Down, Previous Track)
        final isChannelDown = event.logicalKey == LogicalKeyboardKey.channelDown ||
            event.logicalKey == LogicalKeyboardKey.pageDown ||
            event.logicalKey == LogicalKeyboardKey.mediaTrackPrevious;
        if (isChannelDown && onChannelDown != null) {
          onChannelDown!();
          return KeyEventResult.handled;
        }

        // 6. Select / Enter / Game Button A (Toggle controls or Activate)
        final isSelect =
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA;

        if (isSelect) {
          onToggleControls();
          return KeyEventResult.handled;
        }

        // 7. Directional Arrow Keys (Keep controls alive during navigation)
        final isDirectional = switch (event.logicalKey) {
          LogicalKeyboardKey.arrowUp ||
          LogicalKeyboardKey.arrowDown ||
          LogicalKeyboardKey.arrowLeft ||
          LogicalKeyboardKey.arrowRight => true,
          _ => false,
        };
        if (isDirectional) {
          onAnyKey();
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
