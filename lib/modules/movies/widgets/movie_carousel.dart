import 'package:flutter/material.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/tv_focusable.dart';
import 'movie_card.dart';

class MovieCarousel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<MediaItem> movies;
  final void Function(MediaItem movie) onMovieTap;
  final VoidCallback? onSeeAll;
  final Map<String, double>? progressMap;
  final Set<String>? completedIds;
  final void Function(MediaItem movie)? onToggleFavorite;

  const MovieCarousel({
    super.key,
    required this.title,
    this.subtitle,
    required this.movies,
    required this.onMovieTap,
    this.onSeeAll,
    this.progressMap,
    this.completedIds,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final isTv = PlatformHelper.isTV;
    final cardWidth = isTv ? 160.0 : 130.0;
    final cardHeight = isTv ? 270.0 : 230.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTypography.getTitle(
                        color: colorScheme.onSurface,
                        scale: isTv ? 1.05 : 0.95,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurfaceVariant,
                          scale: 0.85,
                        ),
                      ),
                  ],
                ),
              ),
              if (onSeeAll != null)
                TvFocusable(
                  onTap: onSeeAll,
                  borderRadius: AppRadius.pill,
                  scale: 1.05,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See All',
                          style: AppTypography.getLabel(
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18.0,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: cardHeight,
          child: FocusTraversalGroup(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              separatorBuilder: (context, index) => AppSpacing.widthSM,
              itemBuilder: (context, index) {
                final movie = movies[index];
                final progress = progressMap?[movie.id];
                final isDone = completedIds?.contains(movie.id) ?? false;

                return MovieCard(
                  item: movie,
                  width: cardWidth,
                  height: cardHeight,
                  progressPercentage: progress,
                  isCompleted: isDone,
                  onTap: () => onMovieTap(movie),
                  onToggleFavorite: onToggleFavorite != null
                      ? () => onToggleFavorite!(movie)
                      : null,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
