import 'package:flutter/material.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/tv_focusable.dart';

class EpisodeCard extends StatelessWidget {
  final MediaItem episode;
  final VoidCallback? onTap;
  final String? episodeNumber;

  const EpisodeCard({
    super.key,
    required this.episode,
    this.onTap,
    this.episodeNumber,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final thumbnail = episode.thumbnail ?? episode.poster;

    return TvFocusable(
      onTap: onTap,
      borderRadius: AppRadius.medium,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: AppRadius.medium,
        ),
        child: Row(
          children: [
            if (thumbnail != null && thumbnail.isNotEmpty)
              ClipRRect(
                borderRadius: AppRadius.medium,
                child: Image.network(
                  thumbnail,
                  width: 140,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildThumbnailPlaceholder(colorScheme),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: 140,
                      height: 80,
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
                ),
              )
            else
              _buildThumbnailPlaceholder(colorScheme),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (episodeNumber != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: AppRadius.small,
                            ),
                            child: Text(
                              episodeNumber!,
                              style: AppTypography.getCaption(
                                color: colorScheme.primary,
                                scale: 0.9,
                              ),
                            ),
                          ),
                          AppSpacing.widthXS,
                        ],
                        Expanded(
                          child: Text(
                            episode.title,
                            style: AppTypography.getLabel(color: colorScheme.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (episode.subtitle != null) ...[
                      AppSpacing.heightXXS,
                      Text(
                        episode.subtitle!,
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (episode.description != null &&
                        episode.description!.isNotEmpty) ...[
                      AppSpacing.heightXXS,
                      Text(
                        episode.description!,
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurfaceVariant,
                          scale: 0.85,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Icon(
                AppIcons.play,
                size: 20.0,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailPlaceholder(ColorScheme colorScheme) {
    return Container(
      width: 140,
      height: 80,
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          AppIcons.play,
          size: 24.0,
          color: colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
