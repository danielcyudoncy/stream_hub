import 'package:flutter/material.dart';
import '../../core/media/enums/media_type.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_url_formatter.dart';
import '../../data/models/media_item.dart';
import 'tv_focusable.dart';

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
    final formattedPoster = ImageUrlFormatter.extractFromMediaItem(item);
    final rawPoster = (item.poster != null && item.poster!.trim().isNotEmpty)
        ? item.poster!.trim()
        : ((item.thumbnail != null && item.thumbnail!.trim().isNotEmpty)
            ? item.thumbnail!.trim()
            : item.backdrop?.trim());
    final poster = (formattedPoster != null && formattedPoster.isNotEmpty)
        ? formattedPoster
        : rawPoster;
    final isChannel = item.mediaType == MediaType.channel;

    return TvFocusable(
      onTap: onTap,
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
                child: poster != null && poster.isNotEmpty
                    ? (isChannel
                        ? Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Image.network(
                              poster,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildPlaceholder(context, colorScheme),
                            ),
                          )
                        : Image.network(
                            poster,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(context, colorScheme),
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
                          ))
                    : _buildPlaceholder(context, colorScheme),
              ),
            ),
          ),
          AppSpacing.heightXS,
          Text(
            item.title,
            style: AppTypography.getCaption(
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.rating != null && item.rating! > 0) ...[
            AppSpacing.heightXXS,
            Text(
              '⭐ ${item.rating!.toStringAsFixed(1)}',
              style: AppTypography.getCaption(
                color: colorScheme.onSurfaceVariant,
                scale: 0.8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ] else if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
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
