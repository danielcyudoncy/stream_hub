import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/tv_focusable.dart';

class EpisodeCard extends StatelessWidget {
  final MediaItem episode;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final String? episodeNumber;
  final double? progressPercentage;
  final bool isCompleted;
  final bool isCurrentlyPlaying;
  final bool isNextUp;
  final bool isDownloaded;
  final bool isDownloading;

  const EpisodeCard({
    super.key,
    required this.episode,
    this.onTap,
    this.onDownload,
    this.episodeNumber,
    this.progressPercentage,
    this.isCompleted = false,
    this.isCurrentlyPlaying = false,
    this.isNextUp = false,
    this.isDownloaded = false,
    this.isDownloading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rawThumbnail =
        episode.thumbnail ?? episode.poster ?? episode.backdrop;
    final thumbnail = ImageUrlFormatter.format(rawThumbnail, item: episode);

    final duration = _resolveDuration();
    final effectiveProgress = progressPercentage?.clamp(0.0, 1.0);

    return TvFocusable(
      onTap: onTap,
      borderRadius: AppRadius.medium,
      scale: 1.02,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: isCurrentlyPlaying
              ? colorScheme.primary.withValues(alpha: 0.12)
              : colorScheme.surfaceContainerLow,
          borderRadius: AppRadius.medium,
          border: isCurrentlyPlaying
              ? Border.all(color: colorScheme.primary, width: 1.5)
              : (isNextUp
                  ? Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.0,
                    )
                  : null),
        ),
        child: Row(
          children: [
            // 1. Thumbnail with overlay badges (Fixed 16:9, non-flex so info column gets all remaining space)
            ClipRRect(
              borderRadius: AppRadius.small,
              child: SizedBox(
                width: 120,
                height: 68,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbnail != null && thumbnail.isNotEmpty)
                      Image.network(
                        thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildThumbnailPlaceholder(colorScheme),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: SizedBox(
                                width: 20.0,
                                height: 20.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    else
                      _buildThumbnailPlaceholder(colorScheme),

                    // Progress bar overlay at bottom of thumbnail
                    if (effectiveProgress != null &&
                        effectiveProgress > 0 &&
                        !isCompleted)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 4.0,
                          color: Colors.black54,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: effectiveProgress,
                            child: Container(color: colorScheme.primary),
                          ),
                        ),
                      ),

                    // Completed Checkmark Badge
                    if (isCompleted)
                      Positioned(
                        top: AppSpacing.xxs,
                        left: AppSpacing.xxs,
                        child: Container(
                          padding: const EdgeInsets.all(2.0),
                          decoration: const BoxDecoration(
                            color: AppColors.darkSuccess,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 14.0,
                            color: Colors.white,
                          ),
                        ),
                      ),

                    // Next Up Badge
                    if (isNextUp && !isCurrentlyPlaying)
                      Positioned(
                        top: AppSpacing.xxs,
                        right: AppSpacing.xxs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: AppRadius.small,
                          ),
                          child: Text(
                            'NEXT',
                            style: AppTypography.getCaption(
                              color: colorScheme.onPrimary,
                              scale: 0.75,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                    // Currently Playing Indicator
                    if (isCurrentlyPlaying)
                      Positioned(
                        top: AppSpacing.xxs,
                        right: AppSpacing.xxs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.darkPrimary,
                            borderRadius: AppRadius.small,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_arrow,
                                size: 10,
                                color: Colors.white,
                              ),
                              Text(
                                'PLAYING',
                                style: AppTypography.getCaption(
                                  color: Colors.white,
                                  scale: 0.75,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 2. Episode Info: Takes all available width, prominent title
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Kicker: Episode badge + duration on their own line
                    if ((episodeNumber != null && episodeNumber!.isNotEmpty) ||
                        duration != null)
                      Row(
                        children: [
                          if (episodeNumber != null &&
                              episodeNumber!.isNotEmpty)
                            Flexible(
                              child: ClipRect(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6.0,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCurrentlyPlaying
                                        ? colorScheme.primary
                                        : colorScheme.primary.withValues(
                                            alpha: 0.14,
                                          ),
                                  borderRadius: AppRadius.small,
                                  ),
                                  child: Text(
                                    episodeNumber!,
                                    style: AppTypography.getCaption(
                                      color: isCurrentlyPlaying
                                          ? colorScheme.onPrimary
                                          : colorScheme.primary,
                                      scale: 0.75,
                                    ).copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          if (duration != null) ...[
                            if (episodeNumber != null &&
                                episodeNumber!.isNotEmpty)
                              const SizedBox(width: 6.0),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 11.0,
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: 3.0),
                                    Text(
                                      duration,
                                      style: AppTypography.getCaption(
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.8),
                                        scale: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                    const SizedBox(height: 3.0),

                    // Clear, prominent Episode Title (wraps to 2 lines without truncation)
                    Text(
                      episode.title,
                      style: AppTypography.getTitle(
                        color: isCurrentlyPlaying
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        scale: 0.72,
                      ).copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (episode.subtitle != null &&
                        episode.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2.0),
                      Text(
                        episode.subtitle!,
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurfaceVariant,
                          scale: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    if (episode.description != null &&
                        episode.description!.isNotEmpty) ...[
                      const SizedBox(height: 2.0),
                      Text(
                        episode.description!,
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                          scale: 0.75,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 3. Actions (Download + Play)
            Padding(
              padding: const EdgeInsets.only(
                right: AppSpacing.xs,
                left: AppSpacing.xxs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onDownload != null) ...[
                    TvFocusable(
                      onTap: onDownload,
                      borderRadius: AppRadius.pill,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xxs),
                        decoration: BoxDecoration(
                          color: isDownloaded
                              ? AppColors.darkSuccess.withValues(alpha: 0.2)
                              : (isDownloading
                                  ? colorScheme.primary.withValues(
                                      alpha: 0.15,
                                    )
                                  : colorScheme.surfaceContainerHighest),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDownloaded
                              ? Icons.download_done_rounded
                              : (isDownloading
                                  ? Icons.downloading_rounded
                                  : Icons.download_rounded),
                          size: 18.0,
                          color: isDownloaded
                              ? AppColors.darkSuccess
                              : (isDownloading
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                    AppSpacing.widthXS,
                  ],

                  // Play Icon
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xxs),
                    decoration: BoxDecoration(
                      color: isCurrentlyPlaying
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.replay
                          : (isCurrentlyPlaying ? Icons.pause : AppIcons.play),
                      size: 18.0,
                      color: isCurrentlyPlaying
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _resolveDuration() {
    final direct =
        episode.metadata['duration'] ??
        episode.metadata['durationSeconds'] ??
        episode.metadata['runtime'] ??
        episode.metadata['length'];
    if (direct != null) {
      final val = int.tryParse(direct.toString());
      if (val != null && val > 0) {
        if (val > 300) {
          // Duration in seconds
          final mins = (val / 60).round();
          return '$mins min';
        }
        return '$val min';
      }
    }
    return null;
  }

  Widget _buildThumbnailPlaceholder(ColorScheme colorScheme) {
    return Container(
      width: 120,
      height: 68,
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          AppIcons.series,
          size: 24.0,
          color: colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
