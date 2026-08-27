import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_library.dart';
import '../../../shared/widgets/provider_selector_button.dart';
import '../controllers/live_tv_controller.dart';
import '../widgets/live_tv_category_bar.dart';
import '../widgets/live_tv_channel_card.dart';
import '../widgets/live_tv_hero_card.dart';
import '../widgets/live_tv_skeleton.dart';
import '../../epg/pages/tv_guide_page.dart';

class LiveTVPage extends GetView<LiveTVController> {
  const LiveTVPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isTV = ResponsiveHelper.isTV(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    final crossAxisCount = isTV
        ? 5
        : (isDesktop ? 4 : (isTablet ? 3 : 2));

    if (isTV) {
      return const TVGuidePage();
    }

    return AppScaffold(
      title: 'Live TV',
      showAppBar: false,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const LiveTvSkeleton();
        }

        final filtered = controller.filteredChannels;
        final isList = controller.selectedView.value == 'list';
        final query = controller.searchQuery.value;
        final favoritesOnly = controller.showFavoritesOnly.value;
        final selectedCat = controller.selectedCategory.value;
        final featured = controller.featuredChannel.value;

        return RefreshIndicator(
          onRefresh: () async => controller.refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Sticky Glassmorphism Header
              SliverAppBar(
                pinned: true,
                floating: true,
                elevation: 0,
                backgroundColor: AppColors.background.withValues(alpha: 0.85),
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1.0),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.05),
                    height: 1.0,
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Live TV',
                      style: AppTypography.getDisplay(
                        color: AppColors.primary,
                      ).copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 22.0,
                        shadows: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 8.0,
                          )
                        ],
                      ),
                    ),
                    Text(
                      '${controller.channels.length} Available Channels',
                      style: const TextStyle(
                        fontSize: 11.0,
                        color: AppColors.darkTextMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                actions: [
                  // Provider Switcher Button (Compact Initial Avatar)
                  ProviderSelectorButton(
                    selectedProviderId: controller.selectedProvider.value,
                    onSelectProvider: (providerId) =>
                        controller.setProvider(providerId),
                    sheetTitle: 'Live TV Provider',
                    isCompact: true,
                  ),

                  // View Mode Toggle (Grid vs List)
                  Container(
                    margin: const EdgeInsets.only(right: 6.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        isList
                            ? Icons.grid_view_rounded
                            : Icons.view_agenda_rounded,
                        size: 20.0,
                      ),
                      color: isList ? AppColors.primary : Colors.white,
                      tooltip: isList ? 'Switch to Grid View' : 'Switch to List View',
                      onPressed: () {
                        controller.setView(isList ? 'grid' : 'list');
                      },
                    ),
                  ),

                  // Sort Menu
                  Container(
                    margin: const EdgeInsets.only(right: 6.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.sort_rounded,
                        size: 20.0,
                        color: Colors.white,
                      ),
                      tooltip: 'Sort Channels',
                      color: AppColors.darkSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.medium,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      initialValue: controller.selectedSort.value,
                      onSelected: (val) => controller.setSort(val),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'alphabetical',
                          child: Text('A - Z (Alphabetical)'),
                        ),
                        const PopupMenuItem(
                          value: 'recentlyAdded',
                          child: Text('Recently Added'),
                        ),
                        const PopupMenuItem(
                          value: 'provider',
                          child: Text('By Source / Provider'),
                        ),
                        const PopupMenuItem(
                          value: 'country',
                          child: Text('By Country'),
                        ),
                      ],
                    ),
                  ),

                  // Search Guide
                  Container(
                    margin: const EdgeInsets.only(right: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.search_rounded,
                        size: 20.0,
                        color: Colors.white,
                      ),
                      tooltip: 'Search Channels',
                      onPressed: () {
                        Get.toNamed(AppRoutes.guideSearch);
                      },
                    ),
                  ),
                ],
              ),

              // 2. Featured / Last-Watched Channel Hero Showcase
              if (featured != null &&
                  query.isEmpty &&
                  !favoritesOnly &&
                  selectedCat == 'All Channels')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: LiveTvHeroCard(
                      channel: featured,
                      onWatch: () => controller.openChannel(featured),
                      onFavorite: () => controller.toggleFavorite(featured),
                    ),
                  ),
                ),

              // 3. Category Navigation Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.sm,
                    bottom: AppSpacing.xs,
                  ),
                  child: LiveTvCategoryBar(
                    categories: controller.categories,
                    selectedCategory: controller.selectedCategory.value,
                    showFavoritesOnly: controller.showFavoritesOnly.value,
                    favoritesCount: controller.favorites.length,
                    onCategorySelected: (cat) {
                      controller.setCategory(cat);
                    },
                    onFavoritesToggle: (fav) {
                      controller.setFavoritesOnly(fav);
                    },
                  ),
                ),
              ),

              // 4. Category Header with Channel Count
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Text(
                        favoritesOnly ? 'Favorite Channels' : selectedCat,
                        style: const TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: AppRadius.pill,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${filtered.length}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11.0,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Main Channel List or Grid
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: EmptyLibrary(
                        title: query.isNotEmpty
                            ? 'No Matching Channels'
                            : (favoritesOnly
                                ? 'No Favorite Channels'
                                : 'No Channels in This Category'),
                        description: query.isNotEmpty
                            ? 'No channels matched "$query". Try a different search keyword or clear the search.'
                            : (favoritesOnly
                                ? 'You haven\'t added any channels to your favorites yet. Tap the heart on any channel to favorite it.'
                                : 'No channels were found in this category. Try selecting another category or resetting filters.'),
                        actionLabel: 'Reset Filters',
                        onAction: _clearFilters,
                      ),
                    ),
                  ),
                )
              else if (isList)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = filtered[index];
                        return LiveTvChannelCard(
                          channel: item,
                          isList: true,
                          onTap: () => controller.openChannel(item),
                          onFavorite: () => controller.toggleFavorite(item),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: isTV ? 1.1 : 1.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = filtered[index];
                        return LiveTvChannelCard(
                          channel: item,
                          isList: false,
                          onTap: () => controller.openChannel(item),
                          onFavorite: () => controller.toggleFavorite(item),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxl),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _clearFilters() {
    controller.setSearchQuery('');
    controller.setCategory('All Channels');
    controller.setProvider('');
    controller.setLanguage('');
    controller.setCountry('');
    controller.setResolution('');
    controller.setFavoritesOnly(false);
    controller.setRecentlyAdded(false);
  }
}
