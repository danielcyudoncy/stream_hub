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

  /// Whether the player grabs keyboard focus when it mounts. Keep this enabled
  /// for fullscreen playback, but disable it for inline mini-players on grid
  /// pages (e.g. TV Guide) so the surrounding D-pad navigation is not hijacked.
  final bool autofocus;

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
    this.autofocus = true,
  });

  @override
  Widget build(BuildContext context) {
    if (autofocus) {
      // Fullscreen: Create a focus scope that traps navigation
      return Focus(
        autofocus: true,
        onKeyEvent: _handleFocusKeyEvent,
        child: child,
      );
    }

    // Inline/mini-player: NO focus scope. Use KeyboardListener to handle
    // media/hardware keys without creating a focus boundary that traps traversal.
    // Child controls (Play, Stop, Fullscreen, Audio, Subtitles, PiP) participate
    // in parent's focus traversal naturally.
    return KeyboardListener(
      focusNode: FocusNode(
        canRequestFocus: false,
        skipTraversal: true,
        debugLabel: 'TvPlayerKeyboardInline',
      ),
      onKeyEvent: _handleKeyboardListenerEvent,
      child: child,
    );
  }

  KeyEventResult _handleFocusKeyEvent(FocusNode node, KeyEvent event) {
    return _handleKeyEvent(event);
  }

  void _handleKeyboardListenerEvent(KeyEvent event) {
    _handleKeyEvent(event);
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // 1. Hardware Back / Escape (always handle - hierarchy-aware closing)
    final isBack = event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.gameButtonB;
    if (isBack && onBack != null) {
      final handled = onBack!();
      if (handled) return KeyEventResult.handled;
    }

    // 2. Hardware Play / Pause (always handle - media keys)
    final isPlayPause = event.logicalKey == LogicalKeyboardKey.mediaPlayPause ||
        event.logicalKey == LogicalKeyboardKey.mediaPlay ||
        event.logicalKey == LogicalKeyboardKey.mediaPause;
    if (isPlayPause && onPlayPause != null) {
      onPlayPause!();
      return KeyEventResult.handled;
    }

    // 3. Hardware Stop (always handle - media keys)
    if (event.logicalKey == LogicalKeyboardKey.mediaStop && onStop != null) {
      onStop!();
      return KeyEventResult.handled;
    }

    // 4. Hardware Channel Up (CH+, Page Up, Next Track) - always handle
    final isChannelUp = event.logicalKey == LogicalKeyboardKey.channelUp ||
        event.logicalKey == LogicalKeyboardKey.pageUp ||
        event.logicalKey == LogicalKeyboardKey.mediaTrackNext;
    if (isChannelUp && onChannelUp != null) {
      onChannelUp!();
      return KeyEventResult.handled;
    }

    // 5. Hardware Channel Down (CH-, Page Down, Previous Track) - always handle
    final isChannelDown = event.logicalKey == LogicalKeyboardKey.channelDown ||
        event.logicalKey == LogicalKeyboardKey.pageDown ||
        event.logicalKey == LogicalKeyboardKey.mediaTrackPrevious;
    if (isChannelDown && onChannelDown != null) {
      onChannelDown!();
      return KeyEventResult.handled;
    }

    // 6. Select / Enter / Game Button A - Toggle controls visibility
    final isSelect =
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA;

    if (isSelect) {
      onToggleControls();
      // In fullscreen mode, consume. In inline mode, let parent traversal handle.
      return autofocus ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    // 7. Directional Arrow Keys - Keep controls alive during navigation
    final isDirectional = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp ||
      LogicalKeyboardKey.arrowDown ||
      LogicalKeyboardKey.arrowLeft ||
      LogicalKeyboardKey.arrowRight => true,
      _ => false,
    };
    if (isDirectional) {
      onAnyKey();
      // In fullscreen mode, consume. In inline mode, let parent traversal handle.
      return autofocus ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }
}