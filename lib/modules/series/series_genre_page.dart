import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_library.dart';
import 'series_genre_controller.dart';
import 'widgets/series_card.dart';

class SeriesGenrePage extends GetView<SeriesGenreController> {
  const SeriesGenrePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isTv = PlatformHelper.isTV;


    return Obx(
      () => AppScaffold(
        title: controller.genreName.value,
        showNavigation: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: controller.setSortBy,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rating',
                child: Text('Top Rated'),
              ),
              const PopupMenuItem(
                value: 'recent',
                child: Text('Recently Updated'),
              ),
              const PopupMenuItem(
                value: 'title',
                child: Text('Alphabetical (A–Z)'),
              ),
            ],
          ),
        ],
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.series.isEmpty) {
            return EmptyLibrary(
              icon: AppIcons.series,
              title: 'No Series Found',
              description: 'No series found for ${controller.genreName.value}.',
            );
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: isTv ? 180.0 : 140.0,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.62,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = controller.series[index];
                      return SeriesCard(
                        key: ValueKey('genre-${item.id}'),
                        item: item,
                        onTap: () => controller.openSeries(item),
                        onToggleFavorite: () => controller.toggleFavorite(item),
                      );
                    },
                    childCount: controller.series.length,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
