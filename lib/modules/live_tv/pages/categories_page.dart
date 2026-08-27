import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/category.dart';
import '../controllers/category_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/channel_card.dart';
import '../../../shared/widgets/empty_library.dart';

class CategoriesPage extends GetView<CategoryController> {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Obx(() {
      final isDetailView = controller.selectedCategoryId.value.isNotEmpty;
      final selectedCategory = isDetailView
          ? controller.categories.firstWhere(
              (c) => c.id == controller.selectedCategoryId.value,
              orElse: () => Category(
                id: '',
                name: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
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
            leading: isDetailView
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: controller.clearSelection,
                  )
                : null,
            title: Text(
              isDetailView
                  ? (selectedCategory?.name ?? 'Category')
                  : 'Manage Categories (${controller.categories.length})',
            ),
            actions: isDetailView && selectedCategory != null
                ? [
                    Obx(() {
                      final isHidden =
                          controller.isCategoryHidden(selectedCategory.id);
                      return IconButton(
                        tooltip: isHidden ? 'Unhide Category' : 'Hide Category',
                        icon: Icon(
                          isHidden
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: isHidden ? Colors.amber : Colors.white70,
                        ),
                        onPressed: () {
                          controller
                              .toggleCategoryVisibility(selectedCategory.id);
                          Get.snackbar(
                            isHidden ? 'Category Unhidden' : 'Category Hidden',
                            isHidden
                                ? '${selectedCategory.name} is now visible across the app.'
                                : '${selectedCategory.name} is now hidden from channel guides.',
                            snackPosition: SnackPosition.BOTTOM,
                            duration: const Duration(seconds: 2),
                          );
                        },
                      );
                    }),
                  ]
                : null,
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
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (controller.categories.isEmpty) {
      return const EmptyLibrary(
        title: 'No Categories',
        description:
            'No categories available yet. Add providers to populate categories.',
      );
    }

    if (selectedCategory != null && selectedCategory.id.isNotEmpty) {
      return _buildCategoryDetail(context, selectedCategory);
    }

    return _buildCategoryGrid(context);
  }

  Widget _buildCategoryGrid(BuildContext context) {
    final filtered = controller.filteredCategories;

    return Column(
      children: [
        // 1. Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: TextField(
            onChanged: (val) => controller.searchQuery.value = val,
            decoration: InputDecoration(
              hintText: 'Search categories...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: controller.searchQuery.value.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => controller.searchQuery.value = '',
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF161B22),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
        ),

        // 2. Filter Tabs (All / Visible / Hidden)
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
                _buildFilterChip('visible',
                    'Visible (${controller.visibleCategoriesCount})'),
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

        // 3. Grid View
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No categories found',
                    style: AppTypography.getBody(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : GridView.builder(
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
                    return Obx(() {
                      final isHidden =
                          controller.isCategoryHidden(category.id);
                      return GestureDetector(
                        onTap: () => controller.selectCategory(category.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: isHidden
                                ? const Color(0xFF161B22).withValues(alpha: 0.45)
                                : const Color(0xFF161B22),
                            borderRadius: AppRadius.medium,
                            border: Border.all(
                              color: isHidden
                                  ? Colors.amber.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment.topRight,
                                child: IconButton(
                                  iconSize: 18.0,
                                  visualDensity: VisualDensity.compact,
                                  tooltip: isHidden
                                      ? 'Unhide Category'
                                      : 'Hide Category',
                                  icon: Icon(
                                    isHidden
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_outlined,
                                    color: isHidden
                                        ? Colors.amber
                                        : Colors.white38,
                                  ),
                                  onPressed: () {
                                    controller.toggleCategoryVisibility(
                                        category.id);
                                    Get.snackbar(
                                      isHidden
                                          ? 'Category Unhidden'
                                          : 'Category Hidden',
                                      isHidden
                                          ? '${category.name} is now visible.'
                                          : '${category.name} hidden from Live TV & EPG.',
                                      snackPosition: SnackPosition.BOTTOM,
                                      duration: const Duration(seconds: 1),
                                    );
                                  },
                                ),
                              ),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.category_outlined,
                                      size: 26,
                                      color: isHidden
                                          ? Colors.amber.withValues(alpha: 0.7)
                                          : AppColors.primary,
                                    ),
                                    AppSpacing.heightXS,
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4.0),
                                      child: Text(
                                        category.name,
                                        style: AppTypography.getBody(
                                          color: isHidden
                                              ? Colors.white60
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
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
                                            color: AppColors.primary
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                          ),
                                          child: Text(
                                            '${category.channelCount} ch',
                                            style: AppTypography.getCaption(
                                              color: AppColors.primary,
                                            ).copyWith(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 10.0),
                                          ),
                                        ),
                                        if (isHidden) ...[
                                          const SizedBox(width: 4.0),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 6.0,
                                              vertical: 2.0,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.amber
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
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
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String tabKey, String label, {Color? color}) {
    final isSelected = controller.filterTab.value == tabKey;
    final activeColor = color ?? AppColors.primary;

    return GestureDetector(
      onTap: () => controller.filterTab.value = tabKey,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected
                ? activeColor
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12.0,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDetail(
    BuildContext context,
    Category category,
  ) {
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
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      AppSpacing.heightXXS,
                      Text(
                        '${controller.selectedCategoryChannels.length} channels available • Tap eye icon to hide/unhide channel',
                        style: AppTypography.getBody(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ).copyWith(fontSize: 12.0),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: controller.clearSelection,
                  icon: const Icon(Icons.grid_view_rounded, size: 16),
                  label: const Text('All Categories'),
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
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= controller.selectedCategoryChannels.length) {
                  return const SizedBox.shrink();
                }
                final item = controller.selectedCategoryChannels[index];
                return Obx(() {
                  final isChanHidden =
                      controller.isChannelHidden(item.id);
                  return Stack(
                    children: [
                      Opacity(
                        opacity: isChanHidden ? 0.45 : 1.0,
                        child: ChannelCard(
                          channel: item,
                          onTap: () => Get.toNamed(
                            AppRoutes.channelDetails,
                            parameters: {'channelId': item.id},
                          ),
                          onFavorite: () => controller.toggleFavorite(item),
                          showFavoriteButton: true,
                        ),
                      ),
                      Positioned(
                        top: 6.0,
                        left: 6.0,
                        child: GestureDetector(
                          onTap: () {
                            controller.toggleChannelVisibility(item.id);
                            Get.snackbar(
                              isChanHidden
                                  ? 'Channel Unhidden'
                                  : 'Channel Hidden',
                              isChanHidden
                                  ? '${item.title} is now visible.'
                                  : '${item.title} is now hidden.',
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 1),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isChanHidden
                                    ? Colors.amber
                                    : Colors.white24,
                              ),
                            ),
                            child: Icon(
                              isChanHidden
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_outlined,
                              size: 16.0,
                              color: isChanHidden
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
