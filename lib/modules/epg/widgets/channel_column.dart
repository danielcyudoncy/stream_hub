import 'package:flutter/material.dart';
import 'package:stream_hub/modules/epg/models/epg_channel.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/shared/widgets/channel_logo.dart';
import 'package:stream_hub/shared/widgets/live_badge.dart';
import 'package:stream_hub/shared/widgets/provider_chip.dart';

class ChannelColumn extends StatelessWidget {
  final EPGChannel channel;
  final EPGProgram? currentProgram;
  final EPGProgram? nextProgram;
  final VoidCallback? onTap;
  final bool showFavoriteButton;
  final bool showProviderBadge;
  final bool showChannelNumber;

  const ChannelColumn({
    super.key,
    required this.channel,
    this.currentProgram,
    this.nextProgram,
    this.onTap,
    this.showFavoriteButton = true,
    this.showProviderBadge = true,
    this.showChannelNumber = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (showChannelNumber && channel.number != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    margin: const EdgeInsets.only(right: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: AppRadius.small,
                    ),
                    child: Text(
                      channel.number!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ChannelLogo(
                  channel: channel,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (currentProgram != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          currentProgram!.title,
                          style: AppTypography.getCaption(
                            color: colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (showFavoriteButton)
                  IconButton(
                    icon: Icon(
                      channel.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: channel.isFavorite
                          ? AppColors.darkError
                          : colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: () {},
                  ),
              ],
            ),
            if (showProviderBadge && channel.providerBadge != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              ProviderChip(item: channel),
            ],
            if (currentProgram != null && currentProgram!.isLive) ...[
              const SizedBox(height: AppSpacing.xxs),
              const LiveBadge(),
            ],
            if (nextProgram != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Next: ${nextProgram!.title}',
                style: AppTypography.getCaption(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}