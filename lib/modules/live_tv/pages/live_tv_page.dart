import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_library.dart';
import '../controllers/live_tv_controller.dart';
import '../widgets/live_tv_category_bar.dart';
import '../widgets/live_tv_channel_card.dart';
import '../widgets/live_tv_favorites_row.dart';
import '../widgets/live_tv_hero_card.dart';
import '../widgets/live_tv_search_bar.dart';
import '../widgets/live_tv_skeleton.dart';

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

    return AppScaffold(
      title: 'Live TV',
      actions: [
        // Sort Filter Dropdown
        Obx(
          () => PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort Channels',
            initialValue: controller.selectedSort.value,
            onSelected: (value) => controller.setSort(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'alphabetical',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Alphabetical'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'recentlyAdded',
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Recently Added'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'provider',
                child: Row(
                  children: [
                    Icon(Icons.hub_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('By Provider'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'country',
                child: Row(
                  children: [
                    Icon(Icons.public_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('By Country'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Grid vs List view toggle
        Obx(
          () => IconButton(
            icon: Icon(
              controller.selectedView.value == 'grid'
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
            ),
            tooltip: controller.selectedView.value == 'grid'
                ? 'Switch to List View'
                : 'Switch to Grid View',
            onPressed: () {
              final nextView =
                  controller.selectedView.value == 'grid' ? 'list' : 'grid';
              controller.setView(nextView);
            },
          ),
        ),

        // Refresh action
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh Channels',
          onPressed: controller.refresh,
        ),
      ],
      body: Obx(() {
        if (controller.isLoading.value) {
          return const LiveTvSkeleton();
        }

        final filtered = controller.filteredChannels;
        final isList = controller.selectedView.value == 'list';
        final query = controller.searchQuery.value;
        final selectedCat = controller.selectedCategory.value;
        final favoritesOnly = controller.showFavoritesOnly.value;

        return RefreshIndicator(
          onRefresh: () async => controller.refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Featured "Live Now" Hero Section (shown when not searching)
              if (query.isEmpty && !favoritesOnly && selectedCat == 'All Channels')
                SliverToBoxAdapter(
                  child: Obx(
                    () => LiveTvHeroCard(
                      channel: controller.featuredChannel.value,
                      onWatch: () {
                        final featured = controller.featuredChannel.value;
                        if (featured != null) {
                          controller.openChannel(featured);
                        }
                      },
                      onFavorite: () {
                        final featured = controller.featuredChannel.value;
                        if (featured != null) {
                          controller.toggleFavorite(featured);
                        }
                      },
                    ),
                  ),
                ),

              // 2. Channel Search Bar
              SliverToBoxAdapter(
                child: Obx(
                  () => LiveTvSearchBar(
                    query: controller.searchQuery.value,
                    totalCount: filtered.length,
                    onChanged: (q) => controller.setSearchQuery(q),
                    onClear: () => controller.setSearchQuery(''),
                  ),
                ),
              ),

              // 3. Category Navigation Bar
              SliverToBoxAdapter(
                child: Obx(
                  () => LiveTvCategoryBar(
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

              // 4. Favorites Quick Row (when favorites exist and not filtering)
              if (query.isEmpty &&
                  !favoritesOnly &&
                  controller.favorites.isNotEmpty)
                SliverToBoxAdapter(
                  child: Obx(
                    () => LiveTvFavoritesRow(
                      favorites: controller.favorites,
                      onChannelTap: (channel) => controller.openChannel(channel),
                      onSeeAll: () => controller.setFavoritesOnly(true),
                    ),
                  ),
                ),

              // 5. Section Header / Active Filter Info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          favoritesOnly
                              ? 'Favorite Channels'
                              : (query.isNotEmpty
                                  ? 'Search Results'
                                  : (selectedCat == 'All Channels'
                                      ? 'All Channels'
                                      : selectedCat)),
                          style: AppTypography.getTitle(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${filtered.length} channels',
                        style: AppTypography.getCaption(
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 6. Main Channel List or Grid
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
