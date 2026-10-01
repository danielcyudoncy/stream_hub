import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../shared/widgets/keep_screen_on.dart';
import '../../../shared/widgets/tv_focusable.dart';
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
                    return KeepScreenOn(child: adapter.buildPlayerWidget());
                  }),

                  // Remote/D-pad focusable slot: whole tile activates audio focus.
                  // autofocus on slot 0 so the Multi-View screen starts navigable.
                  Positioned.fill(
                    child: TvFocusable(
                      onTap: () => controller.setActiveAudioSlot(slotIndex),
                      autofocus: slotIndex == 0,
                      borderRadius: AppRadius.medium,
                      scale: 1.0,
                      descendantsAreFocusable: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => controller.setActiveAudioSlot(slotIndex),
                      ),
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
                          TvFocusable(
                            onTap: () => controller.setActiveAudioSlot(slotIndex),
                            scale: 1.08,
                            borderRadius: AppRadius.small,
                            focusColor: isAudioActive
                                ? Colors.white
                                : const Color(0xFFFFB74D),
                            focusedBackgroundColor: isAudioActive
                                ? AppColors.primary
                                : const Color(0xFF2C3440),
                            builder: (context, hasFocus) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10.0,
                                vertical: 4.5,
                              ),
                              decoration: BoxDecoration(
                                color: isAudioActive
                                    ? AppColors.primary
                                    : const Color(0xFF1E2430),
                                borderRadius: AppRadius.small,
                                border: Border.all(
                                  color: isAudioActive
                                      ? Colors.white
                                      : const Color(0xFFFFB74D),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isAudioActive
                                            ? AppColors.primary
                                            : const Color(0xFFFFB74D))
                                        .withValues(alpha: hasFocus ? 0.6 : 0.25),
                                    blurRadius: hasFocus ? 8.0 : 4.0,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isAudioActive
                                        ? Icons.volume_up_rounded
                                        : Icons.volume_off_rounded,
                                    size: 15.0,
                                    color: isAudioActive
                                        ? Colors.white
                                        : const Color(0xFFFFB74D),
                                  ),
                                  if (!isCompact) ...[
                                    const SizedBox(width: 5.0),
                                    Text(
                                      isAudioActive ? 'AUDIO ON' : 'MUTED',
                                      style: TextStyle(
                                        color: isAudioActive
                                            ? Colors.white
                                            : const Color(0xFFFFB74D),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8.0),

                          // Change Channel Button
                          TvFocusable(
                            onTap: onSelectChannel,
                            scale: 1.15,
                            borderRadius: BorderRadius.circular(16),
                            focusColor: AppColors.primary,
                            focusedBackgroundColor: AppColors.primary,
                            builder: (context, hasFocus) => Container(
                              padding: const EdgeInsets.all(5.0),
                              decoration: BoxDecoration(
                                color: hasFocus
                                    ? AppColors.primary
                                    : Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: hasFocus ? Colors.white : Colors.white24,
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(
                                Icons.swap_horiz_rounded,
                                color: hasFocus ? Colors.white : Colors.white70,
                                size: 18.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6.0),

                          // Clear / Remove Slot Button
                          TvFocusable(
                            onTap: () => controller.clearSlot(slotIndex),
                            scale: 1.15,
                            borderRadius: BorderRadius.circular(16),
                            focusColor: Colors.redAccent,
                            focusedBackgroundColor: Colors.redAccent,
                            builder: (context, hasFocus) => Container(
                              padding: const EdgeInsets.all(5.0),
                              decoration: BoxDecoration(
                                color: hasFocus
                                    ? Colors.redAccent
                                    : Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: hasFocus ? Colors.white : Colors.white24,
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: hasFocus ? Colors.white : Colors.white70,
                                size: 18.0,
                              ),
                            ),
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
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.9),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (channel.thumbnail != null || channel.poster != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4.0),
                              child: Image.network(
                                ImageUrlFormatter.format(
                                  channel.thumbnail ?? channel.poster,
                                  item: channel,
                                ) ?? '',
                                width: 20.0,
                                height: 20.0,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.live_tv, size: 16.0, color: Colors.white54),
                              ),
                            ),
                            const SizedBox(width: 6.0),
                          ],
                          Expanded(
                            child: Text(
                              channel.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.0,
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
                  // Empty Slot Tile: Fills the entire slot
                  Positioned.fill(
                    child: TvFocusable(
                      onTap: onSelectChannel,
                      autofocus: slotIndex == 0,
                      borderRadius: AppRadius.medium,
                      focusColor: AppColors.primary,
                      focusedBackgroundColor: AppColors.primary.withValues(alpha: 0.08),
                      unfocusedBackgroundColor: Colors.transparent,
                      scale: 1.0,
                      builder: (context, hasFocus) => Container(
                        decoration: BoxDecoration(
                          color: hasFocus
                              ? AppColors.primary.withValues(alpha: 0.10)
                              : Colors.white.withValues(alpha: 0.02),
                          borderRadius: AppRadius.medium,
                          border: Border.all(
                            color: hasFocus
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.15),
                            width: hasFocus ? 2.5 : 1.0,
                          ),
                          boxShadow: hasFocus
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 16.0,
                                    spreadRadius: 2.0,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: isCompact ? 38.0 : 50.0,
                                    height: isCompact ? 38.0 : 50.0,
                                    decoration: BoxDecoration(
                                      color: hasFocus
                                          ? AppColors.primary
                                          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: hasFocus
                                            ? Colors.white
                                            : AppColors.primary.withValues(alpha: 0.6),
                                        width: hasFocus ? 2.0 : 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.add_rounded,
                                      color: hasFocus ? Colors.black : AppColors.primary,
                                      size: isCompact ? 22.0 : 28.0,
                                    ),
                                  ),
                                  const SizedBox(height: 8.0),
                                  Text(
                                    'Select Channel',
                                    style: AppTypography.getBody(
                                      color: hasFocus ? Colors.white : colorScheme.onSurface,
                                    ).copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isCompact ? 12.0 : 13.5,
                                    ),
                                  ),
                                  Text(
                                    'Slot ${slotIndex + 1}',
                                    style: AppTypography.getCaption(
                                      color: hasFocus
                                          ? Colors.white70
                                          : colorScheme.onSurface.withValues(alpha: 0.5),
                                    ).copyWith(
                                      fontSize: isCompact ? 10.0 : 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
