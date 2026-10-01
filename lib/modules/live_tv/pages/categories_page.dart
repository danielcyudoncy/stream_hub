import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/category.dart';
import '../../../shared/widgets/channel_card.dart';
import '../../../shared/widgets/premium_media_card.dart';
import '../../../shared/widgets/search_bar.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../controllers/category_controller.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final CategoryController controller = Get.find<CategoryController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.ensureCategoriesLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Obx(() {
      final isDetailView = controller.selectedCategoryId.value.isNotEmpty;
      final selectedCategory = isDetailView
          ? controller.categories.firstWhereOrNull(
              (c) => c.id == controller.selectedCategoryId.value,
            )
          : null;

      return PopScope(
        canPop: !isDetailView,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && isDetailView) {
            controller.clearSelection();
          }
        },
        child: Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            backgroundColor: colorScheme.surface,
            elevation: 0,
            leading: isDetailView
                ? TvFocusable(
                    onTap: controller.clearSelection,
                    scale: 1.0,
                    borderRadius: BorderRadius.circular(8),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: controller.clearSelection,
                      tooltip: 'Back to Categories',
                    ),
                  )
                : null,
            title: Text(
              isDetailView
                  ? (selectedCategory?.name ?? 'Category')
                  : 'Manage Categories (${controller.categories.length})',
              style: AppTypography.getTitle(color: colorScheme.onSurface).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: isDetailView && selectedCategory != null
                ? [
                    Obx(() {
                      final isHidden =
                          controller.isCategoryHidden(selectedCategory.id);
                      void toggleVisibility() {
                        controller.toggleCategoryVisibility(selectedCategory.id);
                        Get.snackbar(
                          isHidden ? 'Category Unhidden' : 'Category Hidden',
                          isHidden
                              ? '${selectedCategory.name} is now visible across the app.'
                              : '${selectedCategory.name} is now hidden from channel guides.',
                          snackPosition: SnackPosition.BOTTOM,
                          duration: const Duration(seconds: 2),
                        );
                      }

                      return TvFocusable(
                        scale: 1.05,
                        borderRadius: BorderRadius.circular(8),
                        onTap: toggleVisibility,
                        child: IconButton(
                          tooltip: isHidden ? 'Unhide Category' : 'Hide Category',
                          icon: Icon(
                            isHidden
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: isHidden ? Colors.amber : colorScheme.onSurfaceVariant,
                          ),
                          onPressed: toggleVisibility,
                        ),
                      );
                    }),
                  ]
                : [
                    // Sort Menu
                    PopupMenuButton<CategorySortOption>(
                      tooltip: 'Sort Categories',
                      icon: Icon(
                        controller.sortOption.value.icon,
                        color: colorScheme.onSurface,
                      ),
                      initialValue: controller.sortOption.value,
                      onSelected: controller.setSortOption,
                      itemBuilder: (context) {
                        return CategorySortOption.values.map((option) {
                          final isSelected = controller.sortOption.value == option;
                          return PopupMenuItem<CategorySortOption>(
                            value: option,
                            child: Row(
                              children: [
                                Icon(
                                  option.icon,
                                  size: 18,
                                  color: isSelected
                                      ? AppColors.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    option.label,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? AppColors.primary
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                              ],
                            ),
                          );
                        }).toList();
                      },
                    ),

                    // Bulk Actions & Refresh Menu
                    PopupMenuButton<String>(
                      tooltip: 'Category Actions',
                      icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
                      onSelected: (val) {
                        switch (val) {
                          case 'show_all':
                            controller.showAll();
                            Get.snackbar(
                              'All Visible',
                              'All categories in this section are now visible.',
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 2),
                            );
                            break;
                          case 'hide_all':
                            controller.hideAll();
                            Get.snackbar(
                              'All Hidden',
                              'All categories in this section are now hidden.',
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 2),
                            );
                            break;
                          case 'refresh':
                            controller.ensureCategoriesLoaded(force: true);
                            Get.snackbar(
                              'Refreshing',
                              'Scanning catalog for categories...',
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 1),
                            );
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'show_all',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_rounded, size: 18),
                              SizedBox(width: AppSpacing.sm),
                              Text('Unhide All'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'hide_all',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_off_rounded,
                                  size: 18, color: Colors.amber),
                              SizedBox(width: AppSpacing.sm),
                              Text('Hide All'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'refresh',
                          child: Row(
                            children: [
                              Icon(Icons.refresh_rounded, size: 18),
                              SizedBox(width: AppSpacing.sm),
                              Text('Refresh Catalog'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
          ),
          body: _buildBody(context, colorScheme, selectedCategory),
        ),
      );
    });
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme colorScheme,
    Category? selectedCategory,
  ) {
    if (controller.isLoading.value) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            AppSpacing.heightMD,
            Text(
              'Loading categories...',
              style: AppTypography.getBody(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (selectedCategory != null && selectedCategory.id.isNotEmpty) {
      return _buildCategoryDetail(context, selectedCategory);
    }

    return _buildOverview(context, colorScheme);
  }

  Widget _buildOverview(BuildContext context, ColorScheme colorScheme) {
    return Column(
      children: [
        // 1. Media Type Selector Tabs (Live TV, Movies, Series)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Obx(() {
            return Row(
              children: [
                Expanded(
                  child: _buildMediaTypeTab(
                    type: MediaType.channel,
                    label: 'Live TV',
                    icon: Icons.live_tv_rounded,
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _buildMediaTypeTab(
                    type: MediaType.movie,
                    label: 'Movies',
                    icon: Icons.movie_outlined,
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _buildMediaTypeTab(
                    type: MediaType.series,
                    label: 'Series',
                    icon: Icons.tv_rounded,
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            );
          }),
        ),

        // 2. Search Field
        // AppSearchBar owns the TV D-pad contract: the bar itself is a focus
        // stop, the inner text node only takes focus while editing, and
        // Down/Up hand focus back to the surrounding traversal order. A bare
        // TextField cannot do this — DefaultTextEditingShortcuts binds
        // Down/Up to ExtendSelectionVerticallyToAdjacentLineIntent, which is a
        // no-op on a single-line field but still consumes the key, so focus
        // freezes in place.
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: AppSearchBar(
            hintText: 'Search categories...',
            onChanged: (val) => controller.searchQuery.value = val,
          ),
        ),

        // 3. Filter Tabs (All / Visible / Hidden)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Obx(() {
            return Row(
              children: [
                _buildFilterChip('all', 'All (${controller.categories.length})'),
                const SizedBox(width: AppSpacing.xs),
                _buildFilterChip(
                  'visible',
                  'Visible (${controller.visibleCategoriesCount})',
                ),
                const SizedBox(width: AppSpacing.xs),
                _buildFilterChip(
                  'hidden',
                  'Hidden (${controller.hiddenCategoriesCount})',
                  color: Colors.amber,
                ),
              ],
            );
          }),
        ),

        // 4. Category Grid or Empty View
        Expanded(
          child: Obx(() {
            if (controller.categories.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 56,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      AppSpacing.heightMD,
                      Text(
                        'No Categories Available',
                        style: AppTypography.getTitle(
                          color: colorScheme.onSurface,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                      AppSpacing.heightXS,
                      Text(
                        'No categories were found for this section.\nEnsure your playlists or providers are connected.',
                        textAlign: TextAlign.center,
                        style: AppTypography.getBody(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      AppSpacing.heightLG,
                      TvFocusable(
                        onTap: () => controller.ensureCategoriesLoaded(force: true),
                        borderRadius: AppRadius.medium,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              controller.ensureCategoriesLoaded(force: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Catalog'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final filtered = controller.filteredCategories;
            if (filtered.isEmpty) {
              return Center(
                child: Text(
                  'No categories match your filters',
                  style: AppTypography.getBody(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveHelper.isPhone(context)
                    ? 2
                    : (ResponsiveHelper.isDesktop(context) ? 4 : 3),
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.25,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final category = filtered[index];
                return _buildCategoryCard(context, category, colorScheme);
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMediaTypeTab({
    required MediaType type,
    required String label,
    required IconData icon,
    required ColorScheme colorScheme,
  }) {
    final isSelected = controller.selectedMediaType.value == type;

    return TvFocusable(
      onTap: () => controller.setMediaType(type),
      borderRadius: BorderRadius.circular(10),
      scale: 1.03,
      child: GestureDetector(
        onTap: () => controller.setMediaType(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.18)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : colorScheme.outline.withValues(alpha: 0.12),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.primary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6.0),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String tabKey, String label, {Color? color}) {
    final isSelected = controller.filterTab.value == tabKey;
    final activeColor = color ?? AppColors.primary;

    return TvFocusable(
      onTap: () => controller.filterTab.value = tabKey,
      borderRadius: BorderRadius.circular(20.0),
      scale: 1.05,
      child: Builder(
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          return GestureDetector(
            onTap: () => controller.filterTab.value = tabKey,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.2)
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: isSelected
                      ? activeColor
                      : colorScheme.outline.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12.0,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    Category category,
    ColorScheme colorScheme,
  ) {
    return Obx(() {
      final isHidden = controller.isCategoryHidden(category.id);
      final mediaType = controller.selectedMediaType.value;

      IconData categoryIcon = Icons.category_outlined;
      if (mediaType == MediaType.channel) {
        categoryIcon = Icons.live_tv_rounded;
      } else if (mediaType == MediaType.movie) {
        categoryIcon = Icons.movie_outlined;
      } else if (mediaType == MediaType.series) {
        categoryIcon = Icons.tv_rounded;
      }

      final countLabel = mediaType == MediaType.channel
          ? '${category.channelCount} ch'
          : '${category.channelCount} titles';

      return TvFocusable(
        onTap: () => controller.selectCategory(category.id),
        borderRadius: AppRadius.medium,
        scale: 1.04,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: isHidden
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: AppRadius.medium,
            border: Border.all(
              color: isHidden
                  ? Colors.amber.withValues(alpha: 0.4)
                  : colorScheme.outline.withValues(alpha: 0.14),
              width: isHidden ? 1.5 : 1.0,
            ),
          ),
          child: Stack(
            children: [
              // Eye Icon Button (Toggle Category Visibility)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  iconSize: 18.0,
                  visualDensity: VisualDensity.compact,
                  tooltip: isHidden ? 'Unhide Category' : 'Hide Category',
                  icon: Icon(
                    isHidden
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_outlined,
                    color: isHidden
                        ? Colors.amber
                        : colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    controller.toggleCategoryVisibility(category.id);
                    Get.snackbar(
                      isHidden ? 'Category Unhidden' : 'Category Hidden',
                      isHidden
                          ? '${category.name} is now visible.'
                          : '${category.name} is now hidden from channel guides.',
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 1),
                    );
                  },
                ),
              ),

              // Category Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      categoryIcon,
                      size: 26,
                      color: isHidden
                          ? Colors.amber.withValues(alpha: 0.7)
                          : AppColors.primary,
                    ),
                    AppSpacing.heightXS,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        category.name,
                        style: AppTypography.getBody(
                          color: isHidden
                              ? colorScheme.onSurface.withValues(alpha: 0.6)
                              : colorScheme.onSurface,
                        ).copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.0,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppSpacing.heightXXS,
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            countLabel,
                            style: AppTypography.getCaption(
                              color: AppColors.primary,
                            ).copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 10.0,
                            ),
                          ),
                        ),
                        if (isHidden) ...[
                          const SizedBox(width: 4.0),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: const Text(
                              'HIDDEN',
                              style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 9.0,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildCategoryDetail(
    BuildContext context,
    Category category,
  ) {
    final mediaType = controller.selectedMediaType.value;
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: AppTypography.getHeadline(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      AppSpacing.heightXXS,
                      Text(
                        '${controller.selectedCategoryChannels.length} items available • Tap eye icon to hide individual item',
                        style: AppTypography.getBody(
                          color: colorScheme.onSurfaceVariant,
                        ).copyWith(fontSize: 12.0),
                      ),
                    ],
                  ),
                ),
                TvFocusable(
                  onTap: controller.clearSelection,
                  borderRadius: AppRadius.medium,
                  scale: 1.05,
                  child: TextButton.icon(
                    onPressed: controller.clearSelection,
                    icon: const Icon(Icons.grid_view_rounded, size: 16),
                    label: const Text('All Categories'),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.md),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveHelper.isPhone(context)
                  ? 2
                  : (ResponsiveHelper.isDesktop(context) ? 4 : 3),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: mediaType == MediaType.channel ? 0.75 : 0.65,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= controller.selectedCategoryChannels.length) {
                  return const SizedBox.shrink();
                }
                final item = controller.selectedCategoryChannels[index];
                return Obx(() {
                  final isItemHidden = controller.isChannelHidden(item.id);

                  Widget cardWidget;
                  if (mediaType == MediaType.channel) {
                    cardWidget = ChannelCard(
                      channel: item,
                      onTap: () => Get.toNamed(
                        AppRoutes.channelDetails,
                        parameters: {'channelId': item.id},
                      ),
                      onFavorite: () => controller.toggleFavorite(item),
                      showFavoriteButton: true,
                    );
                  } else if (mediaType == MediaType.movie) {
                    cardWidget = PremiumMediaCard(
                      item: item,
                      onTap: () => Get.toNamed(
                        AppRoutes.movieDetails,
                        arguments: item,
                      ),
                    );
                  } else {
                    cardWidget = PremiumMediaCard(
                      item: item,
                      onTap: () => Get.toNamed(
                        AppRoutes.seriesDetails,
                        arguments: item,
                      ),
                    );
                  }

                  return Stack(
                    children: [
                      Opacity(
                        opacity: isItemHidden ? 0.45 : 1.0,
                        child: cardWidget,
                      ),
                      Positioned(
                        top: 6.0,
                        left: 6.0,
                        child: TvFocusable(
                          onTap: () {
                            controller.toggleChannelVisibility(item.id);
                            Get.snackbar(
                              isItemHidden
                                  ? 'Item Unhidden'
                                  : 'Item Hidden',
                              isItemHidden
                                  ? '${item.title} is now visible.'
                                  : '${item.title} is now hidden.',
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 1),
                            );
                          },
                          borderRadius: BorderRadius.circular(16.0),
                          scale: 1.15,
                          child: Container(
                            padding: const EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isItemHidden
                                    ? Colors.amber
                                    : Colors.white24,
                              ),
                            ),
                            child: Icon(
                              isItemHidden
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_outlined,
                              size: 16.0,
                              color: isItemHidden
                                  ? Colors.amber
                                  : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                });
              },
              childCount: controller.selectedCategoryChannels.length,
            ),
          ),
        ),
      ],
    );
  }
}
