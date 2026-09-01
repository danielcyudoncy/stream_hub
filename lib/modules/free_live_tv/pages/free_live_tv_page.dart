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

      // TV / Large-Screen View: Mirrors the Live TV Guide design with a
      // prominent 16:9 mini-player on the right of a top showcase.
      if (isTV || isDesktop) {
        return _buildTVLayout(
          context,
          filtered,
          isList,
          crossAxisCount,
          favoritesOnly,
          selectedCountry,
          selectedCat,
          query,
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

  Widget _buildTVLayout(
    BuildContext context,
    List<FreeTvChannel> filtered,
    bool isList,
    int crossAxisCount,
    bool favoritesOnly,
    String selectedCountry,
    String selectedCat,
    String query,
  ) {
    return AppScaffold(
      title: 'Free Live TV',
      showAppBar: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Showcase: Channel Info on Left, Large 16:9 Live Mini-Player on Right
          _buildTopShowcase(context),

          // 2. Full-Width Category Rail Below the Player
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xs,
            ),
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

          AppSpacing.heightXS,

          // 3. Header Summary Row
          _buildHeaderSummaryRow(
            favoritesOnly,
            selectedCountry,
            selectedCat,
            filtered.length,
          ),

          const SizedBox(height: 2.0),

          // 4. Channel Catalog Grid / List
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                child: _buildChannelListView(
                  filtered,
                  isList,
                  true,
                  crossAxisCount,
                  query,
                  favoritesOnly,
                ),
              ),
            ),
          ),

          // 5. TV Remote D-Pad Navigation Legend Bar
          _buildRemoteLegendBar(),
        ],
      ),
    );
  }

  Widget _buildTopShowcase(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Pane: Header + Active Channel Information Showcase
          Expanded(
            child: _buildShowcaseInfo(context),
          ),

          AppSpacing.widthLG,

          // Right Pane: Prominent 16:9 Live Mini-Player (440x248 on TV)
          Container(
            width: 440,
            height: 248,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FreeTvEmbeddedPlayer(
                key: controller.embeddedPlayerKey,
                controller: controller,
                isFullscreen: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowcaseInfo(BuildContext context) {
    return Obx(() {
      final active = controller.activePlayingChannel.value ??
          controller.featuredChannel.value ??
          (controller.filteredChannels.isNotEmpty
              ? controller.filteredChannels.first
              : null);
      final isList = controller.selectedView.value == 'list';
      final featured = controller.featuredChannel.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Top Action Row: Title, "FREE" Badge, View Mode Toggle, Search, Refresh
          Row(
            children: [
              Flexible(
                child: Text(
                  'Free Live TV',
                  style: AppTypography.getDisplay(
                    color: AppColors.primary,
                  ).copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                    shadows: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 8.0,
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.widthMD,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  'FREE',
                  style: AppTypography.getLabel(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              TvFocusable(
                onTap: () => controller.setView(isList ? 'grid' : 'list'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isList
                            ? Icons.grid_view_rounded
                            : Icons.view_agenda_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isList ? 'Grid View' : 'List View',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.widthSM,
              TvFocusable(
                onTap: () => _showSearchDialog(context),
                scale: 1.15,
                borderRadius: BorderRadius.circular(24),
                child: IconButton(
                  icon: const Icon(Icons.search),
                  color: AppColors.textSecondary,
                  focusColor: AppColors.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  onPressed: () => _showSearchDialog(context),
                ),
              ),
              AppSpacing.widthSM,
              TvFocusable(
                onTap: controller.refresh,
                scale: 1.15,
                borderRadius: BorderRadius.circular(24),
                child: IconButton(
                  icon: const Icon(Icons.refresh),
                  color: AppColors.textSecondary,
                  focusColor: AppColors.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  onPressed: controller.refresh,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 2. Active Playing / Focused Channel Showcase Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: active != null
                ? _buildChannelShowcase(active)
                : _buildFreeShowcase(featured),
          ),
        ],
      );
    });
  }

  Widget _buildChannelShowcase(FreeTvChannel channel) {
    final categoryName = channel.categories.isNotEmpty
        ? channel.categories.first
        : 'Free TV';
    final description = channel.network != null &&
            channel.network!.isNotEmpty
        ? 'Network: ${channel.network}'
        : (channel.country.isNotEmpty
            ? '${channel.country} • Public Free Stream'
            : 'Public Free Stream');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Channel Logo or Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Center(
                child: (channel.logo != null && channel.logo!.isNotEmpty)
                    ? Image.network(
                        channel.logo!,
                        width: 38,
                        height: 38,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.tv, color: Colors.white),
                      )
                    : Text(
                        channel.name.isNotEmpty
                            ? channel.name.substring(0, 1).toUpperCase()
                            : 'TV',
                        style: AppTypography.getTitle(
                          color: AppColors.primary,
                        ),
                      ),
              ),
            ),
            AppSpacing.widthMD,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          channel.name,
                          style: AppTypography.getHeadline(
                            color: Colors.white,
                          ).copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          channel.qualityTier == FreeTvQualityTier.recommended
                              ? 'RECOMMENDED'
                              : 'HD',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$categoryName • ${channel.country}',
                    style: AppTypography.getLabel(
                      color: AppColors.textSecondary,
                    ).copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Stream / Network / Working Info
        Row(
          children: [
            Expanded(
              child: Text(
                description,
                style: AppTypography.getBody(
                  color: Colors.white.withValues(alpha: 0.9),
                ).copyWith(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (channel.streamUrls.length > 1)
              Text(
                '${channel.streamUrls.length} streams',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (channel.isWorking == true)
              _showcaseChip(
                Icons.check_circle_rounded,
                'WORKING',
                Colors.greenAccent,
              ),
            if (channel.isWorking == false) ...[
              const SizedBox(width: 8),
              _showcaseChip(
                Icons.cancel_rounded,
                'OFFLINE',
                AppColors.error,
              ),
            ],
            const Spacer(),
            TvFocusable(
              onTap: () => controller.openChannel(channel),
              borderRadius: AppRadius.pill,
              child: FilledButton.icon(
                onPressed: () => controller.openChannel(channel),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Watch Channel'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _showcaseChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pill,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeShowcase(FreeTvChannel? featured) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.tv_rounded, color: AppColors.primary, size: 28),
            AppSpacing.widthMD,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Free Live TV',
                    style: AppTypography.getTitle(
                      color: Colors.white,
                    ).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Thousands of free global channels. No provider required.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (featured != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  featured.name,
                  style: AppTypography.getHeadline(
                    color: Colors.white,
                  ).copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              TvFocusable(
                onTap: () => controller.openChannel(featured),
                borderRadius: AppRadius.pill,
                child: FilledButton.icon(
                  onPressed: () => controller.openChannel(featured),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Watch Featured'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRemoteLegendBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem(Icons.play_circle_fill, 'OK: Play Fullscreen'),
          AppSpacing.widthLG,
          _legendItem(Icons.star_rounded, 'STAR: Favorite Channel'),
          AppSpacing.widthLG,
          _legendItem(Icons.swap_horiz, '◄ / ►: Categories & Filters'),
          AppSpacing.widthLG,
          _legendItem(Icons.grid_view_rounded, 'View: Toggle Grid / List'),
        ],
      ),
    );
  }

  Widget _legendItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
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
          return Obx(() {
            final isPlaying =
                controller.activePlayingChannel.value?.id == item.id;
            return FreeTvChannelCard(
              channel: item,
              isList: true,
              isPlaying: isPlaying,
              onTap: () => controller.openChannel(item),
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
          final isPlaying =
              controller.activePlayingChannel.value?.id == item.id;
          return FreeTvChannelCard(
            channel: item,
            isList: false,
            isPlaying: isPlaying,
            onTap: () => controller.openChannel(item),
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
