import 'package:flutter/material.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/media_item.dart';
import 'movie_card.dart';

class MovieGrid extends StatelessWidget {
  final List<MediaItem> movies;
  final void Function(MediaItem movie) onMovieTap;
  final Map<String, double>? progressMap;
  final Set<String>? completedIds;
  final void Function(MediaItem movie)? onToggleFavorite;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry padding;

  const MovieGrid({
    super.key,
    required this.movies,
    required this.onMovieTap,
    this.progressMap,
    this.completedIds,
    this.onToggleFavorite,
    this.physics,
    this.shrinkWrap = false,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    final isTv = PlatformHelper.isTV;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 2;
        if (width >= 1400) {
          crossAxisCount = 8;
        } else if (width >= 1100) {
          crossAxisCount = 6;
        } else if (width >= 800) {
          crossAxisCount = 4;
        } else if (width >= 600) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 2;
        }

        if (isTv && crossAxisCount > 5) {
          crossAxisCount = 5;
        }

        return GridView.builder(
          padding: padding,
          physics: physics,
          shrinkWrap: shrinkWrap,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: isTv ? AppSpacing.lg : AppSpacing.md,
            mainAxisSpacing: isTv ? AppSpacing.lg : AppSpacing.md,
            childAspectRatio: 0.65,
          ),
          itemCount: movies.length,
          itemBuilder: (context, index) {
            final movie = movies[index];
            final progress = progressMap?[movie.id];
            final isDone = completedIds?.contains(movie.id) ?? false;

            return MovieCard(
              item: movie,
              progressPercentage: progress,
              isCompleted: isDone,
              onTap: () => onMovieTap(movie),
              onToggleFavorite: onToggleFavorite != null
                  ? () => onToggleFavorite!(movie)
                  : null,
            );
          },
        );
      },
    );
  }
}
