import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A thin keyboard focus wrapper for embedded video players.
///
/// On TV / remote input the on-screen player controls typically auto-hide after
/// a few seconds, but the underlying gesture overlay only reacts to touch, which
/// can leave remote users unable to restore them. This wrapper:
///
/// * Restores (keeps visible) the controls on any D-pad / arrow key press.
/// * Toggles the controls on the remote/Enter/Select key.
///
/// Wrapping the player with this widget ensures the controls are never
/// permanently locked out when using a D-pad remote.
class TvPlayerKeyboard extends StatelessWidget {
  /// The [child] is typically the player's touch gesture overlay.
  final Widget child;

  /// Called when any directional (D-pad / arrow) key is pressed, used to keep
  /// the controls visible so the user can navigate them.
  final VoidCallback onAnyKey;

  /// Called when the remote Select / Enter key is pressed, used to toggle the
  /// visibility of the controls.
  final VoidCallback onToggleControls;

  const TvPlayerKeyboard({
    super.key,
    required this.child,
    required this.onAnyKey,
    required this.onToggleControls,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final isSelect =
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA;

        if (isSelect) {
          onToggleControls();
          return KeyEventResult.handled;
        }

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
