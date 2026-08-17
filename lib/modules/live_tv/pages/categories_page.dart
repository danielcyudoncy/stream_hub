import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/responsive_helper.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Categories'),
      ),
      body: Obx(() {
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

        if (controller.selectedCategoryId.value.isNotEmpty) {
          final category = controller.categories.firstWhere(
            (c) => c.id == controller.selectedCategoryId.value,
            orElse: () => Category(
              id: '',
              name: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          if (category.id.isNotEmpty) {
            return _buildCategoryDetail(context, category);
          }
        }

        return _buildCategoryGrid(context);
      }),
    );
  }

  Widget _buildCategoryGrid(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveHelper.isPhone(context) ? 2 : (ResponsiveHelper.isDesktop(context) ? 4 : 3),
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.2,
      ),
      itemCount: controller.categories.length,
      itemBuilder: (context, index) {
        final category = controller.categories[index];
        return GestureDetector(
          onTap: () => controller.selectCategory(category.id),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                AppSpacing.heightXS,
                Text(
                  category.name,
                  style: AppTypography.getBody(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.heightXXS,
                Text(
                  '${category.channelCount} channels',
                  style: AppTypography.getCaption(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: AppTypography.getHeadline(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                AppSpacing.heightXS,
                Text(
                  '${category.channelCount} channels',
                  style: AppTypography.getBody(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.heightMD,
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        controller.selectedCategoryId.value = '';
                        controller.categories.refresh();
                      },
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const Text('Back to Categories'),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.md),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveHelper.isPhone(context) ? 2 : (ResponsiveHelper.isDesktop(context) ? 4 : 3),
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
                return ChannelCard(
                  channel: item,
                  onTap: () => Get.toNamed(
                    AppRoutes.channelDetails,
                    parameters: {'channelId': item.id},
                  ),
                  onFavorite: () => controller.toggleFavorite(item),
                  showFavoriteButton: true,
                );
              },
              childCount: controller.selectedCategoryChannels.length,
            ),
          ),
        ),
      ],
    );
  }
}
