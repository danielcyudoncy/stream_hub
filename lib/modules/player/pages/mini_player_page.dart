import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

class MiniPlayerPage extends GetView<PlayerController> {
  final VoidCallback? onExpand;

  const MiniPlayerPage({super.key, this.onExpand});

  void _handleExpand() {
    if (onExpand != null) {
      onExpand!();
    } else {
      Get.toNamed(AppRoutes.fullscreenPlayer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Obx(() {
      final state = controller.stateRx.value;
      final session = controller.sessionRx.value;

      // Hide if stopped, idle, or in error without session
      if (state == PlaybackState.idle ||
          state == PlaybackState.stopped ||
          session == null) {
        return const SizedBox.shrink();
      }

      final isLive = session.metadata.isLive;
      final title = (session.metadata.title?.isNotEmpty ?? false)
          ? session.metadata.title!
          : 'StreamHub Live';
      final subtitle =
          session.metadata.description ?? (isLive ? 'Live Broadcast' : '');

      return TvFocusable(
        onTap: _handleExpand,
        scale: 1.01,
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: _handleExpand,
          child: Container(
            height: 64,
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.95,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Row(
                    children: [
                      // Video thumbnail box
                      SizedBox(
                        width: 96,
                        height: 64,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: Colors.black),
                            controller.playbackController.engine.adapter
                                .buildPlayerWidget(),
                            if (state == PlaybackState.buffering ||
                                state == PlaybackState.loading)
                              Container(
                                color: Colors.black45,
                                child: const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Stream info
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isLive) ...[
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
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
                                ],
                              ),
                              if (subtitle.isNotEmpty)
                                Text(
                                  subtitle,
                                  style: AppTypography.getCaption(
                                    color: Colors.white60,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Controls: Play/Pause
                      TvFocusable(
                        onTap: controller.togglePlayPause,
                        scale: 1.08,
                        borderRadius: BorderRadius.circular(20),
                        child: IconButton(
                          onPressed: controller.togglePlayPause,
                          icon: Icon(
                            state == PlaybackState.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          tooltip: state == PlaybackState.playing
                              ? 'Pause'
                              : 'Play',
                        ),
                      ),
                      // Close (Stop)
                      TvFocusable(
                        onTap: controller.stop,
                        scale: 1.08,
                        borderRadius: BorderRadius.circular(20),
                        child: IconButton(
                          onPressed: controller.stop,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                          tooltip: 'Close Playback',
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                  // Progress indicator for non-live VOD
                  if (!isLive)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Obx(() {
                        final pos = controller
                            .playbackController
                            .engine
                            .positionRx
                            .value
                            .inMilliseconds;
                        final dur = controller
                            .playbackController
                            .engine
                            .durationRx
                            .value
                            .inMilliseconds;
                        final progress = dur > 0
                            ? (pos / dur).clamp(0.0, 1.0)
                            : 0.0;
                        return LinearProgressIndicator(
                          value: progress,
                          minHeight: 2.5,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        );
                      }),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
