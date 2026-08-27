import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../controllers/multi_view_controller.dart';

class MultiViewSlotTile extends StatelessWidget {
  final int slotIndex;
  final MultiViewController controller;
  final VoidCallback onSelectChannel;

  const MultiViewSlotTile({
    super.key,
    required this.slotIndex,
    required this.controller,
    required this.onSelectChannel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 220 || constraints.maxHeight < 160;

        return Obx(() {
          final channel = controller.slots[slotIndex].value;
          final playerCtrl = controller.slotControllers[slotIndex];
          final isAudioActive = controller.activeAudioSlot.value == slotIndex;

          return Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: AppRadius.medium,
              border: Border.all(
                color: isAudioActive
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.15),
                width: isAudioActive ? 2.5 : 1.0,
              ),
              boxShadow: isAudioActive
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12.0,
                        spreadRadius: 2.0,
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (channel != null && playerCtrl != null) ...[
                  // Video Player Surface
                  Obx(() {
                    playerCtrl.playbackController.engine.engineKindRx.value;
                    final adapter = playerCtrl.playbackController.engine.adapter;
                    return adapter.buildPlayerWidget();
                  }),

                  // Tap anywhere to set audio focus
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => controller.setActiveAudioSlot(slotIndex),
                    ),
                  ),

                  // Top Controls Overlay
                  Positioned(
                    top: AppSpacing.xs,
                    left: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Audio Focus Indicator Badge
                          GestureDetector(
                            onTap: () => controller.setActiveAudioSlot(slotIndex),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 3.0,
                              ),
                              decoration: BoxDecoration(
                                color: isAudioActive
                                    ? AppColors.primary
                                    : Colors.black.withValues(alpha: 0.7),
                                borderRadius: AppRadius.small,
                                border: Border.all(
                                  color: isAudioActive
                                      ? Colors.white
                                      : Colors.white24,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isAudioActive
                                        ? Icons.volume_up_rounded
                                        : Icons.volume_off_rounded,
                                    size: 13.0,
                                    color: Colors.white,
                                  ),
                                  if (!isCompact) ...[
                                    const SizedBox(width: 4.0),
                                    Text(
                                      isAudioActive ? 'AUDIO ON' : 'MUTED',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8.0),

                          // Change Channel Button
                          IconButton(
                            padding: const EdgeInsets.all(4.0),
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.swap_horiz_rounded,
                              color: Colors.white70,
                              size: 18.0,
                            ),
                            tooltip: 'Change Channel',
                            onPressed: onSelectChannel,
                          ),
                          const SizedBox(width: 4.0),

                          // Clear Slot Button
                          IconButton(
                            padding: const EdgeInsets.all(4.0),
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                              size: 18.0,
                            ),
                            tooltip: 'Remove from Multi-View',
                            onPressed: () => controller.clearSlot(slotIndex),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Channel Info Bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3.0,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (channel.thumbnail != null || channel.poster != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3.0),
                              child: Image.network(
                                ImageUrlFormatter.format(
                                  channel.thumbnail ?? channel.poster,
                                  item: channel,
                                ) ?? '',
                                width: 16.0,
                                height: 16.0,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.live_tv, size: 14.0, color: Colors.white54),
                              ),
                            ),
                            const SizedBox(width: 5.0),
                          ],
                          Expanded(
                            child: Text(
                              channel.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.0,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Empty Slot Tile
                  Center(
                    child: InkWell(
                      onTap: onSelectChannel,
                      borderRadius: AppRadius.medium,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: isCompact ? 36.0 : 44.0,
                                height: isCompact ? 36.0 : 44.0,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.6),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.add_rounded,
                                  color: AppColors.primary,
                                  size: isCompact ? 22.0 : 26.0,
                                ),
                              ),
                              const SizedBox(height: 6.0),
                              Text(
                                'Select Channel',
                                style: AppTypography.getBody(
                                  color: colorScheme.onSurface,
                                ).copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isCompact ? 11.5 : 13.0,
                                ),
                              ),
                              Text(
                                'Slot ${slotIndex + 1}',
                                style: AppTypography.getCaption(
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                ).copyWith(
                                  fontSize: isCompact ? 9.5 : 11.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        });
      },
    );
  }
}
