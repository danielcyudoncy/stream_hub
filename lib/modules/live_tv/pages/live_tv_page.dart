import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/media_item.dart';
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
import '../widgets/live_tv_embedded_player.dart';
import '../widgets/live_tv_skeleton.dart';
import '../../epg/pages/tv_guide_page.dart';
import '../../../shared/widgets/tv_focusable.dart';

class LiveTVPage extends StatefulWidget {
  const LiveTVPage({super.key});

  @override
  State<LiveTVPage> createState() => _LiveTVPageState();
}

class _LiveTVPageState extends State<LiveTVPage> {
  LiveTVController get controller => Get.find<LiveTVController>();

  static final GlobalKey<PopupMenuButtonState<String>> _sortPopupKey =
      GlobalKey();

  @override
  void dispose() {
    if (Get.isRegistered<LiveTVController>()) {
      Get.find<LiveTVController>().stopInlinePlayer();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTV = ResponsiveHelper.isTV(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final crossAxisCount = isTV
        ? 5
        : (isDesktop ? 4 : (isTablet ? 3 : 2));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.isLoading.value) {
        controller.syncHiddenCategories();
        controller.handleNavigationArguments();
      }
    });

    if (isTV || isDesktop) {
      return const TVGuidePage();
    }

    // Track landscape state while in fullscreen to prevent premature auto-exit race
    if (isLandscape && controller.isFullscreenMode.value) {
      controller.hasBeenLandscapeInFullscreen = true;
    }

    // Auto-exit fullscreen only if device was actually in landscape and is now rotated back to portrait
    if (!isLandscape && controller.isFullscreenMode.value && !isTV && !isDesktop) {
      if (controller.hasBeenLandscapeInFullscreen &&
          DateTime.now().difference(controller.lastFullscreenEntered).inMilliseconds > 800) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.isFullscreenMode.value) {
            controller.exitFullscreen();
          }
        });
      }
    }

    return PopScope(
      canPop: !controller.isFullscreenMode.value,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (controller.isFullscreenMode.value) {
          controller.exitFullscreen();
        }
      },
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Scaffold(
            body: LiveTvSkeleton(),
          );
        }

        final filtered = controller.filteredChannels;
        final isList = controller.selectedView.value == 'list';
        final query = controller.searchQuery.value;
        final favoritesOnly = controller.showFavoritesOnly.value;
        final selectedCat = controller.selectedCategory.value;

        // Intentional Fullscreen Toggle Mode (Preserves stream continuously!)
        if (controller.isFullscreenMode.value) {
          return AppScaffold(
            title: 'Live TV',
            showAppBar: false,
            showNavigation: false,
            body: Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: LiveTvEmbeddedPlayer(
                key: controller.playerKey,
                controller: controller,
                isFullscreen: true,
              ),
            ),
          );
        }

      // Landscape 2-Pane Side-by-Side View (Player on left, channels on right)
      if (isLandscape && !isDesktop) {
        return AppScaffold(
          title: 'Live TV',
          showAppBar: false,
          showNavigation: false,
          body: Row(
            children: [
              // Left Pane (45%): Top Bar + Featured Hero / Embedded Player + Category Bar
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.44,
                child: Column(
                  children: [
                    _buildTopAppBar(context, isList),
                    Expanded(
                      child: LiveTvEmbeddedPlayer(
                        key: controller.playerKey,
                        controller: controller,
                        isFullscreen: false,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                      child: LiveTvCategoryBar(
                        categories: controller.categories,
                        selectedCategory: controller.selectedCategory.value,
                        showFavoritesOnly: controller.showFavoritesOnly.value,
                        favoritesCount: controller.favorites.length,
                        onCategorySelected: (cat) => controller.setCategory(cat),
                        onFavoritesToggle: (fav) => controller.setFavoritesOnly(fav),
                      ),
                    ),
                  ],
                ),
              ),

              // Vertical subtle separator
              Container(
                width: 1.0,
                color: Colors.white.withValues(alpha: 0.08),
              ),

              // Right Pane (56%): Channels header + Independent list/grid
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 3.0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              favoritesOnly ? 'Favorite Channels' : selectedCat,
                              style: const TextStyle(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7.0,
                              vertical: 1.5,
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
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 10.0,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => controller.refresh(),
                        child: _buildChannelListView(
                          filtered,
                          isList,
                          isTV,
                          crossAxisCount,
                          query,
                          favoritesOnly,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      // Default Portrait View: Pinned Top Section + Independent Channel List Below
      return AppScaffold(
        title: 'Live TV',
        showAppBar: false,
        body: Column(
          children: [
            // 1. Fixed Sticky App Bar at Top
            _buildTopAppBar(context, isList),

            // 2. Fixed Pinned Top Player (Never scrolls away!)
            LiveTvEmbeddedPlayer(
              key: controller.playerKey,
              controller: controller,
              isFullscreen: false,
            ),

            // 3. Fixed Pinned Category Bar (Never scrolls away!)
            Padding(
              padding: const EdgeInsets.only(
                top: 2.0,
                bottom: 2.0,
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

            // 4. Fixed Category Header with Channel Count
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 2.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      favoritesOnly ? 'Favorite Channels' : selectedCat,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7.0,
                      vertical: 1.5,
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
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 2.0),

            // 5. Scrollable Channel List / Grid Below Pinned Section
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => controller.refresh(),
                child: _buildChannelListView(
                  filtered,
                  isList,
                  isTV,
                  crossAxisCount,
                  query,
                  favoritesOnly,
                ),
              ),
            ),
          ],
        ),
      );
    }),
  );
}

  Widget _buildChannelListView(
    List<MediaItem> filtered,
    bool isList,
    bool isTV,
    int crossAxisCount,
    String query,
    bool favoritesOnly,
  ) {
    if (filtered.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
      );
    }

    if (isList) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 2.0,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return Obx(() {
            final isPlaying = controller.activePlayingChannel.value?.id == item.id;
            return LiveTvChannelCard(
              channel: item,
              isList: true,
              isPlaying: isPlaying,
              onTap: isPlaying
                  ? controller.expandToFullscreen
                  : () => controller.openChannel(item),
              onFavorite: () => controller.toggleFavorite(item),
            );
          });
        },
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: isTV ? 1.1 : 1.0,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return Obx(() {
          final isPlaying = controller.activePlayingChannel.value?.id == item.id;
          return LiveTvChannelCard(
            channel: item,
            isList: false,
            isPlaying: isPlaying,
            onTap: isPlaying
                ? controller.expandToFullscreen
                : () => controller.openChannel(item),
            onFavorite: () => controller.toggleFavorite(item),
          );
        });
      },
    );
  }

  Widget _buildTopAppBar(BuildContext context, bool isList) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 2.0,
        bottom: 2.0,
        left: AppSpacing.md,
        right: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Live TV',
                  style: AppTypography.getDisplay(
                    color: AppColors.primary,
                  ).copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 19.0,
                    shadows: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 8.0,
                      )
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${controller.channels.length} Channels',
                  style: const TextStyle(
                    fontSize: 10.0,
                    color: AppColors.darkTextMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4.0),

          // Provider Switcher Button (Compact Initial Avatar)
          ProviderSelectorButton(
            selectedProviderId: controller.selectedProvider.value,
            onSelectProvider: (providerId) =>
                controller.setProvider(providerId),
            sheetTitle: 'Live TV Provider',
            isCompact: true,
          ),

          // View Mode Toggle (Grid vs List)
          TvFocusable(
            onTap: () {
              controller.setView(isList ? 'grid' : 'list');
            },
            scale: 1.15,
            borderRadius: BorderRadius.circular(24),
            child: IconButton(
              padding: const EdgeInsets.all(6.0),
              constraints: const BoxConstraints(),
              icon: Icon(
                isList
                    ? Icons.grid_view_rounded
                    : Icons.view_agenda_rounded,
                size: 18.0,
              ),
              color: isList ? AppColors.primary : Colors.white,
              tooltip: isList ? 'Switch to Grid View' : 'Switch to List View',
              onPressed: null,
            ),
          ),

          // Sort Menu
          TvFocusable(
            onTap: () => _sortPopupKey.currentState?.showButtonMenu(),
            scale: 1.15,
            borderRadius: BorderRadius.circular(24),
            child: PopupMenuButton<String>(
              key: _sortPopupKey,
              padding: const EdgeInsets.all(6.0),
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.sort_rounded,
                size: 18.0,
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

          // Multi-View (2-4 Concurrent Screens)
          TvFocusable(
            onTap: () async {
              final activeChannel = controller.activePlayingChannel.value ??
                  controller.featuredChannel.value;
              controller.stopInlinePlayer();
              await Get.toNamed(AppRoutes.multiView, arguments: activeChannel);
            },
            scale: 1.15,
            borderRadius: BorderRadius.circular(24),
            child: const IconButton(
              padding: EdgeInsets.all(6.0),
              constraints: BoxConstraints(),
              icon: Icon(
                Icons.grid_view_rounded,
                size: 18.0,
                color: Colors.white,
              ),
              tooltip: 'Multi-View (Multi-Screen)',
              onPressed: null,
            ),
          ),

          // Search Guide
          TvFocusable(
            onTap: () {
              Get.toNamed(AppRoutes.guideSearch);
            },
            scale: 1.15,
            borderRadius: BorderRadius.circular(24),
            child: const IconButton(
              padding: EdgeInsets.all(6.0),
              constraints: BoxConstraints(),
              icon: Icon(
                Icons.search_rounded,
                size: 18.0,
                color: Colors.white,
              ),
              tooltip: 'Search Channels',
              onPressed: null,
            ),
          ),
        ],
      ),
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
