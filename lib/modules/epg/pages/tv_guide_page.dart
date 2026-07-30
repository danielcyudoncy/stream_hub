import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
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
                return const Center(
                  child: LoadingIndicator(),
                );
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

              if (isTV) {
                return _buildTVLayout(context);
              }

              return _buildMobileLayout(context);
            }),
          ),
        ],
      ),
    );
  }

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
            _navButton(context, 'Now', () => controller.setTimelineWindowHours(6)),
            _navButton(context, 'Morning', controller.scrollToMorning),
            _navButton(context, 'Afternoon', controller.scrollToAfternoon),
            _navButton(context, 'Evening', controller.scrollToEvening),
            _navButton(context, 'Tomorrow', controller.scrollToTomorrow),
          ],
        ),
      ),
    );
  }

  Widget _navButton(
    BuildContext context,
    String label,
    VoidCallback onTap,
  ) {
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

  Widget _buildTVLayout(BuildContext context) {
    return GuideGrid(
      channels: controller.channels,
      programs: controller.filteredPrograms,
      channelProgramsMap: _buildChannelProgramsMap(),
      channelColumnWidth: 150,
      programTileWidth: 220,
      onChannelTap: () {},
      onProgramTap: () {},
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
    for (final channel in controller.channels) {
      map[channel.id] = controller.filteredPrograms
          .where((p) => p.channelId == channel.id)
          .toList();
    }
    return map;
  }
}