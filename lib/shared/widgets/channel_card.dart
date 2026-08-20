import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_url_formatter.dart';
import '../../data/models/media_item.dart';
import '../../data/models/channel.dart';
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
    final rawPoster = channel.poster ??
        channel.thumbnail ??
        channel.metadata['stream_icon'] ??
        channel.metadata['streamIcon'] ??
        channel.metadata['logo'];
    final posterUrl = ImageUrlFormatter.format(rawPoster, item: channel);
    final hasPoster = posterUrl != null && posterUrl.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.medium,
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
                  fit: StackFit.expand,
                  children: [
                     // Channel logo / poster image with cover fit
                    if (hasPoster)
                      Image.network(
                        posterUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholder(colorScheme),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        },
                      )
                    else
                      _buildPlaceholder(colorScheme),

                    // Contrast gradient overlay for badges and favorite button
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.45),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                            stops: const [0.0, 0.35, 0.65, 1.0],
                          ),
                        ),
                      ),
                    ),

                    if (isLive)
                      Positioned(
                        top: AppSpacing.xxs,
                        left: AppSpacing.xxs,
                        child: const LiveBadge(isLive: true),
                      ),

                    if (showHD && channel.metadata['resolution'] != null)
                      Positioned(
                        bottom: AppSpacing.xxs,
                        left: AppSpacing.xxs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: AppRadius.small,
                          ),
                          child: Text(
                            channel.metadata['resolution'] as String? ?? '',
                            style: const TextStyle(
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
                  mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.live_tv_rounded,
          color: colorScheme.primary.withValues(alpha: 0.6),
          size: 40.0,
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFavorite ? AppColors.darkError : Colors.white,
          size: 18.0,
        ),
      ),
    );
  }
}