import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/tv_focusable.dart';

class SeriesContentRail extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<MediaItem> items;
  final VoidCallback? onSeeAll;
  final Widget Function(BuildContext context, MediaItem item) itemBuilder;

  const SeriesContentRail({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    this.onSeeAll,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final isTv = width >= 900;
    final cardWidth = isTv ? 170.0 : (width >= 600 ? 150.0 : 130.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.getTitle(color: colorScheme.onSurface),
                    ),
                    if (subtitle != null) ...[
                      AppSpacing.heightXXS,
                      Text(
                        subtitle!,
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: Text(
                    'See All →',
                    style: AppTypography.getLabel(color: colorScheme.primary),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: cardWidth * 0.72 + AppSpacing.md + AppSpacing.sm,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                width: cardWidth,
                margin: EdgeInsets.only(right: AppSpacing.md),
                child: itemBuilder(context, item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class SeriesPosterCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onTap;

  const SeriesPosterCard({
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
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                ),
                child: poster != null && poster.isNotEmpty
                    ? Image.network(
                        poster,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholder(colorScheme),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 24.0,
                              height: 24.0,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                              ),
                            ),
                          );
                        },
                      )
                    : _buildPlaceholder(colorScheme),
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
          if (item.rating != null) ...[
            AppSpacing.heightXXS,
            Text(
              '⭐ ${item.rating!.toStringAsFixed(1)}',
              style: AppTypography.getCaption(
                color: colorScheme.onSurfaceVariant,
                scale: 0.8,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        AppIcons.series,
        size: 32.0,
        color: colorScheme.primary.withValues(alpha: 0.3),
      ),
    );
  }
}

class ContinueWatchingCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final double progress;

  const ContinueWatchingCard({
    super.key,
    required this.item,
    this.onTap,
    required this.progress,
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
    final width = MediaQuery.of(context).size.width >= 900 ? 200.0 : (MediaQuery.of(context).size.width >= 600 ? 180.0 : 150.0);

    return SizedBox(
      width: width,
      child: TvFocusable(
        onTap: onTap,
        borderRadius: AppRadius.medium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: AppRadius.medium,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (poster != null && poster.isNotEmpty)
                        Image.network(
                          poster,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholder(colorScheme),
                        )
                      else
                        _buildPlaceholder(colorScheme),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 4.0,
                          color: colorScheme.surfaceContainerHighest,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: AppColors.primaryGradient),
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(2.0),
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
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        AppIcons.series,
        size: 32.0,
        color: colorScheme.primary.withValues(alpha: 0.3),
      ),
    );
  }
}
