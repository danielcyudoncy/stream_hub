// modules/player/widgets/keyboard_shortcuts.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlayerKeyboardShortcuts extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPlayPause;
  final VoidCallback? onStop;
  final VoidCallback? onReplay;
  final VoidCallback? onFullscreen;
  final VoidCallback? onMute;
  final VoidCallback? onChannelUp;
  final VoidCallback? onChannelDown;
  final VoidCallback? onSeekForward;
  final VoidCallback? onSeekBackward;
  final ValueChanged<double>? onSpeedChange;
  final VoidCallback? onDpadPress;

  const PlayerKeyboardShortcuts({
    super.key,
    required this.child,
    this.onPlayPause,
    this.onStop,
    this.onReplay,
    this.onFullscreen,
    this.onMute,
    this.onChannelUp,
    this.onChannelDown,
    this.onSeekForward,
    this.onSeekBackward,
    this.onSpeedChange,
    this.onDpadPress,
  });

  static bool _isDirectional(KeyEvent event) => switch (event.logicalKey) {
    LogicalKeyboardKey.arrowUp ||
    LogicalKeyboardKey.arrowDown ||
    LogicalKeyboardKey.arrowLeft ||
    LogicalKeyboardKey.arrowRight => true,
    _ => false,
  };

  @override
  State<PlayerKeyboardShortcuts> createState() =>
      _PlayerKeyboardShortcutsState();
}

class _PlayerKeyboardShortcutsState extends State<PlayerKeyboardShortcuts> {
  late final FocusNode _rootFocusNode;

  @override
  void initState() {
    super.initState();
    _rootFocusNode = FocusNode(debugLabel: 'PlayerKeyboardShortcutsRoot');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_rootFocusNode.hasFocus) {
        _rootFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _rootFocusNode,
      autofocus: true,
      canRequestFocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            widget.onDpadPress != null &&
            PlayerKeyboardShortcuts._isDirectional(event)) {
          widget.onDpadPress!();
          // Do NOT mark directional keys as handled: returning `ignored`
          // allows Flutter's directional focus traversal to move between the
          // player controls (favorite, aspect ratio, channel list, audio…).
          // Handling them here previously made those icons unreachable.
          return KeyEventResult.ignored;
        }
        return KeyEventResult.ignored;
      },
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.space): const PlayPauseIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter): const PlayPauseIntent(),
          LogicalKeySet(LogicalKeyboardKey.numpadEnter):
              const PlayPauseIntent(),
          LogicalKeySet(LogicalKeyboardKey.select): const PlayPauseIntent(),
          LogicalKeySet(LogicalKeyboardKey.gameButtonA):
              const PlayPauseIntent(),
          LogicalKeySet(LogicalKeyboardKey.mediaPlayPause):
              const PlayPauseIntent(),
          LogicalKeySet(LogicalKeyboardKey.mediaPlay): const PlayPauseIntent(),
          LogicalKeySet(LogicalKeyboardKey.mediaPause): const PlayPauseIntent(),
          LogicalKeySet(LogicalKeyboardKey.mediaStop): const StopIntent(),
          LogicalKeySet(LogicalKeyboardKey.escape): const StopIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyR): const ReplayIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyF): const FullscreenIntent(),
          LogicalKeySet(LogicalKeyboardKey.contextMenu):
              const FullscreenIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyM): const MuteIntent(),
          LogicalKeySet(LogicalKeyboardKey.mediaTrackNext):
              const ChannelUpIntent(),
          LogicalKeySet(LogicalKeyboardKey.mediaTrackPrevious):
              const ChannelDownIntent(),
          LogicalKeySet(LogicalKeyboardKey.mediaFastForward):
              const SeekForwardIntent(),
          LogicalKeySet(LogicalKeyboardKey.mediaRewind):
              const SeekBackwardIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyS): const SpeedCycleIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            PlayPauseIntent: CallbackAction<PlayPauseIntent>(
              onInvoke: (intent) {
                final primary = FocusManager.instance.primaryFocus;
                if (primary != null && primary.context != null) {
                  final w = primary.context!.widget;
                  if (w is! Focus && w is! Shortcuts && w is! Actions) {
                    return null;
                  }
                }
                widget.onPlayPause?.call();
                return null;
              },
            ),
            StopIntent: CallbackAction<StopIntent>(
              onInvoke: (intent) => widget.onStop?.call(),
            ),
            ReplayIntent: CallbackAction<ReplayIntent>(
              onInvoke: (intent) => widget.onReplay?.call(),
            ),
            FullscreenIntent: CallbackAction<FullscreenIntent>(
              onInvoke: (intent) => widget.onFullscreen?.call(),
            ),
            MuteIntent: CallbackAction<MuteIntent>(
              onInvoke: (intent) => widget.onMute?.call(),
            ),
            ChannelUpIntent: CallbackAction<ChannelUpIntent>(
              onInvoke: (intent) => widget.onChannelUp?.call(),
            ),
            ChannelDownIntent: CallbackAction<ChannelDownIntent>(
              onInvoke: (intent) => widget.onChannelDown?.call(),
            ),
            SeekForwardIntent: CallbackAction<SeekForwardIntent>(
              onInvoke: (intent) => widget.onSeekForward?.call(),
            ),
            SeekBackwardIntent: CallbackAction<SeekBackwardIntent>(
              onInvoke: (intent) => widget.onSeekBackward?.call(),
            ),
            SpeedCycleIntent: CallbackAction<SpeedCycleIntent>(
              onInvoke: (intent) {
                widget.onSpeedChange?.call(1.5);
                return null;
              },
            ),
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class StopIntent extends Intent {
  const StopIntent();
}

class ReplayIntent extends Intent {
  const ReplayIntent();
}

class FullscreenIntent extends Intent {
  const FullscreenIntent();
}

class MuteIntent extends Intent {
  const MuteIntent();
}

class ChannelUpIntent extends Intent {
  const ChannelUpIntent();
}

class ChannelDownIntent extends Intent {
  const ChannelDownIntent();
}

class SeekForwardIntent extends Intent {
  const SeekForwardIntent();
}

class SeekBackwardIntent extends Intent {
  const SeekBackwardIntent();
}

class SpeedCycleIntent extends Intent {
  const SpeedCycleIntent();
}
