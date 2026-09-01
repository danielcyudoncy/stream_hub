import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/core/utils/date_formatter.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/core/utils/responsive_helper.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/modules/epg/controllers/guide_controller.dart';
import 'package:stream_hub/modules/epg/models/epg_channel.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/modules/epg/widgets/guide_grid.dart';
import 'package:stream_hub/modules/epg/widgets/mini_guide.dart';
import 'package:stream_hub/modules/epg/widgets/channel_column.dart';
import 'package:stream_hub/modules/live_tv/controllers/live_tv_controller.dart';
import 'package:stream_hub/modules/live_tv/widgets/live_tv_channel_card.dart';
import 'package:stream_hub/modules/live_tv/widgets/live_tv_embedded_player.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/empty_view.dart';
import 'package:stream_hub/shared/loading/loading_indicator.dart';
import 'package:stream_hub/shared/widgets/error_view.dart';
import 'package:stream_hub/shared/widgets/provider_selector_button.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

class TVGuidePage extends GetView<GuideController> {
  const TVGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isTV = ResponsiveHelper.isTV(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    // If on phone/small screen, show the mobile layout
    if (!isTV && !isDesktop) {
      return AppScaffold(
        title: 'TV Guide',
        actions: [
          TvFocusable(
            onTap: controller.refreshGuide,
            scale: 1.0,
            borderRadius: BorderRadius.circular(8),
            child: const IconButton(
              icon: Icon(Icons.refresh),
              onPressed: null,
            ),
          ),
          TvFocusable(
            onTap: () => Get.toNamed(AppRoutes.guideSearch),
            scale: 1.0,
            borderRadius: BorderRadius.circular(8),
            child: const IconButton(
              icon: Icon(Icons.search),
              onPressed: null,
            ),
          ),
        ],
        body: Column(
          children: [
            _buildTimeNavigation(context),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: LoadingIndicator());
                }
                if (controller.error.value.isNotEmpty) {
                  return ErrorView(
                    message: controller.error.value,
                    onRetry: controller.loadGuide,
                  );
                }
                if (controller.channels.isEmpty) {
                  return const EmptyView(
                    title: 'No Guide Available',
                    description:
                        'No EPG guide data is available at the moment. Try refreshing or adding an XMLTV source.',
                  );
                }
                return _buildMobileLayout(context);
              }),
            ),
          ],
        ),
      );
    }

    // TV Layout (Cinematic Neon)
    final liveCtrl =
        Get.isRegistered<LiveTVController>() ? Get.find<LiveTVController>() : null;

    return Obx(() {
      if (liveCtrl != null && liveCtrl.isFullscreenMode.value) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            liveCtrl.exitFullscreen();
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SizedBox.expand(
              child: LiveTvEmbeddedPlayer(
                key: const ValueKey('tv_guide_fullscreen_player'),
                controller: liveCtrl,
                isFullscreen: true,
              ),
            ),
          ),
        );
      }

      return AppScaffold(
        title: 'TV Guide',
        showAppBar: false,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Showcase: Channel Info on Left, Large 16:9 Live Player on Right
            _buildTopShowcase(context),

            // 2. Full-Width Category Rail Below the Player
            _buildCategoryBar(context),

            AppSpacing.heightXS,

            // 3. Full Guide / Channel Catalog Grid Below
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: _buildTVLayout(context),
              ),
            ),

            // 4. TV Remote D-Pad Navigation Legend Bar
            _buildRemoteLegendBar(),
          ],
        ),
      );
    });
  }

  Widget _buildTopShowcase(BuildContext context) {
    final liveCtrl =
        Get.isRegistered<LiveTVController>() ? Get.find<LiveTVController>() : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Pane: Header and Active Channel Information Showcase
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Top Action Row: Title, Today Badge, View Mode Switch, Search, Refresh
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        children: [
                          Text(
                            'Live TV Guide',
                            style: AppTypography.getDisplay(color: AppColors.primary).copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 26,
                              shadows: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 8.0,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Text(
                              'Live',
                              style: AppTypography.getLabel(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dual View Mode Toggle Button (Grid ↔ Timeline)
                    if (liveCtrl != null)
                      Obx(() {
                        final isTimeline = liveCtrl.selectedView.value == 'timeline';
                        return TvFocusable(
                          onTap: () => liveCtrl.setView(isTimeline ? 'grid' : 'timeline'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isTimeline
                                    ? AppColors.primary
                                    : Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isTimeline ? Icons.grid_view_rounded : Icons.view_timeline_outlined,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isTimeline ? 'Grid View' : 'Timeline EPG',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    AppSpacing.widthSM,
                    TvFocusable(
                      onTap: () => Get.toNamed(AppRoutes.guideSearch),
                      scale: 1.15,
                      borderRadius: BorderRadius.circular(24),
                      child: IconButton(
                        icon: const Icon(Icons.search),
                        color: AppColors.textSecondary,
                        focusColor: AppColors.primaryContainer.withValues(alpha: 0.3),
                        onPressed: () => Get.toNamed(AppRoutes.guideSearch),
                      ),
                    ),
                    AppSpacing.widthSM,
                    TvFocusable(
                      onTap: () => controller.refreshGuide(),
                      scale: 1.15,
                      borderRadius: BorderRadius.circular(24),
                      child: IconButton(
                        icon: const Icon(Icons.refresh),
                        color: AppColors.textSecondary,
                        focusColor: AppColors.primaryContainer.withValues(alpha: 0.3),
                        onPressed: () => controller.refreshGuide(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 2. Active Playing / Focused Channel Showcase Info with Live Progress
                if (liveCtrl != null)
                  Obx(() {
                    final active = liveCtrl.activePlayingChannel.value ??
                        liveCtrl.featuredChannel.value ??
                        (liveCtrl.channels.isNotEmpty ? liveCtrl.channels.first : null);

                    if (active == null) {
                      return const SizedBox(height: 100);
                    }

                    final categoryName = active.metadata['category_name']?.toString() ??
                        (active.genres.isNotEmpty ? active.genres.first : 'Live TV');
                    final resolution = active.metadata['resolution']?.toString() ?? 'HD';
                    final description =
                        active.description ?? active.subtitle ?? 'Live Broadcast';

                    final now = DateTime.now();
                    final currentProgram = controller.programs.firstWhereOrNull(
                      (p) => p.channelId == active.id && p.isCurrentlyPlaying,
                    );
                    final nextProgram = controller.programs.firstWhereOrNull(
                      (p) => p.channelId == active.id && p.startTime.isAfter(now),
                    );
                    final double progPercent = currentProgram != null
                        ? (now.difference(currentProgram.startTime).inSeconds /
                                (currentProgram.endTime.difference(currentProgram.startTime).inSeconds > 0
                                    ? currentProgram.endTime.difference(currentProgram.startTime).inSeconds
                                    : 1))
                            .clamp(0.0, 1.0)
                        : 0.35;

                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Channel Logo or Avatar
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Center(
                                  child: (active.poster != null &&
                                          active.poster!.isNotEmpty)
                                      ? Image.network(
                                          active.poster!,
                                          width: 38,
                                          height: 38,
                                          errorBuilder: (_, _, _) =>
                                              const Icon(Icons.tv, color: Colors.white),
                                        )
                                      : Text(
                                          active.title.isNotEmpty
                                              ? active.title
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                              : 'TV',
                                          style: AppTypography.getTitle(
                                            color: AppColors.primary,
                                          ),
                                        ),
                                ),
                              ),
                              AppSpacing.widthMD,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            active.title,
                                            style: AppTypography.getHeadline(
                                              color: Colors.white,
                                            ).copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryContainer
                                                .withValues(alpha: 0.4),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                          child: Text(
                                            resolution,
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      categoryName,
                                      style: AppTypography.getLabel(
                                        color: AppColors.textSecondary,
                                      ).copyWith(fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Live Progress Bar & Program details
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  currentProgram?.title ?? description,
                                  style: AppTypography.getBody(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ).copyWith(
                                    fontSize: 13,
                                    fontWeight: currentProgram != null ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (currentProgram != null)
                                Text(
                                  DateFormatter.formatTimeRange(currentProgram.startTime, currentProgram.endTime),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progPercent,
                              minHeight: 3.0,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          if (nextProgram != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Up Next: ${nextProgram.title} (${DateFormat('HH:mm').format(nextProgram.startTime)})',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          AppSpacing.widthLG,

          // Right Pane: Prominent 16:9 Live Mini-Player (Width: 440dp, Height: 248dp on TV/large screen)
          if (liveCtrl != null)
            Container(
              width: 440, // Larger 16:9 TV Mini Player
              height: 248,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LiveTvEmbeddedPlayer(
                  key: const ValueKey('tv_guide_inline_player'),
                  controller: liveCtrl,
                  isFullscreen: false,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(BuildContext context) {
    final liveCtrl =
        Get.isRegistered<LiveTVController>() ? Get.find<LiveTVController>() : null;
    final providerRepo =
        Get.isRegistered<ProviderRepository>() ? Get.find<ProviderRepository>() : null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs,
      ),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            if (liveCtrl != null || providerRepo != null)
              Obx(() {
                final currentProvider = liveCtrl?.selectedProvider.value ??
                    providerRepo?.activeProviderId.value ??
                    '';
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: ProviderSelectorButton(
                    selectedProviderId: currentProvider,
                    onSelectProvider: (newProviderId) {
                      liveCtrl?.setProvider(newProviderId);
                      controller.setProvider(newProviderId);
                      providerRepo?.setActiveProviderId(newProviderId);
                    },
                    sheetTitle: 'TV Guide Provider',
                    isCompact: true,
                  ),
                );
              }),
            Expanded(
              child: Obx(() {
                final categories = liveCtrl != null && liveCtrl.categories.isNotEmpty
                    ? liveCtrl.categories
                    : (controller.categories.isNotEmpty
                        ? controller.categories
                        : ['All Channels']);

                final selectedCat =
                    liveCtrl?.selectedCategory.value ?? controller.selectedCategory.value;

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => AppSpacing.widthSM,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected =
                        (selectedCat.isEmpty && index == 0) || selectedCat == cat;
                    return _buildFilterPill(cat, isSelected, () {
                      liveCtrl?.setCategory(cat);
                      controller.setCategory(cat);
                    });
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, bool isSelected, VoidCallback onTap) {
    return TvFocusable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryContainer
              : AppColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.getLabel(
              color:
                  isSelected ? AppColors.onPrimaryContainer : AppColors.textSecondary,
            ).copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTVLayout(BuildContext context) {
    final liveCtrl =
        Get.isRegistered<LiveTVController>() ? Get.find<LiveTVController>() : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Obx(() {
            if (liveCtrl != null && liveCtrl.isLoading.value) {
              return const Center(child: LoadingIndicator());
            }

            // TV Live Channel Catalog Grid based on selected category & filters
            final List<MediaItem> channels =
                liveCtrl != null ? liveCtrl.filteredChannels.toList() : <MediaItem>[];

            if (channels.isNotEmpty) {
              if (liveCtrl?.selectedView.value == 'timeline') {
                return _buildTimelineEpgView(channels, liveCtrl!);
              }
              return _buildTvChannelCatalogGrid(channels, liveCtrl!);
            }

            if (liveCtrl != null && liveCtrl.channels.isEmpty) {
              return const EmptyView(
                title: 'No Live Channels Available',
                description: 'Connect an IPTV provider to start watching Live TV.',
              );
            }

            if (channels.isEmpty &&
                liveCtrl != null &&
                liveCtrl.selectedCategory.value != 'All Channels') {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tv_off, size: 48, color: AppColors.textSecondary),
                    AppSpacing.heightMD,
                    Text(
                      'No channels in "${liveCtrl.selectedCategory.value}"',
                      style: AppTypography.getHeadline(color: Colors.white),
                    ),
                  ],
                ),
              );
            }

            return const EmptyView(
              title: 'No Live Channels Available',
              description: 'Connect an IPTV provider to start watching Live TV.',
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTvChannelCatalogGrid(
    List<MediaItem> channels,
    LiveTVController liveCtrl,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 16 / 10,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final item = channels[index];
        return Obx(() {
          final isPlaying =
              liveCtrl.activePlayingChannel.value?.id == item.id;
          return LiveTvChannelCard(
            channel: item,
            isPlaying: isPlaying,
            onTap: () => liveCtrl.openChannel(item),
            onFavorite: () => liveCtrl.toggleFavorite(item),
          );
        });
      },
    );
  }

  Widget _buildTimelineEpgView(
    List<MediaItem> channels,
    LiveTVController liveCtrl,
  ) {
    final List<EPGChannel> epgChannels = channels.map((c) => EPGChannel(
      id: c.id,
      providerId: c.providerId,
      providerType: c.providerType,
      title: c.title,
      mediaType: c.mediaType,
      poster: c.poster,
      thumbnail: c.thumbnail,
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
      number: c.metadata['number']?.toString(),
    )).toList();

    // Group available programs by channelId in a single O(N) pass
    final Map<String, List<EPGProgram>> channelProgramsMap = {};
    for (final p in controller.programs) {
      final chId = p.channelId;
      if (chId != null &&
          chId.isNotEmpty &&
          p.endTime.difference(p.startTime).inMinutes >= 15) {
        (channelProgramsMap[chId] ??= []).add(p);
      }
    }

    return GuideGrid(
      channels: epgChannels,
      programs: controller.programs,
      channelProgramsMap: channelProgramsMap,
      activePlayingChannelId: liveCtrl.activePlayingChannel.value?.id,
      onChannelTap: (epgChannel) {
        final match = channels.firstWhereOrNull((c) => c.id == epgChannel.id);
        if (match != null) liveCtrl.openChannel(match);
      },
      onProgramTap: (prog) {
        final match = channels.firstWhereOrNull((c) => c.id == prog.channelId);
        if (match != null) liveCtrl.openChannel(match);
      },
    );
  }

  Widget _buildRemoteLegendBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem(Icons.play_circle_fill, 'OK: Play Fullscreen'),
          AppSpacing.widthLG,
          _legendItem(Icons.touch_app, 'Long-press OK: Channel Info'),
          AppSpacing.widthLG,
          _legendItem(Icons.swap_horiz, '◄ / ►: Categories & Hours'),
          AppSpacing.widthLG,
          _legendItem(Icons.grid_view, 'View: Toggle Grid / Timeline EPG'),
        ],
      ),
    );
  }

  Widget _legendItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // --- Mobile Layout Helpers (Unchanged) ---
  Widget _buildTimeNavigation(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _navButton(
              context,
              'Now',
              () => controller.setTimelineWindowHours(6),
            ),
            _navButton(context, 'Morning', controller.scrollToMorning),
            _navButton(context, 'Afternoon', controller.scrollToAfternoon),
            _navButton(context, 'Evening', controller.scrollToEvening),
            _navButton(context, 'Tomorrow', controller.scrollToTomorrow),
          ],
        ),
      ),
    );
  }

  Widget _navButton(BuildContext context, String label, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        MiniGuide(
          programs: controller.filteredPrograms.take(5).toList(),
          onViewAll: () {},
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: controller.channels.length,
            itemBuilder: (context, index) {
              final channel = controller.channels[index];
              final channelPrograms = controller.filteredPrograms
                  .where((p) => p.channelId == channel.id)
                  .toList();
              return ChannelColumn(
                channel: channel,
                currentProgram: channelPrograms.firstWhereOrNull(
                  (p) => p.isCurrentlyPlaying,
                ),
                nextProgram: channelPrograms.firstWhereOrNull(
                  (p) => p.startTime.isAfter(DateTime.now()),
                ),
                onTap: () {},
              );
            },
          ),
        ),
      ],
    );
  }
}

