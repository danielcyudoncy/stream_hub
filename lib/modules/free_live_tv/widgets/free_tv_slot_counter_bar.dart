import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/services/free_tv_slot_service.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';
import 'free_tv_slot_dialog.dart';

/// Top capsule/bar displayed in Free Live TV showing the user's 10 Free Channel Pass
/// status (or VIP badge if subscribed/trialing).
class FreeTvSlotCounterBar extends StatelessWidget {
  final FreeTvSlotService slotService;
  final List<FreeTvChannel> allChannels;
  final void Function(FreeTvChannel channel)? onChannelSelected;

  const FreeTvSlotCounterBar({
    super.key,
    required this.slotService,
    required this.allChannels,
    this.onChannelSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isVip = slotService.isVip;
      if (isVip) {
        return _buildVipCapsule(context);
      }
      return _buildFreeSlotsCapsule(context);
    });
  }

  Widget _buildVipCapsule(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
        borderRadius: AppRadius.medium,
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Color(0xFFF59E0B),
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'VIP Pass Active',
                      style: AppTypography.getLabel(
                        color: const Color(0xFFF59E0B),
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'UNLIMITED',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'All Free TV channels are unlocked and ad-free',
                  style: AppTypography.getCaption(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TvFocusable(
            onTap: () {
              slotService.simulateFreeTier.value = true;
            },
            borderRadius: AppRadius.pill,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: AppRadius.pill,
                border: Border.all(
                  color: Colors.white30,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.science_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Test Free Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeSlotsCapsule(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final used = slotService.usedSlots;
    final max = FreeTvSlotService.maxSlots;
    final remaining = slotService.remainingSlots;
    final isFull = slotService.isFull;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: AppRadius.medium,
        border: Border.all(
          color: isFull
              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
              : AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isFull
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981))
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFull ? Icons.lock_outline_rounded : Icons.check_circle_outline_rounded,
                  color: isFull ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '10 Free Channel Pass',
                          style: AppTypography.getLabel(
                            color: colorScheme.onSurface,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isFull
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                                : const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$used / $max USED',
                            style: TextStyle(
                              color: isFull
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF10B981),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isFull
                          ? 'All 10 free slots used. Tap a channel to swap or upgrade to VIP.'
                          : '$remaining slot${remaining == 1 ? '' : 's'} left. Pick your favorite channels for free.',
                      style: AppTypography.getCaption(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (used > 0)
                TvFocusable(
                  onTap: () {
                    FreeTvSlotDialog.showManageSlots(
                      context: context,
                      slotService: slotService,
                      allChannels: allChannels,
                      onChannelSelected: onChannelSelected,
                    );
                  },
                  borderRadius: AppRadius.pill,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: AppRadius.pill,
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 14,
                          color: colorScheme.onSurface,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Manage',
                          style: AppTypography.getCaption(
                            color: colorScheme.onSurface,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isFull) ...[
                const SizedBox(width: 6),
                TvFocusable(
                  onTap: () => Get.toNamed(AppRoutes.subscription),
                  borderRadius: AppRadius.pill,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: AppRadius.pill,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          size: 14,
                          color: Colors.black,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'VIP',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (slotService.simulateFreeTier.value) ...[
                const SizedBox(width: 6),
                TvFocusable(
                  onTap: () {
                    slotService.simulateFreeTier.value = false;
                  },
                  borderRadius: AppRadius.pill,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: AppRadius.pill,
                      border: Border.all(
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.restore_rounded,
                          size: 13,
                          color: Color(0xFFF59E0B),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Restore VIP',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // 10 Slot Segments Bar
          Row(
            children: List.generate(max, (index) {
              final isFilled = index < used;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(
                    right: index < max - 1 ? 3 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: isFilled
                        ? const Color(0xFF10B981)
                        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
