// modules/player/widgets/player_controls.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                      final title =
                          controller.sessionRx.value?.metadata.title ?? '';
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
    final buttonScale = isFullscreen ? 1.2 : 1.12;
    final leftButtons = <Widget>[
      _ControlButton(
        icon: AppIcons.previous,
        onPressed: controller.previous,
        size: isFullscreen ? 38 : 28,
        autofocus: isFullscreen,
      ),
      _ControlButton(
        icon: AppIcons.rewind,
        onPressed: () =>
            controller.seek(controller.position - const Duration(seconds: 10)),
        size: isFullscreen ? 38 : 28,
      ),
      Obx(() {
        final state = controller.stateRx.value;
        final isPlaying = state == PlaybackState.playing;
        return _ControlButton(
          icon: isPlaying ? AppIcons.pause : AppIcons.play,
          onPressed: isPlaying ? controller.pause : controller.play,
          size: isFullscreen ? 60 : 42,
          autofocus: isFullscreen,
          accent: true,
        );
      }),
      _ControlButton(
        icon: AppIcons.stop,
        onPressed: controller.stopAndClose,
        size: isFullscreen ? 38 : 28,
      ),
      _ControlButton(
        icon: AppIcons.forward,
        onPressed: () =>
            controller.seek(controller.position + const Duration(seconds: 10)),
        size: isFullscreen ? 38 : 28,
      ),
      _ControlButton(
        icon: AppIcons.next,
        onPressed: controller.next,
        size: isFullscreen ? 38 : 28,
      ),
    ];

    final rightButtons = <Widget>[
      _PopupMenuButton<AspectRatioMode>(
        icon: AppIcons.aspectRatio,
        items: AspectRatioMode.values,
        labelBuilder: (mode) => Text(mode.displayName),
        onSelected: (mode) => controller.setAspectRatio(mode),
        scale: buttonScale,
      ),
      _PopupMenuButton<PlaybackSpeed>(
        icon: AppIcons.speed,
        items: PlaybackSpeed.values,
        labelBuilder: (speed) => Text(speed.label),
        onSelected: (speed) => controller.setSpeed(speed),
        scale: buttonScale,
      ),
      if (isFullscreen) ...[
        _PopupMenuButton<PlayerQuality>(
          icon: AppIcons.quality,
          items: PlayerQuality.values,
          labelBuilder: (q) => Text(q.displayName),
          onSelected: (q) => controller.setQuality(q),
          scale: buttonScale,
        ),
        TvFocusable(
          autofocus: false,
          onTap: () => _showSubtitlesSheet(context),
          scale: buttonScale,
          borderRadius: BorderRadius.circular(24),
          child: IconButton(
            onPressed: () => _showSubtitlesSheet(context),
            icon: const Icon(AppIcons.subtitles, color: Colors.white),
            tooltip: 'Subtitles',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ),
        TvFocusable(
          autofocus: false,
          onTap: () => _showAudioTracksSheet(context),
          scale: buttonScale,
          borderRadius: BorderRadius.circular(24),
          child: IconButton(
            onPressed: () => _showAudioTracksSheet(context),
            icon: const Icon(AppIcons.audioTrack, color: Colors.white),
            tooltip: 'Audio Tracks',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ),
        if (onPiPPressed != null || Platform.isAndroid)
          TvFocusable(
            autofocus: false,
            onTap: onPiPPressed ?? () => controller.enterPictureInPicture(),
            scale: buttonScale,
            borderRadius: BorderRadius.circular(24),
            child: IconButton(
              onPressed:
                  onPiPPressed ?? () => controller.enterPictureInPicture(),
              icon: const Icon(
                Icons.picture_in_picture_alt,
                color: Colors.white,
              ),
              tooltip: 'Picture-in-Picture',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
          ),
        TvFocusable(
          autofocus: false,
          onTap: () => _toggleFullscreen(context),
          scale: buttonScale,
          borderRadius: BorderRadius.circular(24),
          child: IconButton(
            onPressed: () => _toggleFullscreen(context),
            icon: const Icon(AppIcons.fullscreenExit, color: Colors.white),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ),
      ],
    ];

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: LayoutBuilder(
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
          final minGap = isFullscreen ? 18.0 : 12.0;

          if (availableWidth > leftWidth + rightWidth + minGap + 40) {
            return Row(
              children: [...leftButtons, const Spacer(), ...rightButtons],
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
      ),
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
    // These controls are rendered inside the fullscreen player route, so the
    // exit-fullscreen affordance returns to the screen it was launched from.
    Get.back();
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
        child: TvFocusable(
          scale: 1.02,
          borderRadius: BorderRadius.circular(4),
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              controller.seek(controller.position - const Duration(seconds: 10));
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              controller.seek(controller.position + const Duration(seconds: 10));
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
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
        ),
      );
    });
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final bool autofocus;
  final bool accent;

  const _ControlButton({
    required this.icon,
    required this.onPressed,
    this.size = 32,
    this.autofocus = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = accent
        ? Colors.red.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.06);
    final border = accent
        ? Colors.red.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.12);

    return TvFocusable(
      autofocus: autofocus,
      onTap: onPressed,
      scale: accent ? 1.22 : 1.14,
      borderRadius: BorderRadius.circular(size * 0.7),
      child: Container(
        width: size + 18,
        height: size + 18,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * 0.7),
          border: Border.all(color: border, width: 1.25),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: size, color: Colors.white),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
    );
  }
}

class _PopupMenuButton<T> extends StatefulWidget {
  final IconData icon;
  final List<T> items;
  final Widget Function(T) labelBuilder;
  final ValueChanged<T> onSelected;
  final double scale;

  const _PopupMenuButton({
    super.key,
    required this.icon,
    required this.items,
    required this.labelBuilder,
    required this.onSelected,
    this.scale = 1.14,
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
      scale: widget.scale,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: PopupMenuButton<T>(
          key: _popupKey,
          icon: Icon(widget.icon, color: Colors.white, size: 20),
          onSelected: widget.onSelected,
          itemBuilder: (context) {
            return widget.items
                .map(
                  (item) => PopupMenuItem<T>(
                    value: item,
                    child: widget.labelBuilder(item),
                  ),
                )
                .toList();
          },
        ),
      ),
    );
  }
}
