import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/core/utils/responsive_helper.dart';
import 'package:stream_hub/modules/epg/controllers/guide_controller.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/modules/epg/widgets/guide_grid.dart';
import 'package:stream_hub/modules/epg/widgets/mini_guide.dart';
import 'package:stream_hub/modules/epg/widgets/channel_column.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/empty_view.dart';
import 'package:stream_hub/shared/loading/loading_indicator.dart';
import 'package:stream_hub/shared/widgets/error_view.dart';

class TVGuidePage extends GetView<GuideController> {
  const TVGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isTV = ResponsiveHelper.isTV(context);

    // If somehow navigated here on mobile, show the mobile layout
    if (!isTV) {
      return AppScaffold(
        title: 'TV Guide',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.refreshGuide,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Get.toNamed(AppRoutes.guideSearch),
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
    return AppScaffold(
      title: 'TV Guide',
      showAppBar: false,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopHeader(context),
              _buildFiltersAndMiniPlayer(context),
              AppSpacing.heightMD,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.xl,
                    right: AppSpacing.xl,
                    bottom: 48.0, // Safe area for TV overscan
                  ),
                  child: _buildTVLayout(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Live TV Guide',
                style: AppTypography.getDisplay(color: AppColors.primary)
                    .copyWith(
                      fontWeight: FontWeight.bold,
                      shadows: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 8.0,
                        ),
                      ],
                    ),
              ),
              AppSpacing.widthMD,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  'Today',
                  style: AppTypography.getLabel(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search),
                color: AppColors.textSecondary,
                focusColor: AppColors.primaryContainer.withValues(alpha: 0.3),
                onPressed: () => Get.toNamed(AppRoutes.guideSearch),
              ),
              AppSpacing.widthMD,
              IconButton(
                icon: const Icon(Icons.notifications),
                color: AppColors.textSecondary,
                focusColor: AppColors.primaryContainer.withValues(alpha: 0.3),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersAndMiniPlayer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Filters
          Row(
            children: [
              _buildFilterPill('All Channels', true),
              AppSpacing.widthSM,
              _buildFilterPill('Movies', false),
              AppSpacing.widthSM,
              _buildFilterPill('Sports', false),
              AppSpacing.widthSM,
              _buildFilterPill('News', false),
            ],
          ),
          // Mini Player Placeholder
          Container(
            width: 384, // aspect-video (16:9) width
            height: 216,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              image: const DecorationImage(
                image: NetworkImage(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuBSsTPU-UZbqqyzQ7VMbmPuH0rtkKyyfvCPvDb0DXMEEtDue60vEZ4PlydIIPpWBhbV4VDzpS1M59QkJX9JAMcpZONZ1WHT9rN-EqafKBtkI6bYsKJ5Ad6LqzIfje_QN_tJQAmb_XdgNCLcDDOG5FZmXtpL7VCNm4o-kLFMtEt6Br25ar7rIs9FMT5hxCvZNjmAvyVk9wRuButjfwY8XUNoSmzPKoQyK6OvlJ4s6N5PPpMAztS_Okffzg',
                ),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.background.withValues(alpha: 0.9),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'LIVE',
                                  style: AppTypography.getLabel(
                                    color: Colors.white,
                                  ).copyWith(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.volume_up, color: Colors.white),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cyberpunk 2077: Neon Circuit',
                            style: AppTypography.getTitle(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'HBO Prime • 8:00 PM - 10:30 PM',
                            style: AppTypography.getLabel(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label, bool isSelected) {
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected || hasFocus
                  ? AppColors.primaryContainer
                  : AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected || hasFocus
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
              ),
              boxShadow: isSelected || hasFocus
                  ? [
                      BoxShadow(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.2,
                        ),
                        blurRadius: 10,
                      ),
                    ]
                  : [],
            ),
            child: Text(
              label,
              style: AppTypography.getTitle(
                color: isSelected || hasFocus
                    ? AppColors.onPrimaryContainer
                    : AppColors.textSecondary,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTVLayout(BuildContext context) {
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
                description: 'No EPG guide data is available at the moment.',
              );
            }

            return GuideGrid(
              channels: controller.channels,
              programs: controller.filteredPrograms,
              channelProgramsMap: _buildChannelProgramsMap(),
              onChannelTap: () {},
              onProgramTap: () {},
            );
          }),
        ),
      ),
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

  Map<String, List<EPGProgram>> _buildChannelProgramsMap() {
    final map = <String, List<EPGProgram>>{};
    for (final program in controller.filteredPrograms) {
      final channelId = program.channelId;
      if (channelId != null) {
        map.putIfAbsent(channelId, () => []).add(program);
      }
    }
    return map;
  }
}
