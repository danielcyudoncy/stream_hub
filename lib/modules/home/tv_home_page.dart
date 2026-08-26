import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/premium_media_card.dart';
import 'home_controller.dart';
import 'widgets/home_content_rail.dart';
import 'widgets/home_live_channel_card.dart';
import 'widgets/home_skeleton_loader.dart';

class TvHomePage extends StatefulWidget {
  const TvHomePage({super.key});

  @override
  State<TvHomePage> createState() => _TvHomePageState();
}

class _TvHomePageState extends State<TvHomePage> {
  final HomeController controller = Get.find<HomeController>();
  MediaItem? _focusedItem;

  void _onItemFocus(MediaItem item, bool isFocused) {
    if (isFocused && _focusedItem?.id != item.id) {
      setState(() {
        _focusedItem = item;
      });
    }
  }

  void _openItem(MediaItem item) {
    if (item.mediaType == MediaType.series) {
      Get.toNamed(AppRoutes.seriesDetails, arguments: {'item': item});
    } else if (item.mediaType == MediaType.movie) {
      Get.toNamed(AppRoutes.movieDetails, arguments: item);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Home',
      showAppBar: false,
      body: Obx(() {
        if (controller.isLoading.value && !controller.hasContent) {
          return const HomeSkeletonLoader();
        }

        // Default to first item if none focused yet
        final backgroundItem = _focusedItem ?? (controller.movies.isNotEmpty ? controller.movies.first : null);
        final rawBackdrop = backgroundItem?.backdrop ?? backgroundItem?.poster;
        final backdrop = backgroundItem != null ? ImageUrlFormatter.format(rawBackdrop, item: backgroundItem) : null;

        return Stack(
          children: [
            // Cinematic Background Layer
            if (backdrop != null && backdrop.isNotEmpty)
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: Image.network(
                    backdrop,
                    key: ValueKey(backdrop),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) => const SizedBox.expand(),
                  ),
                ),
              ),

            // Gradient Overlays (Neon Glow + Darkness)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 0.7, 1.0],
                    colors: [
                      AppColors.darkBackground.withValues(alpha: 0.1),
                      AppColors.darkBackground.withValues(alpha: 0.6),
                      AppColors.darkBackground.withValues(alpha: 0.95),
                      AppColors.darkBackground,
                    ],
                  ),
                ),
              ),
            ),
            
            // Left to right gradient for readability if sidebar is transparent (optional)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, 0.5],
                    colors: [
                      AppColors.darkBackground.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Content Layer
            RefreshIndicator(
              onRefresh: controller.refresh,
              color: colorScheme.primary,
              child: CustomScrollView(
                slivers: [
                  // Spacer to let the background show through at the top
                  SliverToBoxAdapter(
                    child: SizedBox(height: MediaQuery.of(context).size.height * 0.35),
                  ),

                  // Metadata of Focused Item
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                      child: _buildFocusedMetadata(backgroundItem, colorScheme),
                    ),
                  ),

                  // Rows
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSpacing.heightXL,

                        if (controller.movies.isNotEmpty) ...[
                          HomeContentRail(
                            title: 'Trending Movies',
                            items: controller.movies,
                            onSeeAll: () => Get.toNamed(AppRoutes.movies),
                            itemBuilder: (context, item, index) {
                              return PremiumMediaCard(
                                item: item,
                                onTap: () => _openItem(item),
                                onFocusChange: (f) => _onItemFocus(item, f),
                              );
                            },
                          ),
                          AppSpacing.heightMD,
                        ],

                        if (controller.series.isNotEmpty) ...[
                          HomeContentRail(
                            title: 'Popular Series',
                            items: controller.series,
                            onSeeAll: () => Get.toNamed(AppRoutes.series),
                            itemBuilder: (context, item, index) {
                              return PremiumMediaCard(
                                item: item,
                                onTap: () => _openItem(item),
                                onFocusChange: (f) => _onItemFocus(item, f),
                              );
                            },
                          ),
                          AppSpacing.heightMD,
                        ],

                        if (controller.recentlyAdded.isNotEmpty) ...[
                          HomeContentRail(
                            title: 'Recently Added',
                            items: controller.recentlyAdded,
                            itemBuilder: (context, item, index) {
                              if (item.mediaType == MediaType.channel) {
                                return HomeLiveChannelCard(
                                  channel: item,
                                  onTap: () => _openItem(item),
                                );
                              }
                              return PremiumMediaCard(
                                item: item,
                                onTap: () => _openItem(item),
                                onFocusChange: (f) => _onItemFocus(item, f),
                              );
                            },
                          ),
                          AppSpacing.heightMD,
                        ],

                        AppSpacing.heightXXL,
                        AppSpacing.heightXXL,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildFocusedMetadata(MediaItem? item, ColorScheme colorScheme) {
    if (item == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            item.title,
            key: ValueKey(item.title),
            style: AppTypography.getDisplay(color: Colors.white).copyWith(
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        AppSpacing.heightSM,
        if (item.description != null && item.description!.isNotEmpty)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              item.description!,
              key: ValueKey(item.description),
              style: AppTypography.getBody(color: Colors.white70).copyWith(
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
