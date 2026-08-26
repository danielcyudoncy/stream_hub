import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/tv_focusable.dart';

class ContinueWatchingSeriesCard extends StatelessWidget {
  final MediaItem series;
  final MediaItem? episode;
  final Duration position;
  final Duration duration;
  final VoidCallback onResume;
  final VoidCallback? onDetails;
  final double width;

  const ContinueWatchingSeriesCard({
    super.key,
    required this.series,
    this.episode,
    required this.position,
    required this.duration,
    required this.onResume,
    this.onDetails,
    this.width = 240,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final image = _resolveImage();
    final episodeCode = _resolveEpisodeCode();
    final remainingTime = _resolveRemainingTime();
    final progress = duration > Duration.zero
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return SizedBox(
      width: width,
      child: TvFocusable(
        onTap: onResume,
        borderRadius: AppRadius.medium,
        scale: 1.1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Backdrop with play overlay and progress bar
            ClipRRect(
              borderRadius: AppRadius.medium,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: image != null && image.isNotEmpty
                          ? Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildPlaceholder(colorScheme),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: SizedBox(
                                    width: 20.0,
                                    height: 20.0,
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
                          : _buildPlaceholder(colorScheme),
                    ),

                    // Gradient overlay
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black54,
                          ],
                        ),
                      ),
                    ),

                    // Play button overlay in center
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          AppIcons.play,
                          size: 24.0,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    // Episode badge (top left)
                    if (episodeCode != null)
                      Positioned(
                        top: AppSpacing.xs,
                        left: AppSpacing.xs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: AppRadius.small,
                          ),
                          child: Text(
                            episodeCode,
                            style: AppTypography.getCaption(
                              color: colorScheme.onPrimary,
                              scale: 0.8,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                    // Remaining time badge (bottom right)
                    if (remainingTime != null)
                      Positioned(
                        bottom: AppSpacing.sm,
                        right: AppSpacing.xs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: AppRadius.small,
                          ),
                          child: Text(
                            remainingTime,
                            style: AppTypography.getCaption(
                              color: Colors.white70,
                              scale: 0.75,
                            ),
                          ),
                        ),
                      ),

                    // Progress bar at bottom
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 4.0,
                        color: Colors.black54,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary,
                                  AppColors.darkPrimary,
                                ],
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

            AppSpacing.heightXS,

            // Series Title
            Text(
              series.title,
              style: AppTypography.getLabel(
                color: colorScheme.onSurface,
              ).copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Episode Title / subtitle
            if (episode != null || series.subtitle != null) ...[
              AppSpacing.heightXXS,
              Text(
                episode?.title ?? series.subtitle ?? '',
                style: AppTypography.getCaption(
                  color: colorScheme.onSurfaceVariant,
                  scale: 0.9,
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

  String? _resolveImage() {
    final epImage = episode != null
        ? (episode!.thumbnail ?? episode!.poster ?? episode!.backdrop)
        : null;
    final raw = epImage ?? series.backdrop ?? series.poster ?? series.thumbnail;
    return ImageUrlFormatter.format(raw, item: episode ?? series);
  }

  String? _resolveEpisodeCode() {
    final ep = episode;
    if (ep != null) {
      final sNum = ep.metadata['seasonNumber'] ?? ep.metadata['seasonId'];
      final eNum = ep.metadata['episodeNumber'] ?? ep.metadata['streamId'];
      if (sNum != null && eNum != null) {
        final sStr = sNum.toString().padLeft(2, '0');
        final eStr = eNum.toString().padLeft(2, '0');
        return 'S${sStr}E$eStr';
      }
      if (ep.subtitle != null && ep.subtitle!.startsWith('S')) {
        return ep.subtitle;
      }
    }
    return null;
  }

  String? _resolveRemainingTime() {
    if (duration <= Duration.zero) return null;
    final remaining = duration - position;
    if (remaining <= Duration.zero) return null;
    final mins = remaining.inMinutes;
    if (mins > 60) {
      final hours = remaining.inHours;
      final m = mins % 60;
      return '$hours h $m m left';
    }
    return '$mins min left';
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
