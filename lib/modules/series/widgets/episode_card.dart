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
  final String? episodeNumber;
  final double? progressPercentage;
  final bool isCompleted;
  final bool isCurrentlyPlaying;
  final bool isNextUp;

  const EpisodeCard({
    super.key,
    required this.episode,
    this.onTap,
    this.episodeNumber,
    this.progressPercentage,
    this.isCompleted = false,
    this.isCurrentlyPlaying = false,
    this.isNextUp = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rawThumbnail = episode.thumbnail ?? episode.poster ?? episode.backdrop;
    final thumbnail = ImageUrlFormatter.format(rawThumbnail, item: episode);

    final duration = _resolveDuration();
    final effectiveProgress = progressPercentage?.clamp(0.0, 1.0);


    return TvFocusable(
      onTap: onTap,
      borderRadius: AppRadius.medium,
      scale: 1.02,
      child: Container(
        decoration: BoxDecoration(
          color: isCurrentlyPlaying
              ? colorScheme.primary.withValues(alpha: 0.12)
              : colorScheme.surfaceContainerLow,
          borderRadius: AppRadius.medium,
          border: isCurrentlyPlaying
              ? Border.all(color: colorScheme.primary, width: 1.5)
              : (isNextUp
                  ? Border.all(color: colorScheme.primary.withValues(alpha: 0.5), width: 1.0)
                  : null),
        ),
        child: Row(
          children: [
            // Thumbnail with overlay badges
            ClipRRect(
              borderRadius: AppRadius.medium,
              child: SizedBox(
                width: 140,
                height: 84,
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
                                child: CircularProgressIndicator(strokeWidth: 2.0),
                              ),
                            ),
                          );
                        },
                      )
                    else
                      _buildThumbnailPlaceholder(colorScheme),

                    // Progress bar overlay at bottom of thumbnail
                    if (effectiveProgress != null && effectiveProgress > 0 && !isCompleted)
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
                            child: Container(
                              color: colorScheme.primary,
                            ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
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
                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: AppColors.darkPrimary,
                            borderRadius: AppRadius.small,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow, size: 10, color: Colors.white),
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

            // Episode Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (episodeNumber != null && episodeNumber!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: isCurrentlyPlaying
                                  ? colorScheme.primary
                                  : colorScheme.primary.withValues(alpha: 0.14),
                              borderRadius: AppRadius.small,
                            ),
                            child: Text(
                              episodeNumber!,
                              style: AppTypography.getCaption(
                                color: isCurrentlyPlaying
                                    ? colorScheme.onPrimary
                                    : colorScheme.primary,
                                scale: 0.85,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          AppSpacing.widthXS,
                        ],
                        Expanded(
                          child: Text(
                            episode.title,
                            style: AppTypography.getLabel(
                              color: isCurrentlyPlaying
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                            ).copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (duration != null || episode.subtitle != null) ...[
                      AppSpacing.heightXXS,
                      Row(
                        children: [
                          if (duration != null) ...[
                            Icon(
                              Icons.access_time,
                              size: 12.0,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              duration,
                              style: AppTypography.getCaption(
                                color: colorScheme.onSurfaceVariant,
                                scale: 0.85,
                              ),
                            ),
                            if (episode.subtitle != null) const SizedBox(width: 8.0),
                          ],
                          if (episode.subtitle != null)
                            Expanded(
                              child: Text(
                                episode.subtitle!,
                                style: AppTypography.getCaption(
                                  color: colorScheme.onSurfaceVariant,
                                  scale: 0.85,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (episode.description != null && episode.description!.isNotEmpty) ...[
                      AppSpacing.heightXXS,
                      Text(
                        episode.description!,
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                          scale: 0.8,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Play Icon action
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
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
                  color: isCurrentlyPlaying ? colorScheme.onPrimary : colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _resolveDuration() {
    final direct = episode.metadata['duration'] ??
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
      width: 140,
      height: 84,
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          AppIcons.series,
          size: 28.0,
          color: colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
