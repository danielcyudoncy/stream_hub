import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_library.dart';
import '../../../shared/widgets/provider_selector_button.dart';
import './widgets/series_content_rail.dart';
import './widgets/series_hero_section.dart';
import 'series_controller.dart';

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
            title: 'No Series Yet',
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
                          margin: EdgeInsets.only(right: AppSpacing.md),
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

    return CustomScrollView(
      slivers: [
        if (controller.featuredSeries.isNotEmpty)
          SliverToBoxAdapter(
            child: SeriesHeroSection(
              series: controller.featuredSeries.first,
              onWatch: () => _playSeries(controller.featuredSeries.first),
              onFavorite: () => _toggleFavorite(context, controller.featuredSeries.first),
              isFavorite: controller.featuredSeries.first.favorite,
            ),
          ),
        if (controller.continueWatching.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SeriesContentRail(
              title: 'Continue Watching',
              items: controller.continueWatching,
              onSeeAll: () => _openCategory('Continue Watching', controller.continueWatching),
              itemBuilder: (context, item) {
                final progress = (item.metadata['watchProgress'] as double?) ?? 0.0;
                return ContinueWatchingCard(
                  item: item,
                  onTap: () => _playSeries(item),
                  progress: progress,
                );
              },
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: SeriesContentRail(
            title: 'Trending Series',
            items: controller.trendingSeries,
            onSeeAll: () => _openCategory('Trending Series', controller.trendingSeries),
            itemBuilder: (context, item) => SeriesPosterCard(
              item: item,
              onTap: () => _openItem(item),
            ),
          ),
        ),
        if (controller.topRatedSeries.isNotEmpty)
          SliverToBoxAdapter(
            child: SeriesContentRail(
              title: 'Top Rated',
              items: controller.topRatedSeries,
              onSeeAll: () => _openCategory('Top Rated', controller.topRatedSeries),
              itemBuilder: (context, item) => SeriesPosterCard(
                item: item,
                onTap: () => _openItem(item),
              ),
            ),
          ),
        if (controller.recentlyAddedSeries.isNotEmpty)
          SliverToBoxAdapter(
            child: SeriesContentRail(
              title: 'Recently Added',
              items: controller.recentlyAddedSeries,
              onSeeAll: () => _openCategory('Recently Added', controller.recentlyAddedSeries),
              itemBuilder: (context, item) => SeriesPosterCard(
                item: item,
                onTap: () => _openItem(item),
              ),
            ),
          ),
        if (controller.dramaSeries.isNotEmpty)
          SliverToBoxAdapter(
            child: SeriesContentRail(
              title: 'Drama',
              items: controller.dramaSeries,
              onSeeAll: () => _openCategory('Drama', controller.dramaSeries),
              itemBuilder: (context, item) => SeriesPosterCard(
                item: item,
                onTap: () => _openItem(item),
              ),
            ),
          ),
        if (controller.comedySeries.isNotEmpty)
          SliverToBoxAdapter(
            child: SeriesContentRail(
              title: 'Comedy',
              items: controller.comedySeries,
              onSeeAll: () => _openCategory('Comedy', controller.comedySeries),
              itemBuilder: (context, item) => SeriesPosterCard(
                item: item,
                onTap: () => _openItem(item),
              ),
            ),
          ),
        if (controller.actionAdventureSeries.isNotEmpty)
          SliverToBoxAdapter(
            child: SeriesContentRail(
              title: 'Action & Adventure',
              items: controller.actionAdventureSeries,
              onSeeAll: () => _openCategory('Action & Adventure', controller.actionAdventureSeries),
              itemBuilder: (context, item) => SeriesPosterCard(
                item: item,
                onTap: () => _openItem(item),
              ),
            ),
          ),
        if (controller.sciFiFantasySeries.isNotEmpty)
          SliverToBoxAdapter(
            child: SeriesContentRail(
              title: 'Sci-Fi & Fantasy',
              items: controller.sciFiFantasySeries,
              onSeeAll: () => _openCategory('Sci-Fi & Fantasy', controller.sciFiFantasySeries),
              itemBuilder: (context, item) => SeriesPosterCard(
                item: item,
                onTap: () => _openItem(item),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: isTv ? 200.0 : 170.0,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.7,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = controller.series[index];
                return SeriesPosterCard(
                  item: item,
                  onTap: () => _openItem(item),
                );
              },
              childCount: controller.series.length,
            ),
          ),
        ),
      ],
    );
  }

  void _openItem(MediaItem item) {
    Get.toNamed(
      AppRoutes.seriesDetails,
      arguments: {'item': item},
    );
  }

  void _openCategory(String title, List<MediaItem> items) {
    Get.toNamed(
      AppRoutes.seriesCategory,
      arguments: {'title': title, 'items': items},
    );
  }

  void _playSeries(MediaItem item) {
    if (item.mediaType == MediaType.episode) {
      Get.toNamed(
        AppRoutes.fullscreenPlayer,
        arguments: {
          'items': [item],
          'currentId': item.id,
        },
      );
    } else {
      Get.toNamed(
        AppRoutes.seriesDetails,
        arguments: {'item': item},
      );
    }
  }

  void _toggleFavorite(BuildContext context, MediaItem item) {
    Get.snackbar(
      item.favorite ? 'Removed from Favorites' : 'Added to Favorites',
      item.title,
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
