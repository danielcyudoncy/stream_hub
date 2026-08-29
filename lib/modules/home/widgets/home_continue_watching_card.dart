import 'package:flutter/material.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/cached_home_image.dart';
import '../../../shared/widgets/tv_focusable.dart';

class HomeContinueWatchingCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFocusChange;

  const HomeContinueWatchingCard({
    super.key,
    required this.item,
    this.onTap,
    this.onFocusChange,
  });

  double _getProgress() {
    final rawProgress = item.metadata['watchProgress'] ??
        item.metadata['progress'] ??
        item.metadata['position'];
    if (rawProgress is num) {
      if (rawProgress <= 1.0 && rawProgress > 0) {
        return rawProgress.toDouble();
      } else if (rawProgress > 1.0) {
        final duration = item.metadata['duration'];
        if (duration is num && duration > 0) {
          return (rawProgress / duration).clamp(0.0, 1.0);
        }
      }
    }
    // Default pleasant progress indicator for items in history if not specified
    return 0.45;
  }

  String? _getRemainingOrSubtitle() {
    if (item.subtitle != null && item.subtitle!.isNotEmpty) {
      return item.subtitle;
    }
    final season = item.metadata['season']?.toString();
    final episode = item.metadata['episode']?.toString();
    if (season != null && episode != null) {
      return 'S$season E$episode';
    }
    final remaining = item.metadata['remaining']?.toString();
    if (remaining != null && remaining.isNotEmpty) {
      return remaining;
    }
    if (item.mediaType == MediaType.movie) {
      return 'Movie';
    } else if (item.mediaType == MediaType.series) {
      return 'Series';
    } else if (item.mediaType == MediaType.channel) {
      return 'Live Channel';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final formattedPoster = ImageUrlFormatter.extractFromMediaItem(item);
    final rawPoster = (item.poster != null && item.poster!.trim().isNotEmpty)
        ? item.poster!.trim()
        : ((item.thumbnail != null && item.thumbnail!.trim().isNotEmpty)
            ? item.thumbnail!.trim()
            : item.backdrop?.trim());
    final poster = (formattedPoster != null && formattedPoster.isNotEmpty)
        ? formattedPoster
        : rawPoster;
    final progress = _getProgress();
    final subtitleText = _getRemainingOrSubtitle();

    return TvFocusable(
      onTap: onTap,
      onFocusChange: onFocusChange,
      borderRadius: AppRadius.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.medium,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Artwork
                    if (poster != null && poster.isNotEmpty)
                      CachedHomeImage(
                        imageUrl: poster,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        errorBuilder: (context, url) =>
                            _buildPlaceholder(colorScheme),
                      )
                    else
                      _buildPlaceholder(colorScheme),

                    // Gradient overlay for contrast
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Play icon overlay in center
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          AppIcons.play,
                          color: Colors.white,
                          size: 20.0,
                        ),
                      ),
                    ),

                    // Progress Bar at bottom edge
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 4.0,
                        color: Colors.black.withValues(alpha: 0.5),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress.clamp(0.05, 1.0),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppColors.primaryGradient,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AppSpacing.heightXS,
          Text(
            item.title,
            style: AppTypography.getCaption(
              color: colorScheme.onSurface,
            ).copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitleText != null) ...[
            AppSpacing.heightXXS,
            Text(
              subtitleText,
              style: AppTypography.getCaption(
                color: colorScheme.onSurfaceVariant,
                scale: 0.85,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        item.mediaType == MediaType.movie
            ? AppIcons.movies
            : item.mediaType == MediaType.series
                ? AppIcons.series
                : AppIcons.liveTv,
        size: 32.0,
        color: colorScheme.primary.withValues(alpha: 0.35),
      ),
    );
  }
}
