import 'package:flutter/material.dart';
import '../../core/media/enums/media_type.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/media_item.dart';
import 'app_card.dart';

class MediaPosterCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onTap;

  const MediaPosterCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final poster = item.poster ?? item.thumbnail;

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: EdgeInsets.zero,
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
                  child: poster != null && poster.isNotEmpty
                      ? Image.network(
                          poster,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholder(context, colorScheme),
                        )
                      : _buildPlaceholder(context, colorScheme),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.getCaption(
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.subtitle != null) ...[
                    AppSpacing.heightXXS,
                    Text(
                      item.subtitle!,
                      style: AppTypography.getCaption(
                        color: colorScheme.onSurfaceVariant,
                        scale: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Icon(
        item.mediaType == MediaType.movie
            ? AppIcons.movies
            : item.mediaType == MediaType.series
            ? AppIcons.series
            : AppIcons.liveTv,
        size: 32.0,
        color: colorScheme.primary.withValues(alpha: 0.3),
      ),
    );
  }
}
