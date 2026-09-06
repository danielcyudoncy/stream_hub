import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive_helper.dart';

import '../../../data/models/media_item.dart';
import '../controllers/favorites_controller.dart';
import '../controllers/live_tv_controller.dart';
import '../../free_live_tv/controllers/free_live_tv_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/channel_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/empty_library.dart';
import '../../../shared/widgets/tv_focusable.dart';

class FavoritesPage extends GetView<FavoritesController> {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Favorites',
      showBackButton: true,
      actions: [
        TvFocusable(
          scale: 1.0,
          borderRadius: BorderRadius.circular(8),
          child: PopupMenuButton<String>(
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
        ),
      ],
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
            onAction: () => Get.toNamed(AppRoutes.liveTV),
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
                  height: 165,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    itemCount: controller.recentlyFavorited.length,
                    itemBuilder: (context, index) {
                      final item = controller.recentlyFavorited[index];
                      return SizedBox(
                        width: 140,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            right: AppSpacing.md,
                          ),
                          child: ChannelCard(
                            channel: item,
                            onTap: () => _openChannel(item),
                            onFavorite: () => controller.toggleFavorite(item),
                            showFavoriteButton: true,
                          ),
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
                  crossAxisCount: ResponsiveHelper.isPhone(context) ? 3 : (ResponsiveHelper.isDesktop(context) ? 6 : 4),
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = controller.favoriteChannels[index];
                    return ChannelCard(
                      channel: item,
                      onTap: () => _openChannel(item),
                      onFavorite: () => controller.toggleFavorite(item),
                      showFavoriteButton: true,
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

  void _openChannel(MediaItem item) {
    final provider = item.providerType.displayName.toLowerCase();
    final isFreeLiveTv = provider.contains('freelivetv') ||
        provider.contains('free_live_tv') ||
        provider.contains('iptv-org') ||
        item.providerId.toLowerCase().contains('freelivetv') ||
        item.providerId.toLowerCase().contains('free_live_tv') ||
        item.id.startsWith('free_tv_');

    if (isFreeLiveTv) {
      if (Get.isRegistered<LiveTVController>()) {
        Get.find<LiveTVController>().stopInlinePlayer();
      }
      Get.toNamed(
        AppRoutes.freeLiveTV,
        arguments: {'channel': item},
      );
    } else {
      if (Get.isRegistered<FreeLiveTvController>()) {
        Get.find<FreeLiveTvController>().stopInlinePlayer();
      }
      Get.toNamed(
        AppRoutes.liveTV,
        arguments: {'channel': item},
      );
    }
  }
}
