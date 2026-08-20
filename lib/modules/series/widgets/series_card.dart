import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/series.dart';
import '../../../shared/widgets/tv_focusable.dart';

class SeriesCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  final double? progressPercentage;
  final bool isCompleted;
  final VoidCallback? onToggleFavorite;

  const SeriesCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width,
    this.height,
    this.progressPercentage,
    this.isCompleted = false,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final poster = _resolvePoster();
    final rating = item.formattedRating;
    final year = item is Series
        ? (item as Series).formattedYearRange
        : (item.releaseYear?.toString());
    final seasonsCount = _resolveSeasonsCount();

    return SizedBox(
      width: width,
      height: height,
      child: TvFocusable(
        onTap: onTap,
        borderRadius: AppRadius.medium,
        scale: 1.04,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: AppRadius.medium,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (poster != null && poster.isNotEmpty)
                      Image.network(
                        poster,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholder(colorScheme),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: SizedBox(
                              width: 24.0,
                              height: 24.0,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                      )
                    else
                      _buildPlaceholder(colorScheme),

                    if (rating != null)
                      Positioned(
                        top: AppSpacing.xs,
                        left: AppSpacing.xs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: AppRadius.small,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                size: 12.0,
                                color: AppColors.darkWarning,
                              ),
                              const SizedBox(width: 2.0),
                              Text(
                                rating,
                                style: AppTypography.getCaption(
                                  color: Colors.white,
                                  scale: 0.85,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (seasonsCount != null && !isCompleted)
                      Positioned(
                        top: AppSpacing.xs,
                        right: onToggleFavorite != null ? AppSpacing.xxl : AppSpacing.xs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.9),
                            borderRadius: AppRadius.small,
                          ),
                          child: Text(
                            seasonsCount,
                            style: AppTypography.getCaption(
                              color: colorScheme.onPrimary,
                              scale: 0.8,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                    if (onToggleFavorite != null)
                      Positioned(
                        top: AppSpacing.xxs,
                        right: AppSpacing.xxs,
                        child: GestureDetector(
                          onTap: onToggleFavorite,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.all(4.0),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              item.favorite ? Icons.favorite : Icons.favorite_border,
                              size: 16.0,
                              color: item.favorite ? AppColors.darkError : Colors.white,
                            ),
                          ),
                        ),
                      ),

                    if (progressPercentage != null && progressPercentage! > 0 && !isCompleted)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12.0),
                          ),
                          child: Container(
                            height: 4.0,
                            color: Colors.black54,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progressPercentage!.clamp(0.0, 1.0),
                              child: Container(
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (isCompleted)
                      Positioned(
                        top: AppSpacing.xs,
                        right: onToggleFavorite != null ? AppSpacing.xl : AppSpacing.xs,
                        child: Container(
                          padding: const EdgeInsets.all(3.0),
                          decoration: const BoxDecoration(
                            color: AppColors.darkSuccess,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 12.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            AppSpacing.heightXS,

            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.getLabel(
                color: colorScheme.onSurface,
              ).copyWith(fontWeight: FontWeight.w600),
            ),

            if (year != null || item.genres.isNotEmpty) ...[
              AppSpacing.heightXXS,
              Row(
                children: [
                  if (year != null)
                    Text(
                      year,
                      style: AppTypography.getCaption(
                        color: colorScheme.onSurfaceVariant,
                        scale: 0.9,
                      ),
                    ),

                  if (year != null && item.genres.isNotEmpty) ...[
                    const SizedBox(width: 4.0),
                    Text(
                      '•',
                      style: AppTypography.getCaption(
                        color: colorScheme.onSurfaceVariant,
                        scale: 0.9,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                  ],
                  if (item.genres.isNotEmpty)
                    Expanded(
                      child: Text(
                        item.genres.first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurfaceVariant,
                          scale: 0.9,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _resolvePoster() {
    final raw = (item.poster != null && item.poster!.trim().isNotEmpty)
        ? item.poster!.trim()
        : ((item.thumbnail != null && item.thumbnail!.trim().isNotEmpty)
            ? item.thumbnail!.trim()
            : item.backdrop?.trim());
    final formatted = ImageUrlFormatter.format(raw, item: item);
    if (formatted != null && formatted.isNotEmpty) {
      return formatted;
    }
    return ImageUrlFormatter.extractFromMediaItem(item);
  }

  String? _resolveSeasonsCount() {
    final count = item.metadata['seasonsCount'] ??
        item.metadata['seasons_count'] ??
        item.metadata['num_seasons'] ??
        item.metadata['seasons'];
    if (count != null) {
      final parsed = int.tryParse(count.toString());
      if (parsed != null && parsed > 0) {
        return '$parsed ${parsed == 1 ? 'Season' : 'Seasons'}';
      }
    }
    return null;
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          AppIcons.series,
          size: 32.0,
          color: colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
