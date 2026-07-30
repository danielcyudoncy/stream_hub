import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive_helper.dart';

import '../controllers/live_tv_controller.dart';
import '../../../shared/widgets/channel_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/empty_library.dart';

class RecentPage extends GetView<LiveTVController> {
  const RecentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Recent'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (controller.channels.isEmpty) {
          return const EmptyLibrary(
            title: 'No Recent Activity',
            description:
                'Browse channels to see your recent activity here.',
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: SectionHeader(
                  title: 'Recently Viewed',
                  subtitle: '${controller.channels.length} channels',
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: ResponsiveHelper.isPhone(context) ? 2 : (ResponsiveHelper.isDesktop(context) ? 4 : 3),
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = controller.channels[index];
                    return GestureDetector(
                      onTap: () => Get.toNamed(
                        '/channel-details',
                        parameters: {'channelId': item.id},
                      ),
                      child: ChannelCard(
                        channel: item,
                        showFavoriteButton: true,
                      ),
                    );
                  },
                  childCount: controller.channels.length,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
