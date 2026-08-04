import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';

class MiniPlayerPage extends GetView<PlayerController> {
  final VoidCallback? onExpand;

  const MiniPlayerPage({super.key, this.onExpand});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onExpand,
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_outline, color: Colors.white54),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Obx(() {
                  final title = controller.sessionRx.value?.metadata.title ?? 'Live';
                  return Text(
                    title,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                }),
              ),
            ),
            Obx(() {
              final state = controller.stateRx.value;
              if (state == PlaybackState.playing) {
                return IconButton(
                  onPressed: () => controller.pause(),
                  icon: const Icon(Icons.pause),
                );
              }
              return IconButton(
                onPressed: () => controller.play(),
                icon: const Icon(Icons.play_arrow),
              );
            }),
            IconButton(
              onPressed: onExpand,
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
          ],
        ),
      ),
    );
  }
}
