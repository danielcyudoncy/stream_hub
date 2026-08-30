import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/media/enums/media_type.dart';
import '../controllers/live_tv_library_controller.dart';
import '../../../core/utils/responsive_helper.dart';

import '../../../core/routes/app_routes.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/channel_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/empty_library.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../../../modules/movies/widgets/movie_card.dart';
import '../../../modules/series/widgets/series_card.dart';

class LibraryOverviewPage extends GetView<LiveTVLibraryController> {
  const LibraryOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Library',
      showNavigation: false,
      actions: [
        TvFocusable(
          scale: 1.0,
          borderRadius: BorderRadius.circular(8),
          child: PopupMenuButton<String>(
            onSelected: (value) => controller.setFilter(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('All'),
              ),
              const PopupMenuItem(
                value: 'channels',
                child: Text('Channels'),
              ),
              const PopupMenuItem(
                value: 'movies',
                child: Text('Movies'),
              ),
              const PopupMenuItem(
                value: 'series',
                child: Text('Series'),
              ),
              const PopupMenuItem(
                value: 'live',
                child: Text('Live TV'),
              ),
              const PopupMenuItem(
                value: 'favorites',
                child: Text('Favorites'),
              ),
              const PopupMenuItem(
                value: 'recent',
                child: Text('Recently Added'),
              ),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ),
      ],
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final items = controller.getFilteredItems();

        if (items.isEmpty) {
          return EmptyLibrary(
            title: 'No Content',
            description: 'No content matches the current filter.',
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: SectionHeader(
                  title: _getTitle(),
                  subtitle: '${items.length} items',
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
                    final item = items[index];
                    return _buildMediaCard(context, item);
                  },
                  childCount: items.length,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildMediaCard(BuildContext context, MediaItem item) {
    switch (item.mediaType) {
      case MediaType.channel:
        return ChannelCard(
          channel: item,
          onTap: () {
            Get.toNamed(
              AppRoutes.channelDetails,
              parameters: {'channelId': item.id},
            );
          },
          onFavorite: () => controller.toggleFavorite(item),
          showFavoriteButton: true,
        );
      case MediaType.movie:
        return MovieCard(
          item: item,
          onTap: () => Get.toNamed(
            AppRoutes.movieDetails,
            arguments: item,
          ),
          onToggleFavorite: () => controller.toggleFavorite(item),
        );
      case MediaType.series:
        return SeriesCard(
          item: item,
          onTap: () => Get.toNamed(
            AppRoutes.seriesDetails,
            arguments: {'item': item},
          ),
          onToggleFavorite: () => controller.toggleFavorite(item),
        );
      default:
        return ChannelCard(
          channel: item,
          onTap: () {
            if (item.mediaType == MediaType.channel) {
              Get.toNamed(
                AppRoutes.channelDetails,
                parameters: {'channelId': item.id},
              );
            }
          },
          onFavorite: () => controller.toggleFavorite(item),
          showFavoriteButton: true,
        );
    }
  }

  String _getTitle() {
    switch (controller.selectedFilter.value) {
      case 'channels':
        return 'Channels';
      case 'movies':
        return 'Movies';
      case 'series':
        return 'Series';
      case 'live':
        return 'Live TV';
      case 'favorites':
        return 'Favorites';
      case 'recent':
        return 'Recently Added';
      default:
        return 'All Items';
    }
  }
}
