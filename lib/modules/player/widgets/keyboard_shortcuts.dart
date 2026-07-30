import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlayerKeyboardShortcuts extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.space): const PlayPauseIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter): const PlayPauseIntent(),
          LogicalKeySet(LogicalKeyboardKey.escape): const StopIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyR): const ReplayIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyF): const FullscreenIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyM): const MuteIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowUp): const ChannelUpIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowDown): const ChannelDownIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowRight):
              const SeekForwardIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowLeft):
              const SeekBackwardIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyS): const SpeedCycleIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            PlayPauseIntent: CallbackAction<PlayPauseIntent>(
              onInvoke: (intent) => onPlayPause?.call(),
            ),
            StopIntent: CallbackAction<StopIntent>(
              onInvoke: (intent) => onStop?.call(),
            ),
            ReplayIntent: CallbackAction<ReplayIntent>(
              onInvoke: (intent) => onReplay?.call(),
            ),
            FullscreenIntent: CallbackAction<FullscreenIntent>(
              onInvoke: (intent) => onFullscreen?.call(),
            ),
            MuteIntent: CallbackAction<MuteIntent>(
              onInvoke: (intent) => onMute?.call(),
            ),
            ChannelUpIntent: CallbackAction<ChannelUpIntent>(
              onInvoke: (intent) => onChannelUp?.call(),
            ),
            ChannelDownIntent: CallbackAction<ChannelDownIntent>(
              onInvoke: (intent) => onChannelDown?.call(),
            ),
            SeekForwardIntent: CallbackAction<SeekForwardIntent>(
              onInvoke: (intent) => onSeekForward?.call(),
            ),
            SeekBackwardIntent: CallbackAction<SeekBackwardIntent>(
              onInvoke: (intent) => onSeekBackward?.call(),
            ),
            SpeedCycleIntent: CallbackAction<SpeedCycleIntent>(
              onInvoke: (intent) {
                onSpeedChange?.call(1.5);
                return null;
              },
            ),
          },
          child: child,
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
