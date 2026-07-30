import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/responsive_helper.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_icons.dart';
import '../../../data/models/media_item.dart';
import '../controllers/home_controller.dart';
import '../../../shared/widgets/channel_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/media_section.dart';
import '../../../shared/widgets/category_chip.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTV = ResponsiveHelper.isTV(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return CustomScrollView(
          slivers: [
            _buildSliverAppBar(context, colorScheme, isTV, isDesktop),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (controller.continueWatching.isNotEmpty)
                    MediaSection(
                      title: 'Continue Watching',
                      subtitle: 'Pick up where you left off',
                      items: controller.continueWatching,
                      emptyWidget: const SizedBox.shrink(),
                      itemBuilder: (context, item, index) =>
                          _buildContinueWatchingItem(context, item),
                    ),
                  if (controller.recentlyAdded.isNotEmpty)
                    MediaSection(
                      title: 'Recently Added',
                      subtitle: 'Fresh content from your providers',
                      items: controller.recentlyAdded.take(10).toList(),
                      emptyWidget: const SizedBox.shrink(),
                      onSeeAll: () {
                        Get.toNamed(AppRoutes.libraryOverview);
                      },
                      itemBuilder: (context, item, index) =>
                          _buildChannelCard(context, item, isTV),
                    ),
                  if (controller.favoriteChannels.isNotEmpty)
                    MediaSection(
                      title: 'Favorite Channels',
                      subtitle: 'Your saved favorites',
                      items: controller.favoriteChannels.take(10).toList(),
                      emptyWidget: const SizedBox.shrink(),
                      itemBuilder: (context, item, index) =>
                          _buildChannelCard(context, item, isTV),
                    ),
                  if (controller.categories.isNotEmpty)
                    _buildCategoriesSection(context, colorScheme),
                  if (controller.liveNow.isNotEmpty)
                    MediaSection(
                      title: 'Live Now',
                      subtitle: 'Currently broadcasting',
                      items: controller.liveNow.take(10).toList(),
                      emptyWidget: const SizedBox.shrink(),
                      itemBuilder: (context, item, index) =>
                          _buildChannelCard(context, item, isTV),
                    ),
                  if (controller.recentlyViewed.isNotEmpty)
                    MediaSection(
                      title: 'Recently Viewed',
                      subtitle: 'Your recent activity',
                      items: controller.recentlyViewed.take(10).toList(),
                      emptyWidget: const SizedBox.shrink(),
                      itemBuilder: (context, item, index) =>
                          _buildChannelCard(context, item, isTV),
                    ),
                  _buildQuickActionsSection(context, colorScheme),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    bool isTV,
    bool isDesktop,
  ) {
    return SliverAppBar(
      expandedHeight: isTV ? 200.0 : (isDesktop ? 160.0 : 120.0),
      pinned: true,
      stretch: false,
      backgroundColor: colorScheme.surface,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppConstants.appName,
            style: AppTypography.getHeadline(
              color: colorScheme.primary,
            ),
          ),
          Text(
            'Welcome back',
            style: AppTypography.getBody(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.primary.withValues(alpha: 0.1),
                colorScheme.surface,
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(AppIcons.search),
          onPressed: () => Get.toNamed(AppRoutes.search),
          tooltip: 'Search',
        ),
        IconButton(
          icon: const Icon(AppIcons.favorites),
          onPressed: () => Get.toNamed(AppRoutes.favorites),
          tooltip: 'Favorites',
        ),
      ],
    );
  }

  Widget _buildChannelCard(BuildContext context, MediaItem item, bool isTV) {
    return GestureDetector(
      onTap: () => Get.toNamed(
        AppRoutes.channelDetails,
        parameters: {'channelId': item.id},
      ),
      child: ChannelCard(
        channel: item,
        showFavoriteButton: true,
        showProviderBadge: !isTV,
        showChannelNumber: true,
        showHD: true,
        showCurrentProgram: !isTV,
      ),
    );
  }

  Widget _buildContinueWatchingItem(BuildContext context, MediaItem item) {
    return GestureDetector(
      onTap: () => Get.toNamed(
        AppRoutes.channelDetails,
        parameters: {'channelId': item.id},
      ),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.medium,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.small,
              ),
              child: Center(
                child: Icon(
                  Icons.live_tv_outlined,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  size: 32,
                ),
              ),
            ),
            AppSpacing.heightXS,
            Text(
              item.title,
              style: AppTypography.getBody(
                color: Theme.of(context).colorScheme.onSurface,
                scale: 0.85,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Categories',
            trailing: TextButton(
              onPressed: () => Get.toNamed(AppRoutes.categories),
              child: const Text('See All'),
            ),
          ),
          AppSpacing.heightXS,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in controller.categories.take(10))
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: CategoryChip(
                      category: category,
                      onTap: () {
                        Get.toNamed(
                          AppRoutes.categories,
                          parameters: {'categoryId': category.id},
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Quick Actions',
          ),
          AppSpacing.heightXS,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quickActionItem(
                  context,
                  icon: AppIcons.liveTv,
                  label: 'Live TV',
                  onTap: () => Get.toNamed(AppRoutes.liveTV),
                ),
                _quickActionItem(
                  context,
                  icon: AppIcons.providers,
                  label: 'Providers',
                  onTap: () => Get.toNamed(AppRoutes.providerOverview),
                ),
                _quickActionItem(
                  context,
                  icon: AppIcons.favorites,
                  label: 'Favorites',
                  onTap: () => Get.toNamed(AppRoutes.favorites),
                ),
                _quickActionItem(
                  context,
                  icon: AppIcons.search,
                  label: 'Search',
                  onTap: () => Get.toNamed(AppRoutes.search),
                ),
                _quickActionItem(
                  context,
                  icon: AppIcons.library,
                  label: 'Library',
                  onTap: () => Get.toNamed(AppRoutes.libraryOverview),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(AppSpacing.md),
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.medium,
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: colorScheme.primary, size: 32.0),
            AppSpacing.heightXS,
            Text(
              label,
              style: AppTypography.getCaption(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
