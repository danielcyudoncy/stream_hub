import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/services/free_tv_slot_service.dart';
import 'package:stream_hub/shared/widgets/channel_placeholder.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

class FreeTvChannelCard extends StatelessWidget {
  final FreeTvChannel channel;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool isList;
  final bool isPlaying;
  final FreeTvSlotService? slotService;

  const FreeTvChannelCard({
    super.key,
    required this.channel,
    this.onTap,
    this.onFavorite,
    this.isList = false,
    this.isPlaying = false,
    this.slotService,
  });

  @override
  Widget build(BuildContext context) {
    if (isList) {
      return _buildListTile(context);
    }
    return _buildGridCard(context);
  }

  Widget _buildGridCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasLogo = channel.logo != null && channel.logo!.trim().isNotEmpty;
    final categoryText = channel.categories.isNotEmpty
        ? channel.categories.first
        : channel.country;

    return TvFocusable(
      onTap: onTap,
      onLongPress: onFavorite,
      borderRadius: AppRadius.medium,
      scale: 1.04,
      child: Container(
        decoration: BoxDecoration(
          color: isPlaying
              ? AppColors.primary.withValues(alpha: 0.15)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: AppRadius.medium,
          border: Border.all(
            color: isPlaying
                ? AppColors.primary
                : colorScheme.outline.withValues(alpha: 0.15),
            width: isPlaying ? 2.0 : 1.0,
          ),
          boxShadow: isPlaying
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo Header Area
                Expanded(
                  child: Container(
                    color: Colors.black26,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Center(
                      child: hasLogo
                          ? CachedNetworkImage(
                              imageUrl: channel.logo!,
                              fit: BoxFit.contain,
                              memCacheWidth: 256,
                              memCacheHeight: 256,
                              placeholder: (context, url) => const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  const ChannelPlaceholder(
                                iconSize: 28,
                                fontSize: 10,
                              ),
                            )
                          : const ChannelPlaceholder(
                              iconSize: 28,
                              fontSize: 10,
                            ),
                    ),
                  ),
                ),

                // Channel Info Footer
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.9),
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        channel.name,
                        style: AppTypography.getLabel(
                          color: isPlaying
                              ? AppColors.primary
                              : colorScheme.onSurface,
                        ).copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${channel.country} • $categoryText',
                              style: AppTypography.getCaption(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPlaying) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PLAYING',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Top-left LIVE badge & Free Pass / VIP Slot Badge
            Positioned(
              top: 6,
              left: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fiber_manual_record_rounded,
                          color: Colors.white,
                          size: 8,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildSlotBadge(context),
                ],
              ),
            ),

            // Top-right Favorite Toggle Button
            Positioned(
              top: 4,
              right: 4,
              child: ExcludeFocus(
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: Icon(
                      channel.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: channel.isFavorite ? Colors.amber : Colors.white70,
                      size: 20,
                    ),
                    onPressed: onFavorite,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasLogo = channel.logo != null && channel.logo!.trim().isNotEmpty;
    final categoryText = channel.categories.isNotEmpty
        ? channel.categories.first
        : channel.country;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: TvFocusable(
        onTap: onTap,
        onLongPress: onFavorite,
        borderRadius: AppRadius.medium,
        scale: 1.02,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isPlaying
                ? AppColors.primary.withValues(alpha: 0.15)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: AppRadius.medium,
            border: Border.all(
              color: isPlaying
                  ? AppColors.primary
                  : colorScheme.outline.withValues(alpha: 0.1),
              width: isPlaying ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Logo
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(4),
                child: hasLogo
                    ? CachedNetworkImage(
                        imageUrl: channel.logo!,
                        fit: BoxFit.contain,
                        memCacheWidth: 96,
                        memCacheHeight: 96,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            const ChannelPlaceholder(
                          iconSize: 20,
                          fontSize: 8,
                        ),
                      )
                    : const ChannelPlaceholder(
                        iconSize: 20,
                        fontSize: 8,
                      ),
              ),
              AppSpacing.widthMD,

              // Name & Category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      channel.name,
                      style: AppTypography.getLabel(
                        color: isPlaying
                            ? AppColors.primary
                            : colorScheme.onSurface,
                      ).copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${channel.country} • $categoryText',
                      style: AppTypography.getCaption(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              _buildSlotBadge(context),
              const SizedBox(width: 6),

              // Live indicator / Playing badge
              if (isPlaying)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PLAYING',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Favorite toggle
              ExcludeFocus(
                child: IconButton(
                  icon: Icon(
                    channel.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: channel.isFavorite ? Colors.amber : colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  onPressed: onFavorite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotBadge(BuildContext context) {
    final service = slotService ??
        (Get.isRegistered<FreeTvSlotService>()
            ? Get.find<FreeTvSlotService>()
            : null);
    if (service == null) return const SizedBox.shrink();

    return Obx(() {
      if (service.isVip) return const SizedBox.shrink();
      final isSelected = service.selectedChannelIds.contains(channel.id);
      if (isSelected) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.black, size: 9),
              SizedBox(width: 2),
              Text(
                'FREE PASS',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, color: Colors.black, size: 9),
              SizedBox(width: 2),
              Text(
                'VIP',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      }
    });
  }
}
