import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/utils/responsive_helper.dart';
import 'package:stream_hub/modules/epg/controllers/timeline_controller.dart';
import 'package:stream_hub/modules/epg/widgets/timeline_header.dart';
import 'package:stream_hub/modules/epg/widgets/timeline_ruler.dart';
import 'package:stream_hub/modules/epg/widgets/program_tile.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';
import 'package:stream_hub/shared/loading/loading_indicator.dart';
import 'package:stream_hub/shared/widgets/error_view.dart';
import 'package:stream_hub/shared/widgets/empty_view.dart';

class TimelineViewPage extends GetView<TimelineController> {
  const TimelineViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isTV = ResponsiveHelper.isTV(context);

    return AppScaffold(
      title: 'Timeline',
      actions: [
        TvFocusable(
          scale: 1.0,
          borderRadius: BorderRadius.circular(8),
          child: PopupMenuButton<int>(
            onSelected: (hours) => controller.setTimelineWindowHours(hours),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 1, child: Text('30 min')),
              const PopupMenuItem(value: 2, child: Text('1 hour')),
              const PopupMenuItem(value: 4, child: Text('2 hours')),
              const PopupMenuItem(value: 6, child: Text('6 hours')),
              const PopupMenuItem(value: 12, child: Text('12 hours')),
              const PopupMenuItem(value: 24, child: Text('24 hours')),
            ],
            icon: const Icon(Icons.timeline),
          ),
        ),
      ],
      body: Column(
        children: [
          TimelineHeader(
            windowStart: controller.windowStart.value,
            windowEnd: controller.windowEnd.value,
            visibleHours: controller.timelineWindowHours.value,
            onNowTap: controller.scrollToNow,
          ),
          TimelineRuler(
            windowStart: controller.windowStart.value,
            windowEnd: controller.windowEnd.value,
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
                  description: 'No programs found for the selected time range.',
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