import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/core/utils/responsive_helper.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/modules/free_live_tv/controllers/free_live_tv_controller.dart';
import 'package:stream_hub/modules/free_live_tv/widgets/free_tv_category_bar.dart';
import 'package:stream_hub/modules/free_live_tv/widgets/free_tv_channel_card.dart';
import 'package:stream_hub/modules/free_live_tv/widgets/free_tv_embedded_player.dart';
import 'package:stream_hub/modules/free_live_tv/widgets/free_tv_skeleton.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/empty_library.dart';
import 'package:stream_hub/shared/widgets/error_view.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

class FreeLiveTvPage extends GetView<FreeLiveTvController> {
  const FreeLiveTvPage({super.key});

  static final GlobalKey<PopupMenuButtonState<String>> _sortPopupKey =
      GlobalKey();
  static final GlobalKey<PopupMenuButtonState<String>> _countryPopupKey =
      GlobalKey();

  @override
  Widget build(BuildContext context) {
    final isTV = ResponsiveHelper.isTV(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final crossAxisCount =
        isTV ? 5 : (isDesktop ? 4 : (isTablet ? 3 : 2));

    // Auto-exit fullscreen if device is rotated back to portrait
    if (!isLandscape &&
        controller.isFullscreenMode.value &&
        !isTV &&
        !isDesktop) {
      if (DateTime.now()
              .difference(controller.lastFullscreenEntered)
              .inMilliseconds >
          500) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.isFullscreenMode.value) {
            controller.exitFullscreen();
          }
        });
      }
    }

    return Obx(() {
      if (controller.isLoading.value) {
        return const Scaffold(
          body: FreeTvSkeleton(),
        );
      }

      final filtered = controller.filteredChannels;
      final isList = controller.selectedView.value == 'list';
      final query = controller.searchQuery.value;
      final favoritesOnly = controller.showFavoritesOnly.value;
      final selectedCat = controller.selectedCategory.value;
      final selectedCountry = controller.selectedCountry.value;

      // Fullscreen Intentional Mode
      if (controller.isFullscreenMode.value) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            controller.exitFullscreen();
          },
          child: AppScaffold(
            title: 'Free Live TV',
            showAppBar: false,
            showNavigation: false,
            body: Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: FreeTvEmbeddedPlayer(
                key: controller.embeddedPlayerKey,
                controller: controller,
                isFullscreen: true,
              ),
            ),
          ),
        );
      }

      // Landscape 2-Pane Side-by-Side View
      if (isLandscape && !isDesktop && !isTV) {
        return AppScaffold(
          title: 'Free Live TV',
          showAppBar: false,
          showNavigation: false,
          body: Row(
            children: [
              // Left Pane: Embedded Player + Category Bar
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.44,
                child: Column(
                  children: [
                    _buildTopAppBar(context, isList),
                    Expanded(
                      child: FreeTvEmbeddedPlayer(
                        key: controller.embeddedPlayerKey,
                        controller: controller,
                        isFullscreen: false,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                      child: FreeTvCategoryBar(
                        categories: controller.categories,
                        selectedCategory: controller.selectedCategory.value,
                        countries: controller.countries,
                        selectedCountry: controller.selectedCountry.value,
                        regions: controller.regions,
                        selectedRegion: controller.selectedRegion.value,
                        showFavoritesOnly: controller.showFavoritesOnly.value,
                        favoritesCount: controller.favorites.length,
                        showWorkingOnly: controller.showWorkingOnly.value,
                        workingCount: controller.workingCount.value,
                        isCheckingWorking:
                            controller.isCheckingWorking.value,
                        onCategorySelected: controller.setCategory,
                        onCountrySelected: controller.setCountry,
                        onRegionSelected: controller.setRegion,
                        onFavoritesToggle: controller.setFavoritesOnly,
                        onWorkingToggle: controller.setWorkingOnly,
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Container(
                width: 1.0,
                color: Colors.white.withValues(alpha: 0.08),
              ),

              // Right Pane: Channel Grid / List
              Expanded(
                child: Column(
                  children: [
                    _buildHeaderSummaryRow(
                      favoritesOnly,
                      selectedCountry,
                      selectedCat,
                      filtered.length,
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: controller.refresh,
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

      // Default Portrait View: Sticky Player + Category Bar + Scrollable Channels
      return AppScaffold(
        title: 'Free Live TV',
        showAppBar: false,
        body: Column(
          children: [
            // 1. Top App Bar
            _buildTopAppBar(context, isList),

            // 2. Embedded Player / Hero
            FreeTvEmbeddedPlayer(
              key: controller.embeddedPlayerKey,
              controller: controller,
              isFullscreen: false,
            ),

            // 3. Category & Country Bar
            Padding(
              padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
              child: FreeTvCategoryBar(
                categories: controller.categories,
                selectedCategory: controller.selectedCategory.value,
                countries: controller.countries,
                selectedCountry: controller.selectedCountry.value,
                regions: controller.regions,
                selectedRegion: controller.selectedRegion.value,
                showFavoritesOnly: controller.showFavoritesOnly.value,
                favoritesCount: controller.favorites.length,
                showWorkingOnly: controller.showWorkingOnly.value,
                workingCount: controller.workingCount.value,
                isCheckingWorking: controller.isCheckingWorking.value,
                onCategorySelected: controller.setCategory,
                onCountrySelected: controller.setCountry,
                onRegionSelected: controller.setRegion,
                onFavoritesToggle: controller.setFavoritesOnly,
                onWorkingToggle: controller.setWorkingOnly,
              ),
            ),

          // 4. Header Summary Row
          _buildHeaderSummaryRow(
              favoritesOnly,
              selectedCountry,
              selectedCat,
              filtered.length,
            ),

            const SizedBox(height: 2.0),

            // 5. Channel List / Grid
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
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
    });
  }

  Widget _buildHeaderSummaryRow(
    bool favoritesOnly,
    String selectedCountry,
    String selectedCat,
    int count,
  ) {
    String title = selectedCat;
    if (favoritesOnly) {
      title = 'Favorite Channels';
    } else if (selectedCountry != 'All Countries') {
      title = '$selectedCountry • $selectedCat';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 2.0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
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
              '$count',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelListView(
    List<FreeTvChannel> filtered,
    bool isList,
    bool isTV,
    int crossAxisCount,
    String query,
    bool favoritesOnly,
  ) {
    if (filtered.isEmpty) {
      final hasLoadError = controller.errorMessage.value.isNotEmpty;
      if (hasLoadError && !query.isNotEmpty && !favoritesOnly) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 320),
            child: ErrorView(
              title: 'Unable to load Free Live TV',
              message: controller.errorMessage.value,
              onRetry: controller.refresh,
            ),
          ),
        );
      }

      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: EmptyLibrary(
              title: query.isNotEmpty
                  ? 'No Matching Free Channels'
                  : (favoritesOnly
                      ? 'No Favorite Channels'
                      : 'No Channels Found'),
              description: query.isNotEmpty
                  ? 'No free channels matched "$query". Try searching for another channel or category.'
                  : (favoritesOnly
                      ? 'You haven\'t added any free channels to your favorites yet. Tap the star to favorite any channel.'
                      : 'No channels match the selected country or category filter. Tap below to reset.'),
              actionLabel: 'Reset Filters',
              onAction: controller.clearFilters,
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
          final isPlaying =
              controller.activePlayingChannel.value?.id == item.id;
          return FreeTvChannelCard(
            channel: item,
            isList: true,
            isPlaying: isPlaying,
            onTap: () => controller.openChannel(item),
            onFavorite: () => controller.toggleFavorite(item),
          );
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
        final isPlaying =
            controller.activePlayingChannel.value?.id == item.id;
        return FreeTvChannelCard(
          channel: item,
          isList: false,
          isPlaying: isPlaying,
          onTap: () => controller.openChannel(item),
          onFavorite: () => controller.toggleFavorite(item),
        );
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
                  'Free Live TV',
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
                  '${controller.channels.length} Public Free Channels',
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

          // Country Filter Menu
          TvFocusable(
            onTap: () => _countryPopupKey.currentState?.showButtonMenu(),
            scale: 1.15,
            borderRadius: BorderRadius.circular(24),
            child: PopupMenuButton<String>(
              key: _countryPopupKey,
              padding: const EdgeInsets.all(6.0),
              constraints: const BoxConstraints(maxHeight: 400),
              icon: const Icon(
                Icons.public_rounded,
                size: 18.0,
                color: Colors.white,
              ),
              tooltip: 'Filter by Country',
              color: AppColors.darkSurface,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.medium,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              initialValue: controller.selectedCountry.value,
              onSelected: controller.setCountry,
              itemBuilder: (context) => controller.countries.map(
                (country) => PopupMenuItem(
                  value: country,
                  child: Text(
                    country == 'Nigeria' ? '🇳🇬 Nigeria' : country,
                    style: TextStyle(
                      fontWeight: country == 'Nigeria'
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: country == 'Nigeria'
                          ? AppColors.primary
                          : Colors.white,
                    ),
                  ),
                ),
              ).toList(),
            ),
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
              onPressed: () {
                controller.setView(isList ? 'grid' : 'list');
              },
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
              onSelected: controller.setSort,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'alphabetical',
                  child: Text('A - Z (Alphabetical)'),
                ),
                const PopupMenuItem(
                  value: 'country',
                  child: Text('By Country'),
                ),
                const PopupMenuItem(
                  value: 'category',
                  child: Text('By Category'),
                ),
              ],
            ),
          ),

          // Search Button (Opens in-place search dialog / field)
          TvFocusable(
            onTap: () => _showSearchDialog(context),
            scale: 1.15,
            borderRadius: BorderRadius.circular(24),
            child: IconButton(
              padding: const EdgeInsets.all(6.0),
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.search_rounded,
                size: 18.0,
                color: Colors.white,
              ),
              tooltip: 'Search Free Channels',
              onPressed: () => _showSearchDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Search Free Channels'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. News, Sports, Nigeria, BBC...',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: controller.setSearchQuery,
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.setSearchQuery('');
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
