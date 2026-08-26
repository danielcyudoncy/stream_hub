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
import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/premium_media_card.dart';
import '../../../shared/widgets/tv_focusable.dart';
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
            // Background Image
            if (backdrop != null && backdrop.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 716.0,
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

            // Hero Gradients (Stitch Design)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 716.0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, 0.4, 1.0],
                    colors: [
                      AppColors.background,
                      AppColors.background.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 716.0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.0, 0.3, 1.0],
                    colors: [
                      AppColors.background,
                      AppColors.background.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Main Scrolling Content
            Positioned.fill(
              child: CustomScrollView(
                slivers: [
                  // Hero Content Area
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 550, // pushes content down, leaves room for -mt-16 row overlap
                      child: Padding(
                        padding: const EdgeInsets.only(left: 64.0, right: 64.0, bottom: 64.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (backgroundItem != null) _buildHeroContent(backgroundItem),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Rows (Overlapping the hero slightly)
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -64), // -mt-16 overlap hero
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (controller.movies.isNotEmpty) ...[
                            HomeContentRail(
                              title: 'Continue Watching', // Renamed for Stitch match
                              items: controller.movies,
                              onSeeAll: () => Get.toNamed(AppRoutes.movies),
                              itemBuilder: (context, item, index) {
                                return PremiumMediaCard(
                                  item: item,
                                  width: 320, // Wider for continue watching
                                  aspectRatio: 16 / 9,
                                  useGlassLabel: true,
                                  progress: 0.65, // Stubbed progress
                                  onTap: () => _openItem(item),
                                  onFocusChange: (f) => _onItemFocus(item, f),
                                );
                              },
                            ),
                            AppSpacing.heightXL,
                          ],

                          if (controller.series.isNotEmpty) ...[
                            HomeContentRail(
                              title: 'Recommended for You',
                              items: controller.series,
                              onSeeAll: () => Get.toNamed(AppRoutes.series),
                              itemBuilder: (context, item, index) {
                                return PremiumMediaCard(
                                  item: item,
                                  width: 200,
                                  aspectRatio: 2 / 3,
                                  onTap: () => _openItem(item),
                                  onFocusChange: (f) => _onItemFocus(item, f),
                                );
                              },
                            ),
                            AppSpacing.heightXL,
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
                                  width: 200,
                                  aspectRatio: 2 / 3,
                                  onTap: () => _openItem(item),
                                  onFocusChange: (f) => _onItemFocus(item, f),
                                );
                              },
                            ),
                            AppSpacing.heightXL,
                          ],

                          AppSpacing.heightXXL,
                        ],
                      ),
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

  Widget _buildHeroContent(MediaItem item) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges and Metadata
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'FEATURED',
                  style: AppTypography.getLabel(color: AppColors.onSecondaryContainer).copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              AppSpacing.widthMD,
              Text(
                '2024 • Action • 2h 15m', // Stubbing metadata since model might lack it
                style: AppTypography.getLabel(color: AppColors.textSecondary),
              ),
              if (item.rating != null && item.rating! > 0) ...[
                AppSpacing.widthMD,
                Icon(Icons.star, color: AppColors.primary, size: 16),
                AppSpacing.widthXXS,
                Text(
                  item.rating!.toStringAsFixed(1),
                  style: AppTypography.getLabel(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
          AppSpacing.heightMD,

          // Title
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              item.title,
              key: ValueKey(item.title),
              style: AppTypography.getDisplay(color: AppColors.textPrimary).copyWith(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
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
          AppSpacing.heightMD,

          // Description
          if (item.description != null && item.description!.isNotEmpty)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                item.description!,
                key: ValueKey(item.description),
                style: AppTypography.getBody(color: AppColors.textSecondary).copyWith(
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
          
          AppSpacing.heightXL,

          // Buttons
          Row(
            children: [
              TvFocusable(
                onTap: () => _openItem(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow, color: AppColors.onPrimaryContainer),
                      AppSpacing.widthSM,
                      Text(
                        'Watch Now',
                        style: AppTypography.getTitle(color: AppColors.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.widthLG,
              TvFocusable(
                onTap: () {},
                child: GlassPanel(
                  borderRadius: BorderRadius.circular(32),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.textPrimary),
                      AppSpacing.widthSM,
                      Text(
                        'More Info',
                        style: AppTypography.getTitle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
