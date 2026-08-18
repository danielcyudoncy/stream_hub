import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/media_poster_card.dart';
import '../../../shared/widgets/tv_focusable.dart';
import 'home_controller.dart';
import 'widgets/home_content_rail.dart';
import 'widgets/home_continue_watching_card.dart';
import 'widgets/home_header.dart';
import 'widgets/home_hero_carousel.dart';
import 'widgets/home_live_channel_card.dart';
import 'widgets/home_quick_actions.dart';
import 'widgets/home_skeleton_loader.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Home',
      showAppBar: false,
      body: Obx(() {
        if (controller.isLoading.value && !controller.hasContent) {
          return const HomeSkeletonLoader();
        }

        if (!controller.hasProviders.value) {
          return SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      AppSpacing.heightLG,
                      _buildWelcomeCard(context, colorScheme),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          color: colorScheme.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Header (Personalized greeting, Search, Settings)
                    HomeHeader(greeting: controller.getGreeting()),
                    AppSpacing.heightXS,

                    // 2. Hero Section / Carousel (Cinematic featured content)
                    if (controller.featuredHeroItems.isNotEmpty) ...[
                      HomeHeroCarousel(
                        items: controller.featuredHeroItems,
                        onWatch: (item) => _openItem(item),
                        onToggleFavorite: (item) => controller.toggleFavorite(item),
                        isFavorite: controller.isItemFavorite,
                      ),
                      AppSpacing.heightMD,
                    ],

                    // 3. Quick Actions
                    const HomeQuickActions(),
                    AppSpacing.heightMD,

                    // 4. Continue Watching
                    if (controller.continueWatching.isNotEmpty) ...[
                      HomeContentRail(
                        title: 'Continue Watching',
                        leading: Icon(
                          Icons.play_circle_outline_rounded,
                          color: colorScheme.primary,
                          size: 20.0,
                        ),
                        items: controller.continueWatching,
                        cardWidth: 160.0,
                        cardHeight: 180.0,
                        itemBuilder: (context, item, index) {
                          return HomeContinueWatchingCard(
                            item: item,
                            onTap: () => _openItem(item),
                          );
                        },
                      ),
                      AppSpacing.heightMD,
                    ],

                    // 5. Live Now
                    if (controller.liveChannels.isNotEmpty) ...[
                      HomeContentRail(
                        title: 'Live Now',
                        leading: const Icon(
                          Icons.fiber_manual_record_rounded,
                          color: Color(0xFFEF4444),
                          size: 16.0,
                        ),
                        items: controller.liveChannels,
                        onSeeAll: () => Get.toNamed(AppRoutes.liveTV),
                        cardWidth: 155.0,
                        cardHeight: 175.0,
                        itemBuilder: (context, item, index) {
                          return HomeLiveChannelCard(
                            channel: item,
                            onTap: () => _playChannel(item),
                          );
                        },
                      ),
                      AppSpacing.heightMD,
                    ],

                    // 6. Trending Movies
                    if (controller.movies.isNotEmpty) ...[
                      HomeContentRail(
                        title: 'Trending Movies',
                        leading: const Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFF59E0B),
                          size: 20.0,
                        ),
                        items: controller.movies,
                        onSeeAll: () => Get.toNamed(AppRoutes.movies),
                        itemBuilder: (context, item, index) {
                          return MediaPosterCard(
                            item: item,
                            onTap: () => _openMovie(item),
                          );
                        },
                      ),
                      AppSpacing.heightMD,
                    ],

                    // 7. Popular Series
                    if (controller.series.isNotEmpty) ...[
                      HomeContentRail(
                        title: 'Popular Series',
                        leading: Icon(
                          AppIcons.series,
                          color: colorScheme.primary,
                          size: 20.0,
                        ),
                        items: controller.series,
                        onSeeAll: () => Get.toNamed(AppRoutes.series),
                        itemBuilder: (context, item, index) {
                          return MediaPosterCard(
                            item: item,
                            onTap: () => _openSeries(item),
                          );
                        },
                      ),
                      AppSpacing.heightMD,
                    ],

                    // 8. Recently Added
                    if (controller.recentlyAdded.isNotEmpty) ...[
                      HomeContentRail(
                        title: 'Recently Added',
                        leading: const Icon(
                          Icons.new_releases_rounded,
                          color: Color(0xFF10B981),
                          size: 20.0,
                        ),
                        items: controller.recentlyAdded,
                        itemBuilder: (context, item, index) {
                          if (item.mediaType == MediaType.channel) {
                            return HomeLiveChannelCard(
                              channel: item,
                              onTap: () => _playChannel(item),
                            );
                          }
                          return MediaPosterCard(
                            item: item,
                            onTap: () => _openItem(item),
                          );
                        },
                      ),
                      AppSpacing.heightMD,
                    ],

                    // 9. My List (Favorites)
                    if (controller.favorites.isNotEmpty) ...[
                      HomeContentRail(
                        title: 'My List',
                        leading: const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFEC4899),
                          size: 20.0,
                        ),
                        items: controller.favorites,
                        onSeeAll: () => Get.toNamed(AppRoutes.favorites),
                        itemBuilder: (context, item, index) {
                          return MediaPosterCard(
                            item: item,
                            onTap: () => _openItem(item),
                          );
                        },
                      ),
                      AppSpacing.heightMD,
                    ] else ...[
                      _buildEmptyMyListCard(context, colorScheme),
                      AppSpacing.heightMD,
                    ],

                    // 10. Browse by Genre (if real genres available in catalog)
                    if (controller.availableGenres.isNotEmpty) ...[
                      _buildGenreSection(context, colorScheme),
                      AppSpacing.heightMD,
                    ],

                    AppSpacing.heightXXL,
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildEmptyMyListCard(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFFEC4899).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                color: Color(0xFFEC4899),
                size: 24.0,
              ),
            ),
            AppSpacing.widthMD,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your My List is Empty',
                    style: AppTypography.getLabel(
                      color: colorScheme.onSurface,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  AppSpacing.heightXXS,
                  Text(
                    'Add movies, series, or channels to quickly access them here.',
                    style: AppTypography.getCaption(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreSection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Text(
            'Browse by Genre',
            style: AppTypography.getTitle(
              color: colorScheme.onSurface,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: controller.availableGenres.length,
            itemBuilder: (context, index) {
              final genre = controller.availableGenres[index];
              return Container(
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                child: TvFocusable(
                  onTap: () => Get.toNamed(
                    AppRoutes.search,
                    arguments: {'query': genre.title},
                  ),
                  borderRadius: AppRadius.pill,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: AppRadius.pill,
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          genre.icon,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          genre.title,
                          style: AppTypography.getLabel(
                            color: colorScheme.onSurface,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.15),
              ),
              child: Icon(AppIcons.play, size: 48.0, color: colorScheme.primary),
            ),
            AppSpacing.heightMD,
            Text(
              'Welcome to StreamHub Pro',
              style: AppTypography.getHeadline(
                color: colorScheme.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            AppSpacing.heightSM,
            Text(
              'Connect your first IPTV or media source to start discovering Live TV, Movies, Series, and more.',
              style: AppTypography.getBody(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.heightXL,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                _buildFeatureChip(
                  icon: AppIcons.liveTv,
                  label: 'Live TV',
                  onTap: () => Get.toNamed(AppRoutes.liveTV),
                  colorScheme: colorScheme,
                ),
                _buildFeatureChip(
                  icon: AppIcons.movies,
                  label: 'Movies',
                  onTap: () => Get.toNamed(AppRoutes.movies),
                  colorScheme: colorScheme,
                ),
                _buildFeatureChip(
                  icon: AppIcons.series,
                  label: 'Series',
                  onTap: () => Get.toNamed(AppRoutes.series),
                  colorScheme: colorScheme,
                ),
                _buildFeatureChip(
                  icon: AppIcons.favorites,
                  label: 'Favorites',
                  onTap: () => Get.toNamed(AppRoutes.favorites),
                  colorScheme: colorScheme,
                ),
              ],
            ),
            AppSpacing.heightXL,
            TvFocusable(
              onTap: () => Get.toNamed(AppRoutes.providerManager),
              borderRadius: AppRadius.pill,
              child: FilledButton.icon(
                onPressed: () => Get.toNamed(AppRoutes.providerManager),
                icon: const Icon(AppIcons.add, size: 18),
                label: const Text('Add Media Source'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip({
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
    VoidCallback? onTap,
  }) {
    return TvFocusable(
      onTap: onTap,
      borderRadius: AppRadius.pill,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: AppRadius.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.0, color: colorScheme.primary),
            AppSpacing.widthXS,
            Text(
              label,
              style: AppTypography.getCaption(color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  void _openItem(MediaItem item) {
    if (item.mediaType == MediaType.series) {
      _openSeries(item);
    } else if (item.mediaType == MediaType.movie) {
      _openMovie(item);
    } else {
      _playChannel(item);
    }
  }

  void _openMovie(MediaItem item) {
    Get.toNamed(
      AppRoutes.fullscreenPlayer,
      arguments: {
        'items': [item],
        'currentId': item.id,
      },
    );
  }

  void _openSeries(MediaItem item) {
    Get.toNamed(
      AppRoutes.seriesDetails,
      arguments: {'item': item},
    );
  }

  void _playChannel(MediaItem item) {
    Get.toNamed(
      AppRoutes.fullscreenPlayer,
      arguments: {
        'items': [item],
        'currentId': item.id,
      },
    );
  }
}
