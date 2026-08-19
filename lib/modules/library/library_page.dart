import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';
import 'library_controller.dart';

class LibraryPage extends GetView<LibraryController> {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Library',
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLibraryStats(context, colorScheme),
                  AppSpacing.heightMD,
                  _buildMoviesSection(context, colorScheme),
                  AppSpacing.heightMD,
                  _buildSeriesSection(context, colorScheme),
                  AppSpacing.heightMD,
                  _buildFavoritesSection(context, colorScheme),
                  AppSpacing.heightMD,
                  _buildContinueWatchingSection(context, colorScheme),
                  AppSpacing.heightMD,
                  _buildDownloadsSection(context, colorScheme),
                  AppSpacing.heightMD,
                  _buildHistorySection(context, colorScheme),
                  AppSpacing.heightXXL,
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildLibraryStats(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          _buildStatChip(
            icon: AppIcons.movies,
            label: '${controller.movieCount.value}',
            subtitle: 'Movies',
            colorScheme: colorScheme,
          ),
          AppSpacing.widthSM,
          _buildStatChip(
            icon: AppIcons.series,
            label: '${controller.seriesCount.value}',
            subtitle: 'Series',
            colorScheme: colorScheme,
          ),
          AppSpacing.widthSM,
          _buildStatChip(
            icon: AppIcons.favorites,
            label: '${controller.favoriteCount.value}',
            subtitle: 'Favorites',
            colorScheme: colorScheme,
          ),
          AppSpacing.widthSM,
          _buildStatChip(
            icon: AppIcons.downloads,
            label: '${controller.downloadCount.value}',
            subtitle: 'Downloads',
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String subtitle,
    required ColorScheme colorScheme,
  }) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Icon(icon, color: colorScheme.primary, size: 24.0),
            AppSpacing.heightXS,
            Text(
              label,
              style: AppTypography.getTitle(
                color: colorScheme.onSurface,
                scale: 1.2,
              ),
            ),
            Text(
              subtitle,
              style: AppTypography.getCaption(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoviesSection(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Movies',
            trailing: TextButton(
              onPressed: () {},
              child: const Text('See All'),
            ),
          ),
          AppSpacing.heightXS,
          controller.movies.isEmpty
              ? _buildEmptyLibrary(
                  context,
                  colorScheme,
                  'No movies',
                  'Add a provider with movie content.',
                )
              : SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.movies.length,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    itemBuilder: (context, index) {
                      final item = controller.movies[index];
                      return _buildLibraryCard(
                        context,
                        item,
                        colorScheme,
                        width: 140,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSeriesSection(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Series',
            trailing: TextButton(
              onPressed: () {},
              child: const Text('See All'),
            ),
          ),
          AppSpacing.heightXS,
          controller.series.isEmpty
              ? _buildEmptyLibrary(
                  context,
                  colorScheme,
                  'No series',
                  'Add a provider with series content.',
                )
              : SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.series.length,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    itemBuilder: (context, index) {
                      final item = controller.series[index];
                      return _buildLibraryCard(
                        context,
                        item,
                        colorScheme,
                        width: 140,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildFavoritesSection(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Favorites',
            trailing: TextButton(
              onPressed: () {},
              child: const Text('See All'),
            ),
          ),
          AppSpacing.heightXS,
          controller.favorites.isEmpty
              ? _buildEmptyLibrary(
                  context,
                  colorScheme,
                  'No favorites',
                  'Add favorites from Live TV, Movies, or Series.',
                )
              : SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.favorites.length,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    itemBuilder: (context, index) {
                      final item = controller.favorites[index];
                      return _buildLibraryCard(
                        context,
                        item,
                        colorScheme,
                        width: 160,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildContinueWatchingSection(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Continue Watching',
            trailing: TextButton(
              onPressed: () {},
              child: const Text('See All'),
            ),
          ),
          AppSpacing.heightXS,
          controller.continueWatching.isEmpty
              ? _buildEmptyLibrary(
                  context,
                  colorScheme,
                  'No continue watching',
                  'Start watching content to see it here.',
                )
              : SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.continueWatching.length,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    itemBuilder: (context, index) {
                      final item = controller.continueWatching[index];
                      return _buildLibraryCard(
                        context,
                        item,
                        colorScheme,
                        width: 160,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildDownloadsSection(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Downloads',
            trailing: TextButton(
              onPressed: () {},
              child: const Text('See All'),
            ),
          ),
          AppSpacing.heightXS,
          controller.downloads.isEmpty
              ? _buildEmptyLibrary(
                  context,
                  colorScheme,
                  'No downloads',
                  'Download content to watch offline.',
                )
              : SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.downloads.length,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    itemBuilder: (context, index) {
                      final item = controller.downloads[index];
                      return _buildLibraryCard(
                        context,
                        item,
                        colorScheme,
                        width: 140,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'History',
            trailing: TextButton(
              onPressed: () {},
              child: const Text('See All'),
            ),
          ),
          AppSpacing.heightXS,
          controller.history.isEmpty
              ? _buildEmptyLibrary(
                  context,
                  colorScheme,
                  'No history',
                  'Your playback history will appear here.',
                )
              : SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.history.length,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    itemBuilder: (context, index) {
                      final item = controller.history[index];
                      return _buildLibraryCard(
                        context,
                        item,
                        colorScheme,
                        width: 160,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildLibraryCard(
    BuildContext context,
    MediaItem item,
    ColorScheme colorScheme, {
    required double width,
  }) {
    final formattedPoster = ImageUrlFormatter.extractFromMediaItem(item);
    final rawPoster = (item.poster != null && item.poster!.trim().isNotEmpty)
        ? item.poster!.trim()
        : ((item.thumbnail != null && item.thumbnail!.trim().isNotEmpty)
            ? item.thumbnail!.trim()
            : item.backdrop?.trim());
    final poster = (formattedPoster != null && formattedPoster.isNotEmpty)
        ? formattedPoster
        : rawPoster;
    return GestureDetector(
      onTap: () => _openItem(item),
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: AppSpacing.md),
        child: AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AppRadius.medium,
                child: Container(
                  width: double.infinity,
                  height: width * 0.75,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  child: poster != null && poster.isNotEmpty
                      ? Image.network(
                          poster,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPosterPlaceholder(
                                context,
                                item,
                                colorScheme,
                              ),
                        )
                      : _buildPosterPlaceholder(context, item, colorScheme),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTypography.getCaption(
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subtitle != null) ...[
                      AppSpacing.heightXXS,
                      Text(
                        item.subtitle!,
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurfaceVariant,
                          scale: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPosterPlaceholder(
    BuildContext context,
    MediaItem item,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Icon(
        item.mediaType == MediaType.movie
            ? AppIcons.movies
            : item.mediaType == MediaType.series
            ? AppIcons.series
            : AppIcons.liveTv,
        size: 32.0,
        color: colorScheme.primary.withValues(alpha: 0.3),
      ),
    );
  }

  void _openItem(MediaItem item) {
    if (item.mediaType == MediaType.series) {
      Get.toNamed(
        AppRoutes.seriesDetails,
        arguments: {'item': item},
      );
    } else {
      Get.toNamed(
        AppRoutes.fullscreenPlayer,
        arguments: {
          'items': [item],
          'currentId': item.id,
        },
      );
    }
  }

  Widget _buildEmptyLibrary(
    BuildContext context,
    ColorScheme colorScheme,
    String title,
    String description,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Icon(
            AppIcons.empty,
            size: 40.0,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          AppSpacing.heightSM,
          Text(
            title,
            style: AppTypography.getTitle(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.heightXS,
          Text(
            description,
            style: AppTypography.getCaption(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
