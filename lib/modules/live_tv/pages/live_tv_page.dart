import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_library.dart';
import '../controllers/live_tv_controller.dart';
import '../widgets/live_tv_category_bar.dart';
import '../widgets/live_tv_channel_card.dart';
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

        return RefreshIndicator(
          onRefresh: () async => controller.refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Sticky Header
              SliverAppBar(
                pinned: true,
                floating: true,
                elevation: 0,
                backgroundColor: AppColors.background.withValues(alpha: 0.8),
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
                title: Text(
                  'Live TV',
                  style: AppTypography.getDisplay(
                    color: AppColors.primary,
                  ).copyWith(
                    fontWeight: FontWeight.bold,
                    shadows: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 8.0,
                      )
                    ],
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.search_rounded),
                      color: Colors.white,
                      onPressed: () {
                        Get.toNamed(AppRoutes.guideSearch);
                      },
                    ),
                  ),
                ],
              ),

              // 2. Category Navigation Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.sm,
                    bottom: AppSpacing.sm,
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

              // 3. Main Channel List or Grid
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
