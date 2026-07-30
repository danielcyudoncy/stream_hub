import 'package:flutter/material.dart';

class PlayerGestureDetector extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final ValueChanged<double>? onHorizontalDrag;
  final ValueChanged<double>? onVerticalDrag;

  const PlayerGestureDetector({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onHorizontalDrag,
    this.onVerticalDrag,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onVerticalDragUpdate: _onVerticalDrag,
      onHorizontalDragUpdate: _onHorizontalDrag,
      child: child,
    );
  }

  void _onVerticalDrag(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    if (delta.abs() > 10) {
      if (delta > 0) {
        onSwipeDown?.call();
      } else {
        onSwipeUp?.call();
      }
      onVerticalDrag?.call(delta);
    }
  }

  void _onHorizontalDrag(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    if (delta.abs() > 10) {
      if (delta > 0) {
        onSwipeRight?.call();
      } else {
        onSwipeLeft?.call();
      }
      onHorizontalDrag?.call(delta);
    }
  }
}

class PlayerBufferIndicator extends StatelessWidget {
  final double bufferPercentage;

  const PlayerBufferIndicator({super.key, required this.bufferPercentage});

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: bufferPercentage / 100.0,
      backgroundColor: Colors.white24,
      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white54),
      minHeight: 2,
    );
  }
}

class PlayerOverlayControls extends StatelessWidget {
  final VoidCallback? onPlayPause;
  final VoidCallback? onSeekForward;
  final VoidCallback? onSeekBackward;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  const PlayerOverlayControls({
    super.key,
    this.onPlayPause,
    this.onSeekForward,
    this.onSeekBackward,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: onSeekBackward,
              icon: const Icon(Icons.replay_10, color: Colors.white, size: 36),
            ),
            IconButton(
              onPressed: onPlayPause,
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 56,
              ),
            ),
            IconButton(
              onPressed: onSeekForward,
              icon: const Icon(Icons.forward_30, color: Colors.white, size: 36),
            ),
          ],
        ),
      ),
    );
  }
}
