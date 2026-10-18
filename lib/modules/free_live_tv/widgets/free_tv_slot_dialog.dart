import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/services/free_tv_slot_service.dart';
import 'package:stream_hub/shared/widgets/channel_placeholder.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

/// Modal dialogs and sheets for managing the 10 Free Channel Pass:
/// 1. Add or Upgrade dialog (when <10 channels used)
/// 2. Limit reached paywall (when 10/10 channels used)
/// 3. Channel Swap / Slot Manager sheet
class FreeTvSlotDialog {
  /// Prompt when tapping an unselected channel while free slots remain (<10).
  static Future<void> showAddOrUpgrade({
    required BuildContext context,
    required FreeTvChannel channel,
    required FreeTvSlotService slotService,
    required VoidCallback onAddedAndPlay,
  }) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final remaining = slotService.remainingSlots;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Channel Header Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: AppRadius.medium,
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: AppRadius.small,
                        ),
                        child: channel.logo != null && channel.logo!.trim().isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: channel.logo!,
                                fit: BoxFit.contain,
                                errorWidget: (context, url, error) =>
                                    const ChannelPlaceholder(iconSize: 24),
                              )
                            : const ChannelPlaceholder(iconSize: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              channel.name,
                              style: AppTypography.getTitle(
                                color: colorScheme.onSurface,
                              ).copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${channel.country} • ${channel.categories.isNotEmpty ? channel.categories.first : "Live TV"}',
                              style: AppTypography.getCaption(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '$remaining SLOT${remaining == 1 ? '' : 'S'} LEFT',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Explanation
                Text(
                  'Add to Your 10 Free Channels',
                  style: AppTypography.getTitle(
                    color: colorScheme.onSurface,
                  ).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'StreamHub gives you 10 free channels to watch anytime. Would you like to add "${channel.name}" as one of your 10 free channels, or upgrade to VIP for unlimited channels?',
                  style: AppTypography.getBody(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Action 1: Add to Free Pass & Play
                TvFocusable(
                  autofocus: true,
                  onTap: () async {
                    await slotService.addChannel(channel.id);
                    if (bottomSheetContext.mounted) {
                      Navigator.of(bottomSheetContext).pop();
                    }
                    onAddedAndPlay();
                  },
                  borderRadius: AppRadius.pill,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: AppRadius.pill,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_circle_fill_rounded, color: Colors.black, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Add to Free Pass & Play',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Action 2: Upgrade to VIP (Unlimited)
                TvFocusable(
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    Get.toNamed(AppRoutes.subscription);
                  },
                  borderRadius: AppRadius.pill,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: AppRadius.pill,
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Upgrade to VIP (₦1,000/mo) - Unlimited',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Action 3: Cancel
                TvFocusable(
                  onTap: () => Navigator.of(bottomSheetContext).pop(),
                  borderRadius: AppRadius.pill,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: Text(
                      'Cancel',
                      style: AppTypography.getLabel(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Prompt when tapping an unselected channel after all 10 free slots are used.
  static Future<void> showLimitReached({
    required BuildContext context,
    required FreeTvChannel channel,
    required FreeTvSlotService slotService,
    required List<FreeTvChannel> allChannels,
    required void Function(FreeTvChannel channel) onSwappedAndPlay,
  }) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Warning / Limit Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFFF59E0B),
                    size: 32,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                Text(
                  '10 Free Channel Limit Reached',
                  style: AppTypography.getTitle(
                    color: colorScheme.onSurface,
                  ).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'You have picked all 10 of your free channels. Upgrade to VIP for unlimited access to all channels, or swap one of your 10 free channels with "${channel.name}".',
                  style: AppTypography.getBody(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Option 1: Upgrade to VIP (Recommended)
                TvFocusable(
                  autofocus: true,
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    Get.toNamed(AppRoutes.subscription);
                  },
                  borderRadius: AppRadius.pill,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: AppRadius.pill,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stars_rounded, color: Colors.black, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Upgrade to VIP - Unlimited Access',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Option 2: Swap a Free Channel
                TvFocusable(
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    showManageSlots(
                      context: context,
                      slotService: slotService,
                      allChannels: allChannels,
                      channelToSwapIn: channel,
                      onChannelSelected: onSwappedAndPlay,
                    );
                  },
                  borderRadius: AppRadius.pill,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: AppRadius.pill,
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          color: colorScheme.onSurface,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Swap with One of My 10 Channels',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Cancel
                TvFocusable(
                  onTap: () => Navigator.of(bottomSheetContext).pop(),
                  borderRadius: AppRadius.pill,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: Text(
                      'Cancel',
                      style: AppTypography.getLabel(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Full management and swap sheet showing the user's picked 10 channels.
  static Future<void> showManageSlots({
    required BuildContext context,
    required FreeTvSlotService slotService,
    required List<FreeTvChannel> allChannels,
    FreeTvChannel? channelToSwapIn,
    void Function(FreeTvChannel channel)? onChannelSelected,
  }) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSwapMode = channelToSwapIn != null;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return Container(
          height: MediaQuery.of(bottomSheetContext).size.height * 0.75,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSwapMode
                                      ? 'Choose Channel to Replace'
                                      : 'Manage Free Channels',
                                  style: AppTypography.getTitle(
                                    color: colorScheme.onSurface,
                                  ).copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isSwapMode
                                      ? 'Tap Replace to swap with "${channelToSwapIn.name}"'
                                      : 'You can remove channels to free up slots anytime',
                                  style: AppTypography.getCaption(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () =>
                                Navigator.of(bottomSheetContext).pop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Channel List
                Expanded(
                  child: Obx(() {
                    final selectedIds = slotService.selectedChannelIds;
                    if (selectedIds.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tv_off_rounded,
                                size: 48,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'No Free Channels Selected',
                                style: AppTypography.getTitle(
                                  color: colorScheme.onSurface,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Browse the catalog and tap any channel to add it to your 10 free slots.',
                                style: AppTypography.getBody(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: selectedIds.length,
                      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (ctx, index) {
                        final channelId = selectedIds[index];
                        final channel = allChannels.firstWhereOrNull(
                          (c) => c.id == channelId,
                        );
                        final name = channel?.name ?? 'Channel ($channelId)';
                        final logo = channel?.logo;
                        final category = channel != null && channel.categories.isNotEmpty
                            ? channel.categories.first
                            : (channel?.country ?? 'Live TV');

                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                            borderRadius: AppRadius.medium,
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: AppRadius.small,
                                ),
                                child: logo != null && logo.trim().isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: logo,
                                        fit: BoxFit.contain,
                                        errorWidget: (context, url, error) =>
                                            const ChannelPlaceholder(iconSize: 20),
                                      )
                                    : const ChannelPlaceholder(iconSize: 20),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: AppTypography.getLabel(
                                        color: colorScheme.onSurface,
                                      ).copyWith(fontWeight: FontWeight.w700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      category,
                                      style: AppTypography.getCaption(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),

                              if (isSwapMode) ...[
                                // Replace Button
                                TvFocusable(
                                  onTap: () async {
                                    await slotService.swapChannel(
                                      oldChannelId: channelId,
                                      newChannelId: channelToSwapIn.id,
                                    );
                                    if (bottomSheetContext.mounted) {
                                      Navigator.of(bottomSheetContext).pop();
                                    }
                                    onChannelSelected?.call(channelToSwapIn);
                                    Get.snackbar(
                                      'Channel Swapped',
                                      'Replaced $name with ${channelToSwapIn.name}',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: const Color(0xFF10B981)
                                          .withValues(alpha: 0.9),
                                      colorText: Colors.white,
                                      margin: const EdgeInsets.all(AppSpacing.md),
                                      duration: const Duration(seconds: 3),
                                    );
                                  },
                                  borderRadius: AppRadius.pill,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.xs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: AppRadius.pill,
                                    ),
                                    child: const Text(
                                      'Replace',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                // Play Channel Button
                                if (channel != null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: Color(0xFF10B981),
                                      size: 26,
                                    ),
                                    tooltip: 'Play Channel',
                                    onPressed: () {
                                      Navigator.of(bottomSheetContext).pop();
                                      onChannelSelected?.call(channel);
                                    },
                                  ),
                                // Remove Channel Button
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: colorScheme.error,
                                    size: 22,
                                  ),
                                  tooltip: 'Remove',
                                  onPressed: () async {
                                    await slotService.removeChannel(channelId);
                                  },
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  }),
                ),

                // Bottom VIP Upgrade banner
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: TvFocusable(
                    onTap: () {
                      Navigator.of(bottomSheetContext).pop();
                      Get.toNamed(AppRoutes.subscription);
                    },
                    borderRadius: AppRadius.medium,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: AppRadius.medium,
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Want all channels? Upgrade to VIP for ₦1,000/mo',
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: Color(0xFFF59E0B)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
