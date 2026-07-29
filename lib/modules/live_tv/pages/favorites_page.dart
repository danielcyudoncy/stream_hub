import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/media_item.dart';
import '../controllers/favorites_controller.dart';
import '../../../shared/widgets/channel_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/empty_library.dart';

class FavoritesPage extends GetView<FavoritesController> {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => controller.setSort(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'alphabetical',
                child: Text('Alphabetical'),
              ),
              const PopupMenuItem(
                value: 'recentlyAdded',
                child: Text('Recently Added'),
              ),
              const PopupMenuItem(
                value: 'provider',
                child: Text('By Provider'),
              ),
              const PopupMenuItem(
                value: 'country',
                child: Text('By Country'),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (controller.favoriteChannels.isEmpty) {
          return EmptyLibrary(
            title: 'No Favorites',
            description:
                'Mark channels as favorites to see them here.',
            actionLabel: 'Browse Channels',
            onAction: () => Get.toNamed('/live-tv'),
          );
        }

        return CustomScrollView(
          slivers: [
            if (controller.recentlyFavorited.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: SectionHeader(
                    title: 'Recently Favorited',
                  ),
                ),
              ),
            if (controller.recentlyFavorited.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    itemCount: controller.recentlyFavorited.length,
                    itemBuilder: (context, index) {
                      final item = controller.recentlyFavorited[index];
                      return Padding(
                        padding: const EdgeInsets.only(
                          right: AppSpacing.md,
                        ),
                        child: ChannelCard(
                          channel: item,
                          showFavoriteButton: true,
                        ),
                      );
                    },
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: SectionHeader(
                  title: 'Favorite Channels',
                  subtitle:
                      '${controller.favoriteChannels.length} channels',
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
                    final item = controller.favoriteChannels[index];
                    return GestureDetector(
                      onTap: () => Get.toNamed(
                        '/channel-details',
                        parameters: {'channelId': item.id},
                      ),
                      child: ChannelCard(
                        channel: item,
                        showFavoriteButton: true,
                      ),
                    );
                  },
                  childCount: controller.favoriteChannels.length,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}