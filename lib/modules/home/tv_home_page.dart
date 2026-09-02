import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/media/repositories/playback_repository.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/premium_media_card.dart';
import '../../../shared/widgets/provider_selector_button.dart';
import '../../../shared/widgets/tv_focusable.dart';
import 'home_controller.dart';
import 'widgets/home_content_rail.dart';
import 'widgets/home_continue_watching_card.dart';
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

  Future<void> _openItem(MediaItem item) async {
    if (item.mediaType == MediaType.series) {
      Get.toNamed(AppRoutes.seriesDetails, arguments: {'item': item});
    } else if (item.mediaType == MediaType.movie) {
      Get.toNamed(AppRoutes.movieDetails, arguments: item);
    } else if (item.mediaType == MediaType.channel) {
      Get.toNamed(AppRoutes.liveTV, arguments: {'channel': item});
    } else {
      Duration? startPosition;
      if (Get.isRegistered<PlaybackRepository>()) {
        try {
          final session = await Get.find<PlaybackRepository>().getWatchSession(
            item.id,
          );
          if (session != null && session.resumePosition > Duration.zero) {
            startPosition = session.resumePosition;
          }
        } catch (_) {}
      }
      if (startPosition == null) {
        final posMs =
            item.metadata['position'] ?? item.metadata['watchProgress'];
        if (posMs is num && posMs > 1000) {
          startPosition = Duration(milliseconds: posMs.toInt());
        }
      }
      Get.toNamed(
        AppRoutes.fullscreenPlayer,
        arguments: {
          'items': [item],
          'currentId': item.id,
          'resumePosition': startPosition,
        },
      );
    }
  }

  void _openDetails(MediaItem item) {
    if (item.mediaType == MediaType.series) {
      Get.toNamed(AppRoutes.seriesDetails, arguments: {'item': item});
    } else if (item.mediaType == MediaType.movie) {
      Get.toNamed(AppRoutes.movieDetails, arguments: item);
    } else if (item.mediaType == MediaType.channel) {
      Get.toNamed(AppRoutes.liveTV, arguments: {'channel': item});
    } else {
      _openItem(item);
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

        if (!controller.hasProviders.value && !controller.hasContent) {
          return _buildTVWelcomeView(context);
        }

        // Spotlight background item priority:
        // 1. Current focused item from D-pad
        // 2. First hero item
        // 3. First continue watching item
        // 4. First movie/series
        final backgroundItem =
            _focusedItem ??
            (controller.featuredHeroItems.isNotEmpty
                ? controller.featuredHeroItems.first
                : (controller.continueWatching.isNotEmpty
                      ? controller.continueWatching.first
                      : (controller.movies.isNotEmpty
                            ? controller.movies.first
                            : (controller.series.isNotEmpty
                                  ? controller.series.first
                                  : null))));

        final rawBackdrop = backgroundItem?.backdrop ?? backgroundItem?.poster;
        final backdrop = backgroundItem != null
            ? ImageUrlFormatter.format(rawBackdrop, item: backgroundItem)
            : null;

        return Stack(
          children: [
            // 1. Background Cinematic Spotlight Image
            if (backdrop != null && backdrop.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 760.0,
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

            // 2. Rich Multi-Layer Gradient Overlays (Vignette + Readability)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 760.0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, 0.45, 1.0],
                    colors: [
                      AppColors.background,
                      AppColors.background.withValues(alpha: 0.85),
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
              height: 760.0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.0, 0.35, 1.0],
                    colors: [
                      AppColors.background,
                      AppColors.background.withValues(alpha: 0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // 3. Main Scrolling Content (Hero + Content Rails)
            Positioned.fill(
              child: CustomScrollView(
                slivers: [
                  // Hero Spotlight Header
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 560,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 64.0,
                          right: 64.0,
                          bottom: 48.0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (backgroundItem != null)
                              _buildHeroContent(backgroundItem),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Rails Section
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Continue Watching (Real session progress)
                          if (controller.continueWatching.isNotEmpty) ...[
                            HomeContentRail(
                              title: 'Continue Watching',
                              items: controller.continueWatching,
                              onSeeAll: () => Get.toNamed(AppRoutes.movies),
                              itemBuilder: (context, item, index) {
                                return HomeContinueWatchingCard(
                                  item: item,
                                  onTap: () => _openItem(item),
                                  onFocusChange: (f) => _onItemFocus(item, f),
                                );
                              },
                            ),
                            AppSpacing.heightXL,
                          ],

                          // 2. Live TV Quick Picks
                          if (controller.liveChannels.isNotEmpty) ...[
                            HomeContentRail(
                              title: 'Live TV Quick Picks',
                              items: controller.liveChannels.take(15).toList(),
                              onSeeAll: () => Get.toNamed(AppRoutes.liveTV),
                              itemBuilder: (context, item, index) {
                                return HomeLiveChannelCard(
                                  channel: item,
                                  onTap: () => _openItem(item),
                                  onFocusChange: (f) => _onItemFocus(item, f),
                                );
                              },
                            ),
                            AppSpacing.heightXL,
                          ],

                          // 3. Featured Movies
                          if (controller.movies.isNotEmpty) ...[
                            HomeContentRail(
                              title: 'Trending Movies',
                              items: controller.movies.take(20).toList(),
                              onSeeAll: () => Get.toNamed(AppRoutes.movies),
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

                          // 4. Popular Series
                          if (controller.series.isNotEmpty) ...[
                            HomeContentRail(
                              title: 'Popular Series',
                              items: controller.series.take(20).toList(),
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

                          // 5. Recently Added
                          if (controller.recentlyAdded.isNotEmpty) ...[
                            HomeContentRail(
                              title: 'Recently Added',
                              items: controller.recentlyAdded.take(20).toList(),
                              itemBuilder: (context, item, index) {
                                if (item.mediaType == MediaType.channel) {
                                  return HomeLiveChannelCard(
                                    channel: item,
                                    onTap: () => _openItem(item),
                                    onFocusChange: (f) => _onItemFocus(item, f),
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
            // 4. Top-Right Header Actions (Provider Switcher & Search)
            Positioned(
              top: 32.0,
              right: 48.0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(() {
                    return ProviderSelectorButton(
                      selectedProviderId: controller.selectedProviderId.value,
                      onSelectProvider: controller.setSelectedProvider,
                      isCompact: true,
                    );
                  }),
                  AppSpacing.widthSM,
                  TvFocusable(
                    onTap: () => Get.toNamed(AppRoutes.search),
                    borderRadius: AppRadius.pill,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(
                        AppIcons.search,
                        color: Colors.white,
                        size: 20.0,
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

  Widget _buildTVWelcomeView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: AppColors.primaryGradient,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: const Icon(
                    AppIcons.play,
                    color: Colors.white,
                    size: 48.0,
                  ),
                ),
                AppSpacing.heightLG,
                Text(
                  'Welcome to StreamHub Pro',
                  textAlign: TextAlign.center,
                  style: AppTypography.getDisplay(
                    color: colorScheme.onSurface,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
                AppSpacing.heightSM,
                Text(
                  'Connect your first IPTV or media source to start '
                  'discovering Live TV, Movies, Series, and more.',
                  textAlign: TextAlign.center,
                  style: AppTypography.getBody(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ).copyWith(fontSize: 18),
                ),
                AppSpacing.heightXL,
                TvFocusable(
                  autofocus: PlatformHelper.supportsDPadNavigation,
                  onTap: () => Get.toNamed(AppRoutes.providerManager),
                  borderRadius: AppRadius.pill,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.primaryGradient,
                      ),
                      borderRadius: AppRadius.pill,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(AppIcons.add, color: Colors.white, size: 22),
                        AppSpacing.widthSM,
                        Text(
                          'Add Media Source',
                          style: AppTypography.getTitle(
                            color: Colors.white,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroContent(MediaItem item) {
    final typeLabel = item.mediaType == MediaType.series
        ? 'SERIES'
        : (item.mediaType == MediaType.channel ? 'LIVE TV' : 'MOVIE');

    final year = item.resolvedYear;
    final resolution = item.is4k
        ? '4K UHD'
        : (item.isFhd ? 'FHD' : (item.isHd ? 'HD' : null));

    final rating = item.formattedRating;
    final genre = item.resolvedGenre;

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.58,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badges and Metadata Row
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Content Type Tag
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  typeLabel,
                  style: AppTypography.getLabel(
                    color: Colors.white,
                  ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
              ),

              // Rating Badge
              if (rating != null && rating.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 14.0,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        rating,
                        style: AppTypography.getLabel(
                          color: Colors.amber,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

              // Year
              if (year != null && year.isNotEmpty)
                Text(
                  year,
                  style: AppTypography.getLabel(
                    color: AppColors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),

              // Resolution
              if (resolution != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    resolution,
                    style: AppTypography.getCaption(
                      color: Colors.white70,
                    ).copyWith(fontWeight: FontWeight.w700, fontSize: 10),
                  ),
                ),

              // Genre
              if (genre != null && genre.isNotEmpty)
                Text(
                  '•  $genre',
                  style: AppTypography.getLabel(color: AppColors.textSecondary),
                ),
            ],
          ),
          AppSpacing.heightSM,

          // Title
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              item.title,
              key: ValueKey(item.title),
              style: AppTypography.getDisplay(color: AppColors.textPrimary)
                  .copyWith(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.9),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppSpacing.heightSM,

          // Description / Synopsis
          if (item.description != null && item.description!.isNotEmpty)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                item.description!,
                key: ValueKey(item.description),
                style: AppTypography.getBody(color: AppColors.textSecondary)
                    .copyWith(
                      height: 1.4,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.8),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          AppSpacing.heightLG,

          // Action Buttons
          Row(
            children: [
              // Watch Now / Resume Button
              TvFocusable(
                autofocus: PlatformHelper.supportsDPadNavigation,
                onTap: () => _openItem(item),
                borderRadius: AppRadius.pill,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.primaryGradient,
                    ),
                    borderRadius: AppRadius.pill,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(AppIcons.play, color: Colors.white, size: 22),
                      AppSpacing.widthSM,
                      Text(
                        'Watch Now',
                        style: AppTypography.getTitle(
                          color: Colors.white,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.widthMD,

              // More Info / Details Button
              TvFocusable(
                onTap: () => _openDetails(item),
                borderRadius: AppRadius.pill,
                child: GlassPanel(
                  borderRadius: AppRadius.pill,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                      AppSpacing.widthSM,
                      Text(
                        'More Info',
                        style: AppTypography.getTitle(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.widthMD,

              // Favorite Toggle
              Obx(() {
                final isFav = controller.isItemFavorite(item.id);
                return TvFocusable(
                  onTap: () => controller.toggleFavorite(item),
                  borderRadius: AppRadius.pill,
                  child: GlassPanel(
                    borderRadius: AppRadius.pill,
                    padding: const EdgeInsets.all(14),
                    child: Icon(
                      isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFav ? AppColors.darkError : Colors.white,
                      size: 20,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
