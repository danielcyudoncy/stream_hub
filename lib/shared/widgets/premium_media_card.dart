import 'package:flutter/material.dart';
import '../../core/media/enums/media_type.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_url_formatter.dart';
import '../../core/utils/title_formatter.dart';
import '../../data/models/channel.dart';
import '../../data/models/media_item.dart';
import 'cached_home_image.dart';
import 'channel_placeholder.dart';
import 'glass_panel.dart';
import 'tv_focusable.dart';

class PremiumMediaCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final double? width;
  final double aspectRatio;
  final String? overridePosterUrl;
  final ValueChanged<bool>? onFocusChange;
  final double? progress;
  final bool useGlassLabel;

  const PremiumMediaCard({
    super.key,
    required this.item,
    this.onTap,
    this.width,
    this.aspectRatio = 2 / 3,
    this.overridePosterUrl,
    this.onFocusChange,
    this.progress,
    this.useGlassLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isChannel = item is Channel ||
        item.mediaType == MediaType.channel ||
        item.mediaType == MediaType.liveEvent ||
        item.mediaType == MediaType.program;

    final rawPoster = overridePosterUrl ??
        item.poster ??
        item.thumbnail ??
        item.backdrop ??
        item.metadata['stream_icon'] ??
        item.metadata['streamIcon'] ??
        item.metadata['logo'];
    final posterUrl = ImageUrlFormatter.format(rawPoster, item: item);
    final hasPoster = posterUrl != null && posterUrl.isNotEmpty;

    Widget imageWidget;

    if (isChannel) {
      // Channel presentation: framed surface container with centered contained logo
      imageWidget = AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: AppRadius.medium,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.medium,
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.12),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasPoster)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: CachedHomeImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        errorBuilder: (context, url) =>
                            _buildChannelPlaceholder(colorScheme),
                      ),
                    ),
                  )
                else
                  _buildChannelPlaceholder(colorScheme),

                // Top-Right Resolution Badge if available
                if (item.metadata['resolution'] != null)
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5.0,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: AppRadius.small,
                      ),
                      child: Text(
                        item.metadata['resolution'] as String? ?? '',
                        style: const TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Movie / Series Poster Presentation: 2:3 full-bleed cover
      imageWidget = AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: AppRadius.medium,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background placeholder
              Container(color: AppColors.surfaceVariant),

              // Image
              if (hasPoster)
                Positioned.fill(
                  child: CachedHomeImage(
                    imageUrl: posterUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                )
              else
                Center(
                  child: Icon(
                    item.mediaType == MediaType.series
                        ? Icons.tv
                        : Icons.movie,
                    size: 40,
                    color: AppColors.textSecondary,
                  ),
                ),

              // Glass overlay for rating
              if (item.rating != null && item.rating! > 0 && !useGlassLabel)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GlassPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: AppColors.secondary, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          item.rating!.toStringAsFixed(1),
                          style: AppTypography.getCaption(
                            color: AppColors.textPrimary,
                            scale: 0.9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Glass panel label for landscape mode
              if (useGlassLabel)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: GlassPanel(
                    borderRadius: BorderRadius.zero,
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          style: AppTypography.getLabel(
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle!,
                            style: AppTypography.getCaption(
                              color: AppColors.textSecondary,
                              scale: 0.9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (progress != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            height: 4,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: LayoutBuilder(
                              builder: (context, barConstraints) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: barConstraints.maxWidth * progress!,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.8),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget cardBody;
    if (useGlassLabel) {
      cardBody = imageWidget;
    } else {
      final subtitleText = isChannel ? null : item.subtitle;
      cardBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          imageWidget,
          Flexible(
            fit: FlexFit.loose,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isChannel
                        ? TitleFormatter.formatChannelTitle(item.title)
                        : item.title,
                    style: AppTypography.getCaption(
                      color: AppColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitleText != null && subtitleText.isNotEmpty) ...[
                    AppSpacing.heightXXS,
                    Text(
                      subtitleText,
                      style: AppTypography.getCaption(
                        color: AppColors.textSecondary,
                        scale: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (width != null) {
      cardBody = SizedBox(
        width: width,
        child: cardBody,
      );
    }

    return TvFocusable(
      onTap: onTap,
      scale: 1.06,
      onFocusChange: onFocusChange,
      borderRadius: AppRadius.medium,
      child: cardBody,
    );
  }

  Widget _buildChannelPlaceholder(ColorScheme colorScheme) {
    return const ChannelPlaceholder();
  }
}
