import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/media/enums/playback_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../../../shared/widgets/tv_player_keyboard_hint.dart';
import '../../../shared/widgets/keep_screen_on.dart';
import '../../player/controllers/player_controller.dart';
import '../../player/widgets/audio_track_selector.dart';
import '../../player/widgets/player_touch_gesture_overlay.dart';
import '../../player/widgets/subtitle_selector.dart' hide AudioTrackSelector;
import '../movie_details_controller.dart';

class MovieInlinePlayer extends StatefulWidget {
  final MovieDetailsController controller;
  final bool isFullscreen;

  const MovieInlinePlayer({
    super.key,
    required this.controller,
    this.isFullscreen = false,
  });

  @override
  State<MovieInlinePlayer> createState() => _MovieInlinePlayerState();
}

class _MovieInlinePlayerState extends State<MovieInlinePlayer> {
  bool _controlsVisible = true;
  Timer? _controlsTimer;
  bool _isDraggingSlider = false;
  double _dragSliderValue = 0.0;
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'MovieBack');
  final FocusNode _subtitlesFocusNode = FocusNode(debugLabel: 'MovieSubtitles');
  final FocusNode _audioFocusNode = FocusNode(debugLabel: 'MovieAudio');
  final FocusNode _topFullscreenFocusNode = FocusNode(debugLabel: 'MovieTopFullscreen');
  final FocusNode _replayFocusNode = FocusNode(debugLabel: 'MovieReplay');
  final FocusNode _playPauseFocusNode = FocusNode(debugLabel: 'MoviePlayPause');
  final FocusNode _forwardFocusNode = FocusNode(debugLabel: 'MovieForward');
  final FocusNode _seekbarFocusNode = FocusNode(debugLabel: 'MovieSeekbar');
  final FocusNode _bottomFullscreenFocusNode = FocusNode(debugLabel: 'MovieBottomFullscreen');
  final GlobalKey<TvPlayerKeyboardState> _keyboardKey = GlobalKey<TvPlayerKeyboardState>();

  @override
  void initState() {
    super.initState();
    _startControlsTimer();
    _focusPlayPauseIfControlsVisible();
  }

  @override
  void didUpdateWidget(MovieInlinePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isFullscreen && widget.isFullscreen) {
      _focusPlayPauseIfControlsVisible();
    }
  }

  void _reclaimPlayerFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controlsVisible) return;
      _keyboardKey.currentState?.reclaimFocus();
    });
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    final seconds = widget.isFullscreen ? 5 : 8;
    _controlsTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted || !_controlsVisible || _isDraggingSlider) return;
      final ctrl = widget.controller.inlinePlayerController;
      final state = ctrl?.playbackController.engine.stateRx.value;
      // Keep controls on screen while paused; hiding them hides the resume button.
      if (state == PlaybackState.paused) return;
      setState(() => _controlsVisible = false);
      _reclaimPlayerFocus();
    });
  }

  void _focusPlayPauseIfControlsVisible() {
    if (_controlsVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controlsVisible && _playPauseFocusNode.canRequestFocus) {
          _playPauseFocusNode.requestFocus();
        }
      });
    }
  }

  void _showControlsTemporarily() {
    if (!mounted) return;
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _startControlsTimer();
    _focusPlayPauseIfControlsVisible();
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) {
        _startControlsTimer();
        _focusPlayPauseIfControlsVisible();
      } else {
        _controlsTimer?.cancel();
        _reclaimPlayerFocus();
      }
    });
  }

  /// Remote Select/OK handling. If controls are already visible, toggles playback;
  /// if they are hidden, reveals them and focuses the Play/Pause control.
  void _handleSelectKey() {
    if (_controlsVisible) {
      final ctrl = widget.controller.inlinePlayerController;
      ctrl?.togglePlayPause();
      _startControlsTimer();
      return;
    }
    _showControlsTemporarily();
  }

  KeyEventResult _handleControlKey(
    KeyEvent event, {
    VoidCallback? onLeft,
    VoidCallback? onRight,
    VoidCallback? onUp,
    VoidCallback? onDown,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    _startControlsTimer();
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && onLeft != null) {
      onLeft();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight && onRight != null) {
      onRight();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && onUp != null) {
      onUp();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && onDown != null) {
      onDown();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _backFocusNode.dispose();
    _subtitlesFocusNode.dispose();
    _audioFocusNode.dispose();
    _topFullscreenFocusNode.dispose();
    _replayFocusNode.dispose();
    _playPauseFocusNode.dispose();
    _forwardFocusNode.dispose();
    _seekbarFocusNode.dispose();
    _bottomFullscreenFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final playerCtrl = widget.controller.inlinePlayerController;
      final movie = widget.controller.movie;

      if (playerCtrl == null || movie == null) {
        return const SizedBox.shrink();
      }

      final isTv = PlatformHelper.isTV;

      final playerStack = Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video Surface Layer
          _buildVideoSurface(playerCtrl),

          // 2. Touch Gestures & Controls Layer
          TvPlayerKeyboard(
            key: _keyboardKey,
            autofocus: widget.isFullscreen || isTv,
            onAnyKey: _showControlsTemporarily,
            onToggleControls: _handleSelectKey,
            onPlayPause: () {
              playerCtrl.togglePlayPause();
              _showControlsTemporarily();
            },
            onStop: () {
              if (widget.isFullscreen) {
                widget.controller.exitFullscreen();
              } else {
                widget.controller.stopInlinePlayback();
              }
            },
            onChannelUp: () {
              final pos = playerCtrl.playbackController.engine.positionRx.value;
              playerCtrl.seek(pos + const Duration(seconds: 10));
              _showControlsTemporarily();
            },
            onChannelDown: () {
              final pos = playerCtrl.playbackController.engine.positionRx.value;
              playerCtrl.seek(pos - const Duration(seconds: 10));
              _showControlsTemporarily();
            },
            onBack: () {
              if (widget.isFullscreen) {
                widget.controller.exitFullscreen();
                return true;
              }
              return false;
            },
            child: PlayerTouchGestureOverlay(
              onTap: _toggleControls,
              initialVolume: playerCtrl.playbackController.engine.volumeRx.value,
              onVolumeChanged: (vol) => playerCtrl.setVolume(vol),
              controls: Stack(
                fit: StackFit.expand,
                children: [
                  // Loading / Buffering Indicator
                  _buildBufferingIndicator(playerCtrl),

                  // Controls Overlay
                  _buildControlsOverlay(context, playerCtrl, movie),
                ],
              ),
            ),
          ),
        ],
      );

      if (widget.isFullscreen) {
        return ColoredBox(
          color: Colors.black,
          child: playerStack,
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: AppRadius.large,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 16.0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: playerStack,
        ),
      );
    });
  }

  Widget _buildVideoSurface(PlayerController playerCtrl) {
    return Obx(() {
      final engine = playerCtrl.playbackController.engine;
      engine.engineKindRx.value;
      playerCtrl.stateRx.value;
      return Positioned.fill(
        child: ColoredBox(
          color: Colors.black,
          child: KeepScreenOn(child: engine.adapter.buildPlayerWidget()),
        ),
      );
    });
  }

  Widget _buildBufferingIndicator(PlayerController playerCtrl) {
    return Obx(() {
      final state = playerCtrl.playbackController.engine.stateRx.value;
      if (state == PlaybackState.loading || state == PlaybackState.buffering) {
        return Container(
          color: Colors.black45,
          child: const Center(
            child: SizedBox(
              width: 36.0,
              height: 36.0,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3.0,
              ),
            ),
          ),
        );
      }
      if (state == PlaybackState.error) {
        final errorMsg = playerCtrl.playbackController.engine.errorMessageRx.value.isNotEmpty
            ? playerCtrl.playbackController.engine.errorMessageRx.value
            : 'Playback failed. Stream source may be offline.';
        return Container(
          color: Colors.black87,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.darkError, size: 36.0),
                const SizedBox(height: 8.0),
                Text(
                  errorMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12.0),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10.0),
                TvFocusable(
                  onTap: () => widget.controller.startInlinePlayback(),
                  borderRadius: AppRadius.pill,
                  scale: 1.05,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: AppRadius.pill,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 16.0, color: Colors.white),
                        SizedBox(width: 6.0),
                        Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 12.0,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    });
  }

  Widget _buildControlsOverlay(
    BuildContext context,
    PlayerController playerCtrl,
    MediaItem movie,
  ) {
    return IgnorePointer(
      ignoring: !_controlsVisible,
      child: ExcludeFocus(
        excluding: !_controlsVisible,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.75),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.25, 0.7, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Top Bar
                  _buildTopBar(context, playerCtrl, movie),

                  // Center Play / Pause & Skip Buttons
                  Expanded(
                    child: _buildCenterControls(playerCtrl),
                  ),

                  // Bottom Bar (Seekbar, Duration, Fullscreen)
                  _buildBottomBar(context, playerCtrl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    PlayerController playerCtrl,
    MediaItem movie,
  ) {
    final isTv = PlatformHelper.isTV;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTv || widget.isFullscreen ? AppSpacing.lg : AppSpacing.sm,
        vertical: isTv || widget.isFullscreen ? AppSpacing.sm : 4.0,
      ),
      child: Row(
        children: [
          // Back / Close button
          TvFocusable(
            focusNode: _backFocusNode,
            onKeyEvent: (node, event) => _handleControlKey(
              event,
              onRight: () => _subtitlesFocusNode.requestFocus(),
              onDown: () => _playPauseFocusNode.requestFocus(),
            ),
            onTap: () => widget.isFullscreen
                ? widget.controller.exitFullscreen()
                : widget.controller.stopInlinePlayback(),
            borderRadius: AppRadius.pill,
            scale: 1.1,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                widget.isFullscreen ? Icons.arrow_back_rounded : Icons.close_rounded,
                color: Colors.white70,
                size: 20.0,
              ),
            ),
          ),
          const SizedBox(width: 4.0),
          Expanded(
            child: Text(
              movie.title,
              style: AppTypography.getLabel(color: Colors.white).copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Subtitle Selector Button
          TvFocusable(
            focusNode: _subtitlesFocusNode,
            onKeyEvent: (node, event) => _handleControlKey(
              event,
              onLeft: () => _backFocusNode.requestFocus(),
              onRight: () => _audioFocusNode.requestFocus(),
              onDown: () => _playPauseFocusNode.requestFocus(),
            ),
            onTap: () => _openSubtitlePicker(context, playerCtrl),
            borderRadius: AppRadius.pill,
            scale: 1.1,
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.subtitles_rounded, color: Colors.white, size: 19.0),
            ),
          ),
          // Audio Track Selector Button
          TvFocusable(
            focusNode: _audioFocusNode,
            onKeyEvent: (node, event) => _handleControlKey(
              event,
              onLeft: () => _subtitlesFocusNode.requestFocus(),
              onRight: () => _topFullscreenFocusNode.requestFocus(),
              onDown: () => _playPauseFocusNode.requestFocus(),
            ),
            onTap: () => _openAudioTrackPicker(context, playerCtrl),
            borderRadius: AppRadius.pill,
            scale: 1.1,
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.audiotrack_rounded, color: Colors.white, size: 19.0),
            ),
          ),
          // Fullscreen Toggle Button
          TvFocusable(
            focusNode: _topFullscreenFocusNode,
            onKeyEvent: (node, event) => _handleControlKey(
              event,
              onLeft: () => _audioFocusNode.requestFocus(),
              onDown: () => _playPauseFocusNode.requestFocus(),
            ),
            onTap: () => widget.controller.toggleFullscreen(),
            borderRadius: AppRadius.pill,
            scale: 1.1,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                widget.isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                color: Colors.white,
                size: 22.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls(PlayerController playerCtrl) {
    return Obx(() {
      final isPlaying = playerCtrl.playbackController.engine.stateRx.value == PlaybackState.playing;

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Replay 10s
          TvFocusable(
            focusNode: _replayFocusNode,
            onKeyEvent: (node, event) => _handleControlKey(
              event,
              onRight: () => _playPauseFocusNode.requestFocus(),
              onUp: () => _backFocusNode.requestFocus(),
              onDown: () => _seekbarFocusNode.requestFocus(),
            ),
            onTap: () {
              final pos = playerCtrl.playbackController.engine.positionRx.value;
              playerCtrl.seek(pos - const Duration(seconds: 10));
              _startControlsTimer();
            },
            borderRadius: AppRadius.pill,
            scale: 1.15,
            child: const Padding(
              padding: EdgeInsets.all(10.0),
              child: Icon(Icons.replay_10_rounded, color: Colors.white, size: 28.0),
            ),
          ),
          AppSpacing.widthMD,
          // Play / Pause Circle
          TvFocusable(
            focusNode: _playPauseFocusNode,
            onKeyEvent: (node, event) => _handleControlKey(
              event,
              onLeft: () => _replayFocusNode.requestFocus(),
              onRight: () => _forwardFocusNode.requestFocus(),
              onUp: () => _backFocusNode.requestFocus(),
              onDown: () => _seekbarFocusNode.requestFocus(),
            ),
            onTap: () {
              playerCtrl.togglePlayPause();
              _startControlsTimer();
            },
            borderRadius: AppRadius.pill,
            child: Container(
              width: 52.0,
              height: 52.0,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.darkPrimary.withValues(alpha: 0.4),
                    blurRadius: 12.0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32.0,
              ),
            ),
          ),
          AppSpacing.widthMD,
          // Forward 10s
          TvFocusable(
            focusNode: _forwardFocusNode,
            onKeyEvent: (node, event) => _handleControlKey(
              event,
              onLeft: () => _playPauseFocusNode.requestFocus(),
              onRight: () => _subtitlesFocusNode.requestFocus(),
              onUp: () => _subtitlesFocusNode.requestFocus(),
              onDown: () => _seekbarFocusNode.requestFocus(),
            ),
            onTap: () {
              final pos = playerCtrl.playbackController.engine.positionRx.value;
              playerCtrl.seek(pos + const Duration(seconds: 10));
              _startControlsTimer();
            },
            borderRadius: AppRadius.pill,
            scale: 1.15,
            child: const Padding(
              padding: EdgeInsets.all(10.0),
              child: Icon(Icons.forward_10_rounded, color: Colors.white, size: 28.0),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildBottomBar(
    BuildContext context,
    PlayerController playerCtrl,
  ) {
    final isTv = PlatformHelper.isTV;
    return Obx(() {
      final position = playerCtrl.playbackController.engine.positionRx.value;
      final duration = playerCtrl.playbackController.engine.durationRx.value;

      final totalMs = duration.inMilliseconds.toDouble();
      final currentMs = _isDraggingSlider
          ? _dragSliderValue
          : position.inMilliseconds.toDouble().clamp(0.0, totalMs > 0 ? totalMs : 1.0);

      final maxSlider = totalMs > 0 ? totalMs : 1.0;

      return Padding(
        padding: EdgeInsets.fromLTRB(
          isTv || widget.isFullscreen ? AppSpacing.lg : AppSpacing.md,
          0.0,
          isTv || widget.isFullscreen ? AppSpacing.lg : AppSpacing.md,
          isTv || widget.isFullscreen ? AppSpacing.md : AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Custom Seekbar Slider
            TvFocusable(
              focusNode: _seekbarFocusNode,
              descendantsAreFocusable: false,
              scale: 1.02,
              borderRadius: AppRadius.small,
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                _startControlsTimer();
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  final pos = playerCtrl.playbackController.engine.positionRx.value;
                  playerCtrl.seek(pos - const Duration(seconds: 10));
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  final pos = playerCtrl.playbackController.engine.positionRx.value;
                  playerCtrl.seek(pos + const Duration(seconds: 10));
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _playPauseFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _bottomFullscreenFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
                child: Slider(
                  value: currentMs.clamp(0.0, maxSlider),
                  min: 0.0,
                  max: maxSlider,
                  onChangeStart: (val) {
                    setState(() {
                      _isDraggingSlider = true;
                      _dragSliderValue = val;
                    });
                    _controlsTimer?.cancel();
                  },
                  onChanged: (val) {
                    setState(() {
                      _dragSliderValue = val;
                    });
                  },
                  onChangeEnd: (val) {
                    setState(() {
                      _isDraggingSlider = false;
                    });
                    playerCtrl.seek(Duration(milliseconds: val.toInt()));
                    _startControlsTimer();
                  },
                ),
              ),
            ),
            // Time Labels & Fullscreen Trigger Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatDuration(position)} / ${_formatDuration(duration)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TvFocusable(
                  focusNode: _bottomFullscreenFocusNode,
                  onKeyEvent: (node, event) => _handleControlKey(
                    event,
                    onUp: () => _seekbarFocusNode.requestFocus(),
                    onLeft: () => _seekbarFocusNode.requestFocus(),
                  ),
                  onTap: () => widget.controller.toggleFullscreen(),
                  borderRadius: AppRadius.small,
                  scale: 1.05,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                          color: Colors.white70,
                          size: 18.0,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          widget.isFullscreen ? 'Exit Full Screen' : 'Full Screen',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  void _openSubtitlePicker(BuildContext context, PlayerController playerCtrl) async {
    final tracks = await playerCtrl.getAvailableSubtitleTracks();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (ctx) {
        return Obx(() {
          final selected = playerCtrl.selectedSubtitleTrackRx.value;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
            ),
            child: SubtitleSelector(
              tracks: tracks,
              selectedTrackId: selected,
              onSelected: (trackId) {
                playerCtrl.setSubtitleTrack(trackId);
                Navigator.pop(ctx);
              },
              onDisabled: () {
                playerCtrl.setSubtitleTrack('no');
                Navigator.pop(ctx);
              },
            ),
          );
        });
      },
    );
  }

  void _openAudioTrackPicker(BuildContext context, PlayerController playerCtrl) async {
    final tracks = await playerCtrl.getAvailableAudioTracks();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (ctx) {
        return Obx(() {
          final selected = playerCtrl.selectedAudioTrackRx.value;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.audiotrack_rounded, color: Colors.white, size: 22),
                        AppSpacing.widthSM,
                        Text(
                          'Audio Tracks',
                          style: AppTypography.getTitle(color: Colors.white).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TvFocusable(
                          onTap: () => Navigator.pop(ctx),
                          borderRadius: AppRadius.pill,
                          scale: 1.1,
                          child: const IconButton(
                            icon: Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                            onPressed: null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    AudioTrackSelector(
                      tracks: tracks,
                      selectedTrackId: selected,
                      onSelected: (trackId) {
                        playerCtrl.setAudioTrack(trackId);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }
}
