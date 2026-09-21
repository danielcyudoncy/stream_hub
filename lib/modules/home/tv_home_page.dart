import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/media/repositories/playback_repository.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/tv_navigation_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/premium_media_card.dart';
import '../../../shared/widgets/provider_selector_button.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../free_live_tv/controllers/free_live_tv_controller.dart';
import '../live_tv/controllers/live_tv_controller.dart';
import 'home_controller.dart';
import '../../../core/streaming/vod/xtream_vod_info_service.dart';
import '../../../shared/widgets/cached_home_image.dart';
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
  String? _resolvedBackdropUrl;
  String? _lastResolvedItemId;

  @override
  void initState() {
    super.initState();
    // Home rails are conditionally built (e.g. "Continue Watching" only when
    // there is watch history), so their widget order — and therefore their
    // auto-derived region order in TvNavigationService — can flip between
    // builds. Pinning the canonical order here makes UP/DOWN inter-rail
    // navigation deterministic regardless of which rails are present.
    if (Get.isRegistered<TvNavigationService>()) {
      Get.find<TvNavigationService>().registerRailOrder(const [
        'rail_continue_watching',
        'rail_live_tv_quick_picks',
        'rail_trending_movies',
        'rail_popular_series',
        'rail_recently_added',
      ]);
    }
  }

  void _onItemFocus(MediaItem item, bool isFocused) {
    if (isFocused && _focusedItem?.id != item.id) {
      setState(() {
        _focusedItem = item;
      });
    }
  }

  void _resolveBackdrop(MediaItem? item) {
    if (item == null) {
      if (_lastResolvedItemId != null) {
        _resolvedBackdropUrl = null;
        _lastResolvedItemId = null;
      }
      return;
    }
    if (_lastResolvedItemId == item.id) return;
    _lastResolvedItemId = item.id;

    final direct = item.resolvedBackdropUrl;
    _resolvedBackdropUrl = direct;

    if ((item.mediaType == MediaType.movie || item.mediaType == MediaType.series) &&
        Get.isRegistered<XtreamVodInfoService>()) {
      final vodService = Get.find<XtreamVodInfoService>();
      final cached = vodService.getCachedBackdrop(item);
      if (cached != null && cached.isNotEmpty) {
        _resolvedBackdropUrl = cached;
      } else {
        vodService.fetchForMediaItem(item).then((info) {
          if (!mounted || _lastResolvedItemId != item.id) return;
          final bd = (info?.backdrop != null && info!.backdrop!.trim().isNotEmpty)
              ? info.backdrop!.trim()
              : null;
          if (bd != null && bd.isNotEmpty) {
            setState(() {
              _resolvedBackdropUrl = bd;
            });
          }
        }).catchError((_) {});
      }
    }
  }

  Future<void> _openItem(MediaItem item) async {
    if (item.mediaType == MediaType.series) {
      Get.toNamed(AppRoutes.seriesDetails, arguments: {'item': item});
    } else if (item.mediaType == MediaType.movie) {
      Get.toNamed(AppRoutes.movieDetails, arguments: item);
    } else if (item.mediaType == MediaType.channel) {
      final provider = item.providerType.displayName.toLowerCase();
      final isFreeLiveTv = provider.contains('freelivetv') ||
          provider.contains('free_live_tv') ||
          provider.contains('iptv-org') ||
          item.providerId.toLowerCase().contains('freelivetv') ||
          item.providerId.toLowerCase().contains('free_live_tv') ||
          item.providerId.toLowerCase().contains('portal5458') ||
          item.id.startsWith('free_tv_') ||
          item.id.toLowerCase().contains('portal5458') ||
          (item.metadata['source']?.toString().toLowerCase().contains('portal5458') ?? false) ||
          (item.metadata['streamUrl']?.toString().toLowerCase().contains('portal5458') ?? false);

      if (isFreeLiveTv) {
        if (Get.isRegistered<LiveTVController>()) {
          Get.find<LiveTVController>().stopInlinePlayer();
        }
        Get.toNamed(AppRoutes.freeLiveTV, arguments: {'channel': item});
      } else {
        if (Get.isRegistered<FreeLiveTvController>()) {
          Get.find<FreeLiveTvController>().stopInlinePlayer();
        }
        Get.toNamed(AppRoutes.liveTV, arguments: {'channel': item});
      }
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

        if (!controller.hasContent) {
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

        _resolveBackdrop(backgroundItem);

        final backdrop = _resolvedBackdropUrl ?? backgroundItem?.resolvedBackdropUrl;
        final screenHeight = MediaQuery.of(context).size.height;
        final spotlightHeight = (screenHeight * 0.82).clamp(640.0, 800.0);
        final heroHeaderHeight = (screenHeight * 0.58).clamp(480.0, 560.0);

        return Stack(
          children: [
            // 1. Background Cinematic Spotlight Image
            if (backdrop != null && backdrop.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: spotlightHeight,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ...previousChildren,
                        ?currentChild,
                      ],
                    );
                  },
                  child: SizedBox.expand(
                    key: ValueKey(backdrop),
                    child: CachedHomeImage(
                      imageUrl: backdrop,
                      fit: BoxFit.cover,
                      alignment: Alignment.topRight,
                      errorBuilder: (_, _) => const SizedBox.expand(),
                    ),
                  ),
                ),
              ),

            // 2. Rich Multi-Layer Gradient Overlays (Vignette + Readability)
            // Layer A: Left-to-right gradient ensuring perfect readability of text/buttons on the left,
            // while leaving the right 40% crisp and clear.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: spotlightHeight,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [0.0, 0.38, 0.58, 0.82, 1.0],
                    colors: [
                      AppColors.background,
                      Color(0xF50B0E14),
                      Color(0x750B0E14),
                      Color(0x100B0E14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Layer B: Bottom-to-top gradient blending seamlessly into the content rails.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: spotlightHeight,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: [0.0, 0.22, 0.55, 1.0],
                    colors: [
                      AppColors.background,
                      Color(0xD00B0E14),
                      Color(0x200B0E14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Layer C: Subtle top shadow for status / header actions.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120.0,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 1.0],
                    colors: [
                      Color(0x99000000),
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
                      height: heroHeaderHeight,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 56.0,
                          right: 56.0,
                          bottom: 36.0,
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
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
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
                              cardWidth: 160.0,
                              cardHeight: 125.0,
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
                          ] else if (controller.channelsState.value == SectionLoadState.loading || controller.isLoading.value) ...[
                            _buildLiveTvSkeletonRail(context),
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
                                  width: 155,
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
                                  width: 155,
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
                                  width: 155,
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
                  controller.hasProviders.value
                      ? 'No media content found in your connected providers. Manage or refresh your sources to start watching.'
                      : 'Connect your first IPTV or media source to start discovering Live TV, Movies, Series, and more.',
                  textAlign: TextAlign.center,
                  style: AppTypography.getBody(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ).copyWith(fontSize: 18),
                ),
                AppSpacing.heightXL,
                TvFocusable(
                  autofocus: ResponsiveHelper.isTvLayout(context),
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
                        Icon(
                          controller.hasProviders.value
                              ? AppIcons.settings
                              : AppIcons.add,
                          color: Colors.white,
                          size: 22,
                        ),
                        AppSpacing.widthSM,
                        Text(
                          controller.hasProviders.value
                              ? 'Manage Media Sources'
                              : 'Add Media Source',
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

    final textWidth = (MediaQuery.of(context).size.width * 0.52).clamp(420.0, 780.0);
    return SizedBox(
      width: textWidth,
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
                autofocus: ResponsiveHelper.isTvLayout(context),
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

  Widget _buildLiveTvSkeletonRail(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          child: Container(
            width: 180,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        AppSpacing.heightSM,
        SizedBox(
          height: 125.0,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            separatorBuilder: (context, index) => AppSpacing.widthMD,
            itemBuilder: (context, index) => Container(
              width: 160.0,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
