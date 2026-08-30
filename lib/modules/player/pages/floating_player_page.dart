import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

class FloatingPlayerPage extends StatefulWidget {
  final double width;
  final double height;
  final Offset? initialPosition;
  final bool draggable;

  const FloatingPlayerPage({
    super.key,
    this.width = 280.0,
    this.height = 158.0,
    this.initialPosition,
    this.draggable = true,
  });

  @override
  State<FloatingPlayerPage> createState() => _FloatingPlayerPageState();
}

class _FloatingPlayerPageState extends State<FloatingPlayerPage> {
  Offset? _position;
  bool _showControls = false;
  Timer? _hideControlsTimer;

  PlayerController get _controller => Get.find<PlayerController>();

  void _onHover(bool hovering) {
    if (hovering) {
      _showOverlay();
    } else {
      _startHideTimer();
    }
  }

  void _showOverlay() {
    _hideControlsTimer?.cancel();
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PlayerController>()) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      final state = _controller.stateRx.value;
      final session = _controller.sessionRx.value;

      if (state == PlaybackState.idle ||
          state == PlaybackState.stopped ||
          session == null) {
        return const SizedBox.shrink();
      }

      final screenSize = MediaQuery.of(context).size;
      final defaultX = screenSize.width - widget.width - 24.0;
      final defaultY = screenSize.height - widget.height - 24.0;

      final currentPos =
          _position ??
          widget.initialPosition ??
          Offset(
            defaultX.clamp(16.0, double.infinity),
            defaultY.clamp(16.0, double.infinity),
          );

      final isLive = session.metadata.isLive;
      final title = (session.metadata.title?.isNotEmpty ?? false)
          ? session.metadata.title!
          : 'Live Stream';

      return Positioned(
        left: currentPos.dx.clamp(
          8.0,
          (screenSize.width - widget.width - 8.0).clamp(8.0, double.infinity),
        ),
        top: currentPos.dy.clamp(
          8.0,
          (screenSize.height - widget.height - 8.0).clamp(8.0, double.infinity),
        ),
        child: Material(
          color: Colors.transparent,
          child: MouseRegion(
            onEnter: (_) => _onHover(true),
            onExit: (_) => _onHover(false),
            child: GestureDetector(
              onTap: _showOverlay,
              onPanUpdate: widget.draggable
                  ? (details) {
                      setState(() {
                        _position = Offset(
                          (currentPos.dx + details.delta.dx).clamp(
                            8.0,
                            (screenSize.width - widget.width - 8.0).clamp(
                              8.0,
                              double.infinity,
                            ),
                          ),
                          (currentPos.dy + details.delta.dy).clamp(
                            8.0,
                            (screenSize.height - widget.height - 8.0).clamp(
                              8.0,
                              double.infinity,
                            ),
                          ),
                        );
                      });
                    }
                  : null,
              child: Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Video Player Widget
                      _controller.playbackController.engine.adapter
                          .buildPlayerWidget(),

                      // Buffering indicator
                      if (state == PlaybackState.buffering ||
                          state == PlaybackState.loading)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                      // Overlay scrim & controls
                      AnimatedOpacity(
                        opacity: _showControls ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.75),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.85),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Top Bar: Live indicator + Title + Close Button
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: [
                                    if (isLive) ...[
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(
                                          left: 4,
                                          right: 4,
                                        ),
                                        decoration: const BoxDecoration(
                                          color: AppColors.error,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: AppTypography.getCaption(
                                          color: Colors.white,
                                        ).copyWith(fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    TvFocusable(
                                      onTap: _controller.stop,
                                      scale: 1.1,
                                      borderRadius: BorderRadius.circular(16),
                                      child: IconButton(
                                        onPressed: _controller.stop,
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 28,
                                          minHeight: 28,
                                        ),
                                        tooltip: 'Close Playback',
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Bottom Bar: Play/Pause + Expand Fullscreen
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    TvFocusable(
                                      onTap: _controller.togglePlayPause,
                                      scale: 1.1,
                                      borderRadius: BorderRadius.circular(16),
                                      child: IconButton(
                                        onPressed: _controller.togglePlayPause,
                                        icon: Icon(
                                          state == PlaybackState.playing
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 28,
                                          minHeight: 28,
                                        ),
                                        tooltip: state == PlaybackState.playing
                                            ? 'Pause'
                                            : 'Play',
                                      ),
                                    ),
                                    TvFocusable(
                                      onTap: () => Get.toNamed(
                                        AppRoutes.fullscreenPlayer,
                                      ),
                                      scale: 1.1,
                                      borderRadius: BorderRadius.circular(16),
                                      child: IconButton(
                                        onPressed: () => Get.toNamed(
                                          AppRoutes.fullscreenPlayer,
                                        ),
                                        icon: const Icon(
                                          Icons.fullscreen_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 28,
                                          minHeight: 28,
                                        ),
                                        tooltip: 'Fullscreen',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
