import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_library.dart';
import '../../../shared/widgets/media_carousel.dart';
import '../../../shared/widgets/media_poster_card.dart';
import '../../../shared/widgets/media_section.dart';
import 'movies_controller.dart';

class MoviesPage extends GetView<MoviesController> {
  const MoviesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: 'Movies',
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.movies.isEmpty) {
          return EmptyLibrary(
            icon: AppIcons.movies,
            title: 'No Movies Yet',
            description: 'Add a provider with movie content to start watching.',
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
                  '${controller.movies.length} Movies',
                  style: AppTypography.getCaption(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (controller.featuredMovies.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: MediaCarousel(
                  items: controller.featuredMovies,
                  itemWidth: 120,
                  itemBuilder: (context, item, index) {
                    final mediaItem = item as MediaItem;
                    return MediaPosterCard(
                      item: mediaItem,
                      onTap: () => _openItem(context, mediaItem),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(child: AppSpacing.heightSM),
            ],
            _buildSection(
              title: 'Trending Movies',
              items: controller.trendingMovies,
            ),
            _buildSection(
              title: 'New This Week',
              items: controller.newThisWeekMovies,
            ),
            _buildSection(
              title: 'Mystery & Thriller',
              items: controller.mysteryThrillerMovies,
            ),
            _buildSection(
              title: 'Romantic Comedies',
              items: controller.romanticComedyMovies,
            ),
            _buildSection(title: 'Top Rated', items: controller.topRatedMovies),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.7,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = controller.movies[index];
                  return MediaPosterCard(
                    item: item,
                    onTap: () => _openItem(context, item),
                  );
                }, childCount: controller.movies.length),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSection({
    required String title,
    required List<MediaItem> items,
  }) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: MediaSection(
        title: title,
        items: items,
        onSeeAll: () {},
        itemBuilder: (context, item, index) {
          return SizedBox(
            width: 120,
            child: MediaPosterCard(
              item: item,
              onTap: () => _openItem(context, item),
            ),
          );
        },
      ),
    );
  }

  void _openItem(BuildContext context, MediaItem item) {
    if (!controller.canOpenMovie(item)) {
      Get.snackbar('Not Available', 'This movie is not available right now.');
      return;
    }

    Get.toNamed(
      AppRoutes.fullscreenPlayer,
      arguments: {
        'items': [item],
        'currentId': item.id,
      },
    );
  }
}
