import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_url_formatter.dart';
import '../../core/utils/title_formatter.dart';
import '../../data/models/media_item.dart';
import '../../data/models/channel.dart';
import 'cached_home_image.dart';
import 'channel_placeholder.dart';
import 'tv_focusable.dart';

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
    final rawPoster = channel.poster ??
        channel.thumbnail ??
        channel.metadata['stream_icon'] ??
        channel.metadata['streamIcon'] ??
        channel.metadata['logo'];
    final posterUrl = ImageUrlFormatter.format(rawPoster, item: channel);
    final hasPoster = posterUrl != null && posterUrl.isNotEmpty;

    return TvFocusable(
      onTap: onTap,
      borderRadius: AppRadius.medium,
      scale: 1.05,
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
                    // Channel logo / poster image with contain fit
                    if (hasPoster)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: CachedHomeImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            errorBuilder: (context, error) =>
                                _buildPlaceholder(colorScheme),
                          ),
                        ),
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
                      TitleFormatter.formatChannelTitle(channel.title),
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

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: const ChannelPlaceholder(),
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