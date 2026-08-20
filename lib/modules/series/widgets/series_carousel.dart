import 'package:flutter/material.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/tv_focusable.dart';
import 'series_card.dart';

class SeriesCarousel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<MediaItem> series;
  final void Function(MediaItem item) onSeriesTap;
  final VoidCallback? onViewAll;
  final Map<String, double>? progressMap;
  final Set<String>? completedIds;

  const SeriesCarousel({
    super.key,
    required this.title,
    this.subtitle,
    required this.series,
    required this.onSeriesTap,
    this.onViewAll,
    this.progressMap,
    this.completedIds,
  });

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final isTv = PlatformHelper.isTV;

    final cardWidth = isTv ? 160.0 : 130.0;
    final cardHeight = isTv ? 240.0 : 200.0;
    final carouselHeight = cardHeight + 48.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
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
                        scale: isTv ? 1.1 : 1.0,
                      ).copyWith(fontWeight: FontWeight.bold),
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
              if (onViewAll != null)
                TvFocusable(
                  onTap: onViewAll,
                  scale: 1.05,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See All',
                          style: AppTypography.getLabel(
                            color: colorScheme.primary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4.0),
                        Icon(
                          AppIcons.forward,
                          size: 14.0,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        AppSpacing.heightSM,
        SizedBox(
          height: carouselHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: series.length,
            separatorBuilder: (context, index) => AppSpacing.widthMD,
            itemBuilder: (context, index) {
              final item = series[index];
              final progress = progressMap?[item.id];
              final isCompleted = completedIds?.contains(item.id) ?? false;

              return SeriesCard(
                key: ValueKey('series-card-${item.id}'),
                item: item,
                width: cardWidth,
                height: cardHeight,
                progressPercentage: progress,
                isCompleted: isCompleted,
                onTap: () => onSeriesTap(item),
              );
            },
          ),
        ),
      ],
    );
  }
}
