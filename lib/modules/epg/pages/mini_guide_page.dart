import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/modules/epg/controllers/guide_controller.dart';
import 'package:stream_hub/modules/epg/widgets/mini_guide.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/empty_view.dart';
import 'package:stream_hub/shared/loading/loading_indicator.dart';

class MiniGuidePage extends GetView<GuideController> {
  const MiniGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Mini Guide',
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: LoadingIndicator(),
          );
        }

        if (controller.filteredPrograms.isEmpty) {
          return const EmptyView(
            title: 'No Guide Data',
            description: 'No programs available for the guide.',
          );
        }

        return MiniGuide(
          programs: controller.filteredPrograms.take(10).toList(),
          onViewAll: () {
            Get.toNamed('/epg/tv-guide');
          },
        );
      }),
    );
  }
}