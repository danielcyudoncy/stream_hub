import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../data/models/category.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/channel.dart';
import '../controllers/category_controller.dart';
import '../../../shared/widgets/channel_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/empty_library.dart';

class CategoriesPage extends GetView<CategoryController> {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
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
        crossAxisCount: context.isPhone ? 2 : (context.isDesktop ? 4 : 3),
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
                  color: colorScheme.primary,
                ),
                AppSpacing.heightXS,
                Text(
                  category.name,
                  style: AppTypography.getBody(
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.heightXXS,
                Text(
                  '${category.channelCount} channels',
                  style: AppTypography.getCaption(
                    color: colorScheme.onSurfaceVariant,
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
                    color: colorScheme.onSurface,
                  ),
                ),
                AppSpacing.heightXS,
                Text(
                  '${category.channelCount} channels',
                  style: AppTypography.getBody(
                    color: colorScheme.onSurfaceVariant,
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
              crossAxisCount: context.isPhone ? 2 : (context.isDesktop ? 4 : 3),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = category.channelIds.elementAtOrNull(index);
                if (item == null) return const SizedBox.shrink();
                return ChannelCard(
                  channel: MediaItem(
                    id: item,
                    providerId: '',
                    providerType: null,
                    mediaType: MediaType.channel,
                    title: item,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                );
              },
              childCount: category.channelIds.length,
            ),
          ),
        ),
      ],
    );
  }
}