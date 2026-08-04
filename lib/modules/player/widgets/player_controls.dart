import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';

class PlayerControls extends StatelessWidget {
  final PlayerController controller;
  final bool isFullscreen;

  const PlayerControls({
    super.key,
    required this.controller,
    this.isFullscreen = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFullscreen)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(AppIcons.back, color: Colors.white),
                  ),
                  Expanded(
                    child: Obx(() {
                      final title = controller.sessionRx.value?.metadata.title ?? '';
                      return Text(
                        title,
                        style: AppTypography.getBody(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    }),
                  ),
                ],
              ),
            ),
          _ProgressBar(controller: controller),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isFullscreen ? AppSpacing.lg : AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                _ControlButton(
                  icon: AppIcons.previous,
                  onPressed: controller.previous,
                  size: isFullscreen ? 32 : 24,
                ),
                _ControlButton(
                  icon: AppIcons.rewind,
                  onPressed: () => controller.seek(
                    controller.position - const Duration(seconds: 10),
                  ),
                  size: isFullscreen ? 32 : 24,
                ),
                Obx(() {
                  final state = controller.stateRx.value;
                  final isPlaying = state == PlaybackState.playing;
                  return _ControlButton(
                    icon: isPlaying ? AppIcons.pause : AppIcons.play,
                    onPressed: isPlaying ? controller.pause : controller.play,
                    size: isFullscreen ? 48 : 36,
                  );
                }),
                _ControlButton(
                  icon: AppIcons.forward,
                  onPressed: () => controller.seek(
                    controller.position + const Duration(seconds: 10),
                  ),
                  size: isFullscreen ? 32 : 24,
                ),
                _ControlButton(
                  icon: AppIcons.next,
                  onPressed: controller.next,
                  size: isFullscreen ? 32 : 24,
                ),
                const Spacer(),
                Flexible(
                  flex: 2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PopupMenuButton<AspectRatioMode>(
                          icon: AppIcons.aspectRatio,
                          items: AspectRatioMode.values,
                          labelBuilder: (mode) => Text(mode.displayName),
                          onSelected: (mode) =>
                              controller.setAspectRatio(mode),
                        ),
                        _PopupMenuButton<PlaybackSpeed>(
                          icon: AppIcons.speed,
                          items: PlaybackSpeed.values,
                          labelBuilder: (speed) => Text(speed.label),
                          onSelected: (speed) => controller.setSpeed(speed),
                        ),
                        if (isFullscreen) ...[
                          _PopupMenuButton<PlayerQuality>(
                            icon: AppIcons.quality,
                            items: PlayerQuality.values,
                            labelBuilder: (q) => Text(q.displayName),
                            onSelected: (q) => controller.setQuality(q),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(AppIcons.subtitles,
                                color: Colors.white),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(AppIcons.audioTrack,
                                color: Colors.white),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(AppIcons.sleep,
                                color: Colors.white),
                          ),
                          IconButton(
                            onPressed: () => _toggleFullscreen(context),
                            icon: const Icon(AppIcons.fullscreenExit,
                                color: Colors.white),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFullscreen(BuildContext context) {
    // Fullscreen toggle handled by platform channels or route navigation
  }
}

class _ProgressBar extends StatelessWidget {
  final PlayerController controller;

  const _ProgressBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final position = controller.position;
      final duration = controller.duration;

      final progress = duration > Duration.zero
          ? position.inMilliseconds / duration.inMilliseconds
          : 0.0;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: Colors.red,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.red,
            overlayColor: Colors.red.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: (value) {
              final newPosition = Duration(
                milliseconds: (value * duration.inMilliseconds).round(),
              );
              controller.seek(newPosition);
            },
          ),
        ),
      );
    });
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.onPressed,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: size, color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: BoxConstraints(minWidth: size + 16, minHeight: size + 16),
    );
  }
}

class _PopupMenuButton<T> extends StatelessWidget {
  final IconData icon;
  final List<T> items;
  final Widget Function(T) labelBuilder;
  final ValueChanged<T> onSelected;

  const _PopupMenuButton({
    required this.icon,
    required this.items,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      icon: Icon(icon, color: Colors.white, size: 20),
      onSelected: onSelected,
      itemBuilder: (context) {
        return items
            .map((item) => PopupMenuItem<T>(
                  value: item,
                  child: labelBuilder(item),
                ))
            .toList();
      },
    );
  }
}
