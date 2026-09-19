// shared/widgets/tv_player_keyboard_hint.dart
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
class TvPlayerKeyboard extends StatefulWidget {
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
  State<TvPlayerKeyboard> createState() => _TvPlayerKeyboardState();
}

class _TvPlayerKeyboardState extends State<TvPlayerKeyboard> {
  FocusNode? _inlineFocusNode;
  FocusNode? _fullscreenFocusNode;

  void _requestFocusAnchor() {
    if (!widget.autofocus || _fullscreenFocusNode == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_fullscreenFocusNode!.canRequestFocus) return;
      if (FocusManager.instance.primaryFocus == null ||
          FocusManager.instance.primaryFocus == _inlineFocusNode) {
        _fullscreenFocusNode!.requestFocus();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (!widget.autofocus) {
      // Inline mini-players must not become the page's primary focus target.
      // They should remain a passive anchor for key handling only, so D-pad
      // navigation can move back out to the surrounding guide/channel content
      // instead of getting trapped inside the player controls.
      _inlineFocusNode = FocusNode(
        canRequestFocus: false,
        skipTraversal: true,
        debugLabel: 'TvPlayerKeyboardInline',
      );
    } else {
      _fullscreenFocusNode = FocusNode(
        debugLabel: 'TvPlayerKeyboardFullscreen',
      );
    }
    _requestFocusAnchor();
  }

  @override
  void didUpdateWidget(TvPlayerKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autofocus != widget.autofocus) {
      if (widget.autofocus) {
        _inlineFocusNode?.dispose();
        _inlineFocusNode = null;
        _fullscreenFocusNode ??= FocusNode(
          debugLabel: 'TvPlayerKeyboardFullscreen',
        );
      } else {
        _fullscreenFocusNode?.dispose();
        _fullscreenFocusNode = null;
        _inlineFocusNode ??= FocusNode(
          canRequestFocus: false,
          skipTraversal: true,
          debugLabel: 'TvPlayerKeyboardInline',
        );
      }
    }
    _requestFocusAnchor();
  }

  @override
  void dispose() {
    _inlineFocusNode?.dispose();
    _fullscreenFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerContent = widget.child;

    if (widget.autofocus) {
      // Fullscreen: keep a stable focus anchor on the player itself so the remote
      // can return to the player after a child control was activated, and so the
      // fullscreen toggle remains reachable without losing the keyboard focus.
      return FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Focus(
          focusNode: _fullscreenFocusNode,
          autofocus: true,
          canRequestFocus: true,
          onKeyEvent: _handleFocusKeyEvent,
          child: playerContent,
        ),
      );
    }

    // Inline/mini-player: keep a passive key handler so the player can respond to
    // media keys and directional actions while never becoming the page's primary
    // focus target and trapping the remote inside the mini-player.
    return Focus(
      focusNode: _inlineFocusNode!,
      canRequestFocus: false,
      onKeyEvent: _handleFocusKeyEvent,
      child: playerContent,
    );
  }

  KeyEventResult _handleFocusKeyEvent(FocusNode node, KeyEvent event) {
    return _handleKeyEvent(event);
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // 1. Hardware Back / Escape (always handle - hierarchy-aware closing)
    final isBack =
        event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.gameButtonB;
    if (isBack && widget.onBack != null) {
      final handled = widget.onBack!();
      if (handled) return KeyEventResult.handled;
    }

    // 2. Hardware Play / Pause (always handle - media keys)
    final isPlayPause =
        event.logicalKey == LogicalKeyboardKey.mediaPlayPause ||
        event.logicalKey == LogicalKeyboardKey.mediaPlay ||
        event.logicalKey == LogicalKeyboardKey.mediaPause;
    if (isPlayPause && widget.onPlayPause != null) {
      widget.onPlayPause!();
      return KeyEventResult.handled;
    }

    // 3. Hardware Stop (always handle - media keys)
    if (event.logicalKey == LogicalKeyboardKey.mediaStop &&
        widget.onStop != null) {
      widget.onStop!();
      return KeyEventResult.handled;
    }

    // 4. Hardware Channel Up (CH+, Page Up, Next Track) - always handle
    final isChannelUp =
        event.logicalKey == LogicalKeyboardKey.channelUp ||
        event.logicalKey == LogicalKeyboardKey.pageUp ||
        event.logicalKey == LogicalKeyboardKey.mediaTrackNext;
    if (isChannelUp && widget.onChannelUp != null) {
      widget.onChannelUp!();
      return KeyEventResult.handled;
    }

    // 5. Hardware Channel Down (CH-, Page Down, Previous Track) - always handle
    final isChannelDown =
        event.logicalKey == LogicalKeyboardKey.channelDown ||
        event.logicalKey == LogicalKeyboardKey.pageDown ||
        event.logicalKey == LogicalKeyboardKey.mediaTrackPrevious;
    if (isChannelDown && widget.onChannelDown != null) {
      widget.onChannelDown!();
      return KeyEventResult.handled;
    }

    // 6. Select / Enter / Game Button A - Toggle controls visibility
    final isSelect =
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA;

    if (isSelect) {
      // Check if a child button currently has primary focus
      final primary = FocusManager.instance.primaryFocus;
      final isSelfFocused =
          primary == _fullscreenFocusNode || primary == _inlineFocusNode;
      if (isSelfFocused || primary == null) {
        widget.onToggleControls();
        return widget.autofocus
            ? KeyEventResult.handled
            : KeyEventResult.ignored;
      }
      // If a child control has focus, let the child control handle its own activation!
      return KeyEventResult.ignored;
    }

    // 7. Directional Arrow Keys - Keep controls alive during navigation,
    // and return ignored so directional focus traversal can move to controls.
    final isDirectional = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp ||
      LogicalKeyboardKey.arrowDown ||
      LogicalKeyboardKey.arrowLeft ||
      LogicalKeyboardKey.arrowRight => true,
      _ => false,
    };
    if (isDirectional) {
      widget.onAnyKey();
      // Allow directional focus to move freely between buttons
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }
}
