import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/media_item.dart';
import '../../data/models/channel.dart';
import 'channel_logo.dart';
import 'live_badge.dart';

class ChannelCard extends StatelessWidget {
  final MediaItem channel;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool showFavoriteButton;
  final bool showChannelNumber;
  final bool showHD;

  const ChannelCard({
    super.key,
    required this.channel,
    this.onTap,
    this.onFavorite,
    this.showFavoriteButton = true,
    this.showChannelNumber = true,
    this.showHD = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isChannel = channel is Channel;
    final channelNum = isChannel ? (channel as Channel).number : null;
    final isLive = isChannel ? (channel as Channel).isLive : false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: AppRadius.medium,
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  Center(
                    child: ChannelLogo(
                      channel: channel,
                      size: 64.0,
                      showLiveIndicator: isLive,
                    ),
                  ),
                  if (isLive)
                    Positioned(
                      top: AppSpacing.xxs,
                      left: AppSpacing.xxs,
                      child: LiveBadge(isLive: true),
                    ),
                  if (showHD && channel.metadata['resolution'] != null)
                    Positioned(
                      top: AppSpacing.xxs,
                      right: AppSpacing.xxs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.0,
                          vertical: 1.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: AppRadius.small,
                        ),
                        child: Text(
                          channel.metadata['resolution'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (showFavoriteButton)
                    Positioned(
                      top: AppSpacing.xxs,
                      right: AppSpacing.xxs,
                      child: _FavoriteButton(
                        isFavorite: channel.favorite,
                        onTap: onFavorite,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showChannelNumber && channelNum != null) ...[
                    Text(
                      channelNum,
                      style: AppTypography.getCaption(
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                  ],
                  Text(
                    channel.title,
                    style: AppTypography.getBody(
                      color: colorScheme.onSurface,
                      scale: 0.9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback? onTap;

  const _FavoriteButton({
    required this.isFavorite,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.small,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? AppColors.darkError : Colors.white,
            size: 18.0,
          ),
        ),
      ),
    );
  }
}