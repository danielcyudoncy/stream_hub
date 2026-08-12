import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/media_item.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';
import 'home_controller.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: '',
      showAppBar: false,
      body: Obx(() {
        if (controller.isLoading.value && controller.hasProviders.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSpacing.heightMD,
                  if (!controller.hasProviders.value)
                    _buildWelcomeCard(context, colorScheme),
                  if (controller.hasProviders.value) ...[
                    _buildQuickActionsSection(context, colorScheme),
                    AppSpacing.heightMD,
                    _buildProviderSummaryCard(context, colorScheme),
                    AppSpacing.heightMD,
                    _buildContinueWatchingSection(context, colorScheme),
                    AppSpacing.heightMD,
                    _buildLiveTVSection(context, colorScheme),
                    AppSpacing.heightMD,
                    _buildMoviesSection(context, colorScheme),
                    AppSpacing.heightMD,
                    _buildSeriesSection(context, colorScheme),
                    AppSpacing.heightMD,
                    _buildTVGuideSection(context, colorScheme),
                    AppSpacing.heightMD,
                    _buildFavoritesSection(context, colorScheme),
                    AppSpacing.heightMD,
                    _buildRecentlyAddedSection(context, colorScheme),
                    AppSpacing.heightMD,
                    _buildRecentlyPlayedSection(context, colorScheme),
                    AppSpacing.heightMD,
                    _buildDownloadsSection(context, colorScheme),
                    AppSpacing.heightXXL,
                  ],
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Icon(AppIcons.play, size: 48.0, color: colorScheme.primary),
            AppSpacing.heightMD,
            Text(
              'Welcome to StreamHub Pro',
              style: AppTypography.getHeadline(color: colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            AppSpacing.heightSM,
            Text(
              'Connect your first media source to begin watching Live TV, Movies, Series, and more.',
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
                  icon: AppIcons.live,
                  label: 'TV Guide',
                  onTap: () => Get.toNamed(AppRoutes.guideSearch),
                  colorScheme: colorScheme,
                ),
                _buildFeatureChip(
                  icon: AppIcons.favorites,
                  label: 'Favorites',
                  onTap: () => Get.toNamed(AppRoutes.favorites),
                  colorScheme: colorScheme,
                ),
                _buildFeatureChip(
                  icon: AppIcons.downloads,
                  label: 'Downloads',
                  colorScheme: colorScheme,
                ),
              ],
            ),
            AppSpacing.heightXL,
            FilledButton.icon(
              onPressed: () => Get.toNamed(AppRoutes.providerManager),
              icon: const Icon(AppIcons.add, size: 18),
              label: const Text('Add Media Source'),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.large,
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

  Widget _buildQuickActionsSection(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Quick Actions'),
          AppSpacing.heightXS,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quickActionChip(
                  context,
                  icon: AppIcons.liveTv,
                  label: 'Watch Live TV',
                  onTap: () => Get.toNamed(AppRoutes.liveTV),
                  colorScheme: colorScheme,
                ),
                _quickActionChip(
                  context,
                  icon: AppIcons.movies,
                  label: 'Browse Movies',
                  onTap: () => Get.toNamed(AppRoutes.movies),
                  colorScheme: colorScheme,
                ),
                _quickActionChip(
                  context,
                  icon: AppIcons.series,
                  label: 'Browse Series',
                  onTap: () => Get.toNamed(AppRoutes.series),
                  colorScheme: colorScheme,
                ),
                _quickActionChip(
                  context,
                  icon: AppIcons.search,
                  label: 'Search',
                  onTap: () => Get.toNamed(AppRoutes.search),
                  colorScheme: colorScheme,
                ),
                _quickActionChip(
                  context,
                  icon: AppIcons.live,
                  label: 'TV Guide',
                  onTap: () {},
                  colorScheme: colorScheme,
                ),
                _quickActionChip(
                  context,
                  icon: AppIcons.downloads,
                  label: 'Downloads',
                  onTap: () {},
                  colorScheme: colorScheme,
                ),
                _quickActionChip(
                  context,
                  icon: AppIcons.providers,
                  label: 'Media Sources',
                  onTap: () => Get.toNamed(AppRoutes.settings),
                  colorScheme: colorScheme,
                ),
                _quickActionChip(
                  context,
                  icon: AppIcons.settings,
                  label: 'Settings',
                  onTap: () => Get.toNamed(AppRoutes.settings),
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.large,
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colorScheme.primary, size: 18.0),
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

  Widget _buildProviderSummaryCard(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        onTap: () => Get.toNamed(AppRoutes.settings),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.providers,
                color: colorScheme.primary,
                size: 24.0,
              ),
            ),
            AppSpacing.widthMD,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Media Sources',
                    style: AppTypography.getTitle(color: colorScheme.onSurface),
                  ),
                  AppSpacing.heightXXS,
                  Text(
                    '${controller.providerCount.value} Connected',
                    style: AppTypography.getCaption(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Manage',
              style: AppTypography.getCaption(color: colorScheme.primary),
            ),
            Icon(
              AppIcons.forward,
              size: 16.0,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueWatchingSection(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Continue Watching',
            trailing: TextButton(
              onPressed: () {},
              child: const Text('See All'),
            ),
          ),
          AppSpacing.heightXS,
          controller.continueWatching.isEmpty
              ? _buildEmptySection(
                  context,
                  'No continue watching items',
                  'Start watching content to see it here.',
                  colorScheme,
                )
              : SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.continueWatching.length,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    itemBuilder: (context, index) {
                      final item = controller.continueWatching[index];
                      return _buildMediaCard(
                        context,
                        item,
                        colorScheme,
                        width: 160,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildLiveTVSection(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Live TV',
            trailing: TextButton(
              onPressed: () => Get.toNamed(AppRoutes.liveTV),
              child: const Text('See All'),
            ),
          ),
          AppSpacing.heightXS,
          controller.liveChannels.isEmpty
              ? _buildEmptySection(
                  context,
                  'No channels available',
                  'Add a provider to start watching Live TV.',
                  colorScheme,
                  actionLabel: 'Add Provider',
                  onAction: () => Get.toNamed(AppRoutes.providerManager),
                )
              : SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.liveChannels.length,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    itemBuilder: (context, index) {
                      final item = controller.liveChannels[index];
                      return _buildMediaCard(
                        context,
                        item,
                        colorScheme,
                        width: 160,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildMoviesSection(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Movies',
            trailing: TextButton(
              onPressed: () => Get.toNamed(AppRoutes.movies),
              child: const Text('See All'),
            ),
          ),
          AppSpacing.heightXS,
          controller.movies.isEmpty
              ? _buildEmptySection(
                  context,
                  'No movies yet',
                  'Add a provider with movie content to see it here.',
                  colorScheme,
                )
              : SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.movies.length,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    itemBuilder: (context, index) {
                      final item = controller.movies[index];
                      return _buildMediaCard(
                        context,
                        item,
                        colorScheme,
                        width: 140,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSeriesSection(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Series',
            trailing: TextButton(
              onPressed: () => Get.toNamed(AppRoutes.series),
              child: const Text('See All'),
            ),
          ),
          AppSpacing.heightXS,
          controller.series.isEmpty
              ? _buildEmptySection(
                  context,
                  'No series yet',
                  'Add a provider with series content to see it here.',
                  colorScheme,
                )
              : SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.series.length,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    itemBuilder: (context, index) {
                      final item = controller.series[index];
                      return _buildMediaCard(
                        context,
                        item,
                        colorScheme,
                        width: 140,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildTVGuideSection(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'TV Guide',
            trailing: TextButton(
              onPressed: () {},
              child: const Text('See All'),
            ),
          ),
          AppSpacing.heightXS,
          _buildGuidePreviewCard(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildGuidePreviewCard(BuildContext context, ColorScheme colorScheme) {
    return AppCard(
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.medium,
            ),
            child: Center(
              child: Icon(
                AppIcons.live,
                size: 48.0,
                color: colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
          ),
          AppSpacing.heightSM,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Currently Airing',
                  style: AppTypography.getTitle(color: colorScheme.onSurface),
                ),
                AppSpacing.heightXXS,
                Text(
                  'No programs available',
                  style: AppTypography.getCaption(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.heightSM,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                _buildGuideTimeSlot('Now', colorScheme),
                AppSpacing.widthSM,
                _buildGuideTimeSlot('Next', colorScheme),
                AppSpacing.widthSM,
                _buildGuideTimeSlot('Later', colorScheme),
              ],
            ),
          ),
          AppSpacing.heightMD,
        ],
      ),
    );
  }

  Widget _buildGuideTimeSlot(String label, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.small,
      ),
      child: Text(
        label,
        style: AppTypography.getCaption(color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildFavoritesSection(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Favorites',
            trailing: TextButton(
              onPressed: () {},
              child: const Text('See All'),
            ),
          ),
          AppSpacing.heightXS,
          controller.favorites.isEmpty
              ? _buildEmptySection(
                  context,
                  'No favorites yet',
                  'Add favorites from Live TV, Movies, or Series.',
                  colorScheme,
                )
              : SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.favorites.length,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    itemBuilder: (context, index) {
                      final item = controller.favorites[index];
                      return _buildMediaCard(
                        context,
                        item,
                        colorScheme,
                        width: 160,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildRecentlyAddedSection(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Recently Added',
            trailing: TextButton(
              onPressed: () {},
              child: const Text('See All'),
            ),
          ),
          AppSpacing.heightXS,
          controller.recentlyAdded.isEmpty
              ? _buildEmptySection(
                  context,
                  'No recently added content',
                  'Add a provider to discover new content.',
                  colorScheme,
                )
              : SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.recentlyAdded.length,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    itemBuilder: (context, index) {
                      final item = controller.recentlyAdded[index];
                      return _buildMediaCard(
                        context,
                        item,
                        colorScheme,
                        width: 140,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildRecentlyPlayedSection(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Recently Played',
            trailing: TextButton(
              onPressed: () {},
              child: const Text('See All'),
            ),
          ),
          AppSpacing.heightXS,
          controller.recentlyPlayed.isEmpty
              ? _buildEmptySection(
                  context,
                  'No recently played content',
                  'Your playback history will appear here.',
                  colorScheme,
                )
              : SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.recentlyPlayed.length,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    itemBuilder: (context, index) {
                      final item = controller.recentlyPlayed[index];
                      return _buildMediaCard(
                        context,
                        item,
                        colorScheme,
                        width: 160,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildDownloadsSection(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Downloads',
            trailing: TextButton(
              onPressed: () {},
              child: const Text('See All'),
            ),
          ),
          AppSpacing.heightXS,
          controller.downloads.isEmpty
              ? _buildEmptySection(
                  context,
                  'No downloads yet',
                  'Download content to watch offline.',
                  colorScheme,
                )
              : SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.downloads.length,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    itemBuilder: (context, index) {
                      final item = controller.downloads[index];
                      return _buildMediaCard(
                        context,
                        item,
                        colorScheme,
                        width: 140,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildMediaCard(
    BuildContext context,
    MediaItem item,
    ColorScheme colorScheme, {
    required double width,
  }) {
    final poster = item.poster ?? item.thumbnail;
    return GestureDetector(
      onTap: () => _openItem(item),
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: AppSpacing.md),
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
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(
                              _getMediaIcon(item),
                              size: 32.0,
                              color: colorScheme.primary.withValues(alpha: 0.3),
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            _getMediaIcon(item),
                            size: 32.0,
                            color: colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
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
                        item.subtitle ?? '',
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
      ),
    );
  }

  IconData _getMediaIcon(MediaItem item) {
    switch (item.mediaType) {
      case MediaType.movie:
        return AppIcons.movies;
      case MediaType.series:
        return AppIcons.series;
      default:
        return AppIcons.liveTv;
    }
  }

  void _openItem(MediaItem item) {
    Get.toNamed(
      AppRoutes.fullscreenPlayer,
      arguments: {
        'items': [item],
        'currentId': item.id,
      },
    );
  }

  Widget _buildEmptySection(
    BuildContext context,
    String title,
    String description,
    ColorScheme colorScheme, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Icon(
            AppIcons.empty,
            size: 40.0,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          AppSpacing.heightSM,
          Text(
            title,
            style: AppTypography.getTitle(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.heightXS,
          Text(
            description,
            style: AppTypography.getCaption(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            AppSpacing.heightMD,
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(AppIcons.add, size: 16),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}
