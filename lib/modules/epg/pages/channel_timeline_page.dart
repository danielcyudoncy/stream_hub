import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/utils/responsive_helper.dart';
import 'package:stream_hub/modules/epg/controllers/channel_timeline_controller.dart';
import 'package:stream_hub/modules/epg/widgets/timeline_header.dart';
import 'package:stream_hub/modules/epg/widgets/timeline_ruler.dart';
import 'package:stream_hub/modules/epg/widgets/program_tile.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';
import 'package:stream_hub/shared/loading/loading_indicator.dart';
import 'package:stream_hub/shared/widgets/error_view.dart';
import 'package:stream_hub/shared/widgets/empty_view.dart';

class ChannelTimelinePage extends GetView<ChannelTimelineController> {
  const ChannelTimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isTV = ResponsiveHelper.isTV(context);

    return AppScaffold(
      title: controller.channelName.value.isEmpty
          ? 'Channel Timeline'
          : controller.channelName.value,
      actions: [
        TvFocusable(
          scale: 1.0,
          borderRadius: BorderRadius.circular(8),
          child: PopupMenuButton<int>(
            onSelected: (hours) {
              controller.visibleHours.value = hours;
              controller.loadTimeline();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 6, child: Text('6 hours')),
              const PopupMenuItem(value: 12, child: Text('12 hours')),
              const PopupMenuItem(value: 24, child: Text('24 hours')),
              const PopupMenuItem(value: 48, child: Text('48 hours')),
            ],
            icon: const Icon(Icons.timeline),
          ),
        ),
      ],
      body: Column(
        children: [
          TimelineHeader(
            windowStart: controller.timelineEntries.isNotEmpty
                ? controller.timelineEntries.first.slotStart
                : DateTime.now(),
            windowEnd: controller.timelineEntries.isNotEmpty
                ? controller.timelineEntries.last.slotEnd
                : DateTime.now(),
            visibleHours: controller.visibleHours.value,
            onNowTap: controller.scrollToNow,
          ),
          TimelineRuler(
            windowStart: controller.timelineEntries.isNotEmpty
                ? controller.timelineEntries.first.slotStart
                : DateTime.now(),
            windowEnd: controller.timelineEntries.isNotEmpty
                ? controller.timelineEntries.last.slotEnd
                : DateTime.now(),
          ),
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
                  onRetry: controller.loadTimeline,
                );
              }

              if (controller.timelineEntries.isEmpty) {
                return const EmptyView(
                  title: 'No Programs',
                  description:
                      'No programs available for this channel in the selected time range.',
                );
              }

              return _buildTimelineContent(context, isTV);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineContent(BuildContext context, bool isTV) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: controller.timelineEntries.length,
      itemBuilder: (context, index) {
        final entry = controller.timelineEntries[index];
        return ProgramTile(
          program: entry.program,
          isCurrent: entry.isCurrent,
          width: isTV ? 400 : (ResponsiveHelper.isDesktop(context) ? 300 : 200),
          onTap: () {
            Get.toNamed(
              AppRoutes.programDetails,
              parameters: {'programId': entry.program.id},
            );
          },
        );
      },
    );
  }
}