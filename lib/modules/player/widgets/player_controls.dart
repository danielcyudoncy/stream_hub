import 'dart:io';
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
import '../../../shared/widgets/tv_focusable.dart';
import 'subtitle_selector.dart';

class PlayerControls extends StatelessWidget {
  final PlayerController controller;
  final bool isFullscreen;
  final VoidCallback? onPiPPressed;

  const PlayerControls({
    super.key,
    required this.controller,
    this.isFullscreen = true,
    this.onPiPPressed,
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
                  TvFocusable(
                    onTap: () => Get.back(),
                    scale: 1.15,
                    borderRadius: BorderRadius.circular(24),
                    child: IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(AppIcons.back, color: Colors.white),
                    ),
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
            child: _buildControlsRow(context),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsRow(BuildContext context) {
    final leftButtons = <Widget>[
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
        icon: AppIcons.stop,
        onPressed: controller.stopAndClose,
        size: isFullscreen ? 32 : 24,
      ),
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
    ];

    final rightButtons = <Widget>[
      _PopupMenuButton<AspectRatioMode>(
        icon: AppIcons.aspectRatio,
        items: AspectRatioMode.values,
        labelBuilder: (mode) => Text(mode.displayName),
        onSelected: (mode) => controller.setAspectRatio(mode),
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
        TvFocusable(
          onTap: () => _showSubtitlesSheet(context),
          scale: 1.15,
          borderRadius: BorderRadius.circular(24),
          child: IconButton(
            onPressed: () => _showSubtitlesSheet(context),
            icon: const Icon(AppIcons.subtitles,
                color: Colors.white),
            tooltip: 'Subtitles',
          ),
        ),
        TvFocusable(
          onTap: () => _showAudioTracksSheet(context),
          scale: 1.15,
          borderRadius: BorderRadius.circular(24),
          child: IconButton(
            onPressed: () => _showAudioTracksSheet(context),
            icon: const Icon(AppIcons.audioTrack,
                color: Colors.white),
            tooltip: 'Audio Tracks',
          ),
        ),
        if (onPiPPressed != null || Platform.isAndroid)
          TvFocusable(
            onTap: onPiPPressed ??
                () => controller.enterPictureInPicture(),
            scale: 1.15,
            borderRadius: BorderRadius.circular(24),
            child: IconButton(
              onPressed: onPiPPressed ??
                  () => controller.enterPictureInPicture(),
              icon: const Icon(Icons.picture_in_picture_alt,
                  color: Colors.white),
              tooltip: 'Picture-in-Picture',
            ),
          ),
        TvFocusable(
          onTap: () => _toggleFullscreen(context),
          scale: 1.15,
          borderRadius: BorderRadius.circular(24),
          child: IconButton(
            onPressed: () => _toggleFullscreen(context),
            icon: const Icon(AppIcons.fullscreenExit,
                color: Colors.white),
          ),
        ),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final leftWidth = leftButtons.fold<double>(
          0,
          (sum, w) => sum + (_estimateButtonWidth(w) ?? 0),
        );
        final rightWidth = rightButtons.fold<double>(
          0,
          (sum, w) => sum + (_estimateButtonWidth(w) ?? 0),
        );
        final minGap = 12.0;

        if (availableWidth > leftWidth + rightWidth + minGap + 40) {
          return Row(
            children: [
              ...leftButtons,
              const Spacer(),
              ...rightButtons,
            ],
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
            child: Row(
            children: [
              ...leftButtons,
              SizedBox(width: minGap),
              ...rightButtons,
            ],
          ),
        );
      },
    );
  }

  double? _estimateButtonWidth(Widget widget) {
    if (widget is _ControlButton) {
      return widget.size + 20;
    }
    if (widget is _PopupMenuButton) {
      return 44;
    }
    if (widget is IconButton) {
      return 48;
    }
    return 44;
  }

  void _showSubtitlesSheet(BuildContext context) async {
    final tracks = await controller.getAvailableSubtitleTracks();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Obx(() {
          final selected = controller.selectedSubtitleTrackRx.value;
          return SafeArea(
            child: SubtitleSelector(
              tracks: tracks,
              selectedTrackId: selected,
              onSelected: (trackId) {
                controller.setSubtitleTrack(trackId);
                Navigator.of(ctx).pop();
              },
            ),
          );
        });
      },
    );
  }

  void _showAudioTracksSheet(BuildContext context) async {
    final tracks = await controller.getAvailableAudioTracks();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Obx(() {
          final selected = controller.selectedAudioTrackRx.value;
          return SafeArea(
            child: AudioTrackSelector(
              tracks: tracks,
              selectedTrackId: selected,
              onSelected: (trackId) {
                controller.setAudioTrack(trackId);
                Navigator.of(ctx).pop();
              },
            ),
          );
        });
      },
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
    return TvFocusable(
      onTap: onPressed,
      scale: 1.15,
      borderRadius: BorderRadius.circular(size),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: size, color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        constraints: BoxConstraints(minWidth: size + 16, minHeight: size + 16),
      ),
    );
  }
}

class _PopupMenuButton<T> extends StatefulWidget {
  final IconData icon;
  final List<T> items;
  final Widget Function(T) labelBuilder;
  final ValueChanged<T> onSelected;

  const _PopupMenuButton({
    super.key,
    required this.icon,
    required this.items,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  State<_PopupMenuButton<T>> createState() => _PopupMenuButtonState<T>();
}

class _PopupMenuButtonState<T> extends State<_PopupMenuButton<T>> {
  final GlobalKey<PopupMenuButtonState<T>> _popupKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: () => _popupKey.currentState?.showButtonMenu(),
      scale: 1.15,
      borderRadius: BorderRadius.circular(24),
      child: PopupMenuButton<T>(
        key: _popupKey,
        icon: Icon(widget.icon, color: Colors.white, size: 20),
        onSelected: widget.onSelected,
        itemBuilder: (context) {
          return widget.items
              .map((item) => PopupMenuItem<T>(
                    value: item,
                    child: widget.labelBuilder(item),
                  ))
              .toList();
        },
      ),
    );
  }
}
