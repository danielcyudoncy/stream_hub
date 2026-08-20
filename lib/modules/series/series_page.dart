import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';

import '../../../shared/widgets/empty_library.dart';
import '../../../shared/widgets/provider_selector_button.dart';
import '../../../shared/widgets/tv_focusable.dart';
import 'series_controller.dart';
import 'widgets/continue_watching_series_card.dart';
import 'widgets/series_card.dart';
import 'widgets/series_carousel.dart';
import 'widgets/series_hero_carousel.dart';

class SeriesPage extends GetView<SeriesController> {
  const SeriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Series',
      actions: [
        Obx(
          () => ProviderSelectorButton(
            selectedProviderId: controller.selectedProvider.value,
            onSelectProvider: (providerId) => controller.setProvider(providerId),
            sheetTitle: 'Series Provider',
          ),
        ),
        IconButton(
          icon: const Icon(AppIcons.search),
          onPressed: () => Get.toNamed(AppRoutes.search),
          tooltip: 'Search',
        ),
      ],
      body: Obx(() {
        if (controller.isLoading.value) {
          return _buildSkeleton(context);
        }

        if (controller.series.isEmpty) {
          return EmptyLibrary(
            icon: AppIcons.series,
            title: 'No Series Found',
            description:
                'Add a provider with series content to start watching.',
            actionLabel: 'Add Media Source',
            onAction: () => Get.toNamed(AppRoutes.providerManager),
          );
        }

        return _buildContent(context);
      }),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSpacing.heightMD,
              Container(
                height: 280,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadius.large,
                ),
              ),
              AppSpacing.heightLG,
              ...List.generate(3, (_) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 20,
                      width: 160,
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: AppRadius.small,
                      ),
                    ),
                    AppSpacing.heightSM,
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        itemCount: 5,
                        itemBuilder: (context, index) => Container(
                          width: 130,
                          margin: const EdgeInsets.only(right: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: AppRadius.medium,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
              AppSpacing.heightXXL,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final isTv = PlatformHelper.isTV;
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Featured Hero Carousel
        if (controller.featuredSeries.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: SeriesHeroCarousel(
                series: controller.featuredSeries,
                onWatch: controller.openSeries,
                onDetails: controller.openSeries,
                onToggleFavorite: controller.toggleFavorite,
              ),
            ),
          ),

        // Genre Filter Chips Bar
        if (controller.availableGenres.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: controller.availableGenres.length,
                separatorBuilder: (context, index) => AppSpacing.widthXS,
                itemBuilder: (context, index) {
                  final genre = controller.availableGenres[index];
                  return TvFocusable(
                    onTap: () => controller.openGenre(genre),
                    borderRadius: AppRadius.pill,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: AppRadius.pill,
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          genre,
                          style: AppTypography.getLabel(
                            color: colorScheme.onSurface,
                          ).copyWith(fontSize: 12),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        if (controller.availableGenres.isNotEmpty)
          const SliverToBoxAdapter(child: AppSpacing.heightMD),

        // Continue Watching Series Row
        if (controller.continueWatching.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Text(
                      'Continue Watching',
                      style: AppTypography.getTitle(
                        color: colorScheme.onSurface,
                        scale: isTv ? 1.1 : 1.0,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  AppSpacing.heightSM,
                  SizedBox(
                    height: isTv ? 210 : 180,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      itemCount: controller.continueWatching.length,
                      separatorBuilder: (context, index) => AppSpacing.widthMD,
                      itemBuilder: (context, index) {
                        final item = controller.continueWatching[index];
                        return ContinueWatchingSeriesCard(
                          key: ValueKey('cw-${item.series.id}'),
                          series: item.series,
                          episode: item.episode,
                          position: item.position,
                          duration: item.duration,
                          onResume: () => controller.openSeries(item.series),
                          onDetails: () => controller.openSeries(item.series),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Trending Series Carousel
        if (controller.trendingSeries.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: SeriesCarousel(
                title: 'Trending Series',
                subtitle: 'Popular and recently updated series',
                series: controller.trendingSeries,
                progressMap: controller.progressMap,
                completedIds: controller.completedSeriesIds,
                onSeriesTap: controller.openSeries,
                onViewAll: () => controller.openGenre('Trending'),
              ),
            ),
          ),

        // Top Rated Series Carousel
        if (controller.topRatedSeries.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: SeriesCarousel(
                title: 'Top Rated',
                subtitle: 'Critically acclaimed series',
                series: controller.topRatedSeries,
                progressMap: controller.progressMap,
                completedIds: controller.completedSeriesIds,
                onSeriesTap: controller.openSeries,
                onViewAll: () => controller.openGenre('Top Rated'),
              ),
            ),
          ),

        // Recently Added Series
        if (controller.recentlyAddedSeries.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: SeriesCarousel(
                title: 'Recently Added',
                subtitle: 'Newest additions to the library',
                series: controller.recentlyAddedSeries,
                progressMap: controller.progressMap,
                completedIds: controller.completedSeriesIds,
                onSeriesTap: controller.openSeries,
                onViewAll: () => controller.openGenre('Recently Added'),
              ),
            ),
          ),

        // Drama Carousel
        if (controller.dramaSeries.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: SeriesCarousel(
                title: 'Drama',
                series: controller.dramaSeries,
                progressMap: controller.progressMap,
                completedIds: controller.completedSeriesIds,
                onSeriesTap: controller.openSeries,
                onViewAll: () => controller.openGenre('Drama'),
              ),
            ),
          ),

        // Comedy Carousel
        if (controller.comedySeries.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: SeriesCarousel(
                title: 'Comedy',
                series: controller.comedySeries,
                progressMap: controller.progressMap,
                completedIds: controller.completedSeriesIds,
                onSeriesTap: controller.openSeries,
                onViewAll: () => controller.openGenre('Comedy'),
              ),
            ),
          ),

        // Action & Adventure Carousel
        if (controller.actionAdventureSeries.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: SeriesCarousel(
                title: 'Action & Adventure',
                series: controller.actionAdventureSeries,
                progressMap: controller.progressMap,
                completedIds: controller.completedSeriesIds,
                onSeriesTap: controller.openSeries,
                onViewAll: () => controller.openGenre('Action'),
              ),
            ),
          ),

        // Sci-Fi & Fantasy Carousel
        if (controller.sciFiFantasySeries.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: SeriesCarousel(
                title: 'Sci-Fi & Fantasy',
                series: controller.sciFiFantasySeries,
                progressMap: controller.progressMap,
                completedIds: controller.completedSeriesIds,
                onSeriesTap: controller.openSeries,
                onViewAll: () => controller.openGenre('Sci-Fi'),
              ),
            ),
          ),

        // Animation Carousel
        if (controller.animationSeries.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: SeriesCarousel(
                title: 'Animation',
                series: controller.animationSeries,
                progressMap: controller.progressMap,
                completedIds: controller.completedSeriesIds,
                onSeriesTap: controller.openSeries,
                onViewAll: () => controller.openGenre('Animation'),
              ),
            ),
          ),

        // Documentary Carousel
        if (controller.documentarySeries.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: SeriesCarousel(
                title: 'Documentary',
                series: controller.documentarySeries,
                progressMap: controller.progressMap,
                completedIds: controller.completedSeriesIds,
                onSeriesTap: controller.openSeries,
                onViewAll: () => controller.openGenre('Documentary'),
              ),
            ),
          ),

        // All Series Grid Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'All Series (${controller.series.length})',
              style: AppTypography.getTitle(
                color: colorScheme.onSurface,
                scale: isTv ? 1.1 : 1.0,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),

        // All Series Grid
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: isTv ? 180.0 : 140.0,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.62,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = controller.series[index];
                final progress = controller.progressMap[item.id];
                final isCompleted = controller.completedSeriesIds.contains(item.id);

                return SeriesCard(
                  key: ValueKey('all-series-${item.id}'),
                  item: item,
                  progressPercentage: progress,
                  isCompleted: isCompleted,
                  onTap: () => controller.openSeries(item),
                  onToggleFavorite: () => controller.toggleFavorite(item),
                );
              },
              childCount: controller.series.length,
            ),
          ),
        ),
      ],
    );
  }
}
