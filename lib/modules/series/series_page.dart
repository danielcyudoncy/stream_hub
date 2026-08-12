import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_library.dart';
import '../../../shared/widgets/media_poster_card.dart';
import 'series_controller.dart';

class SeriesPage extends GetView<SeriesController> {
  const SeriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: 'Series',
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.series.isEmpty) {
          return EmptyLibrary(
            icon: AppIcons.series,
            title: 'No Series Yet',
            description:
                'Add a provider with series content to start watching.',
            actionLabel: 'Add Media Source',
            onAction: () => Get.toNamed(AppRoutes.providerManager),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  '${controller.series.length} Series',
                  style: AppTypography.getCaption(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200.0,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.7,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = controller.series[index];
                    return MediaPosterCard(
                      item: item,
                      onTap: () => _openItem(item),
                    );
                  },
                  childCount: controller.series.length,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _openItem(MediaItem item) {
    Get.toNamed(
      AppRoutes.seriesDetails,
      arguments: {'item': item},
    );
  }
}
