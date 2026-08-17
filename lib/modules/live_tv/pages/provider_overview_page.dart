import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/responsive_helper.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_radius.dart';
import '../controllers/provider_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/channel_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/empty_library.dart';

class ProviderOverviewPage extends GetView<ProviderController> {
  const ProviderOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Providers'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (controller.providerChannels.isEmpty) {
          return const EmptyLibrary(
            title: 'No Providers',
            description:
                'No providers configured yet. Add a provider to start browsing.',
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SectionHeader(
                  title: 'Provider Statistics',
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: ResponsiveHelper.isPhone(context) ? 2 : 3,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.5,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final providerName = controller.getProviderNames()[index];
                    final count = controller.getProviderCount(providerName);
                    return GestureDetector(
                      onTap: () => controller.selectProvider(providerName),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: AppRadius.medium,
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.network_check_outlined,
                              size: 32,
                              color: colorScheme.primary,
                            ),
                            AppSpacing.heightXS,
                            Text(
                              providerName,
                              style: AppTypography.getBody(
                                color: colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            AppSpacing.heightXXS,
                            Text(
                              '$count channels',
                              style: AppTypography.getCaption(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: controller.getProviderNames().length,
                ),
              ),
            ),
            if (controller.selectedProvider.value.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SectionHeader(
                    title: 'Channels (${controller.selectedProvider.value})',
                    trailing: TextButton(
                      onPressed: () => controller.selectProvider(''),
                      child: const Text('Back'),
                    ),
                  ),
                ),
              ),
            if (controller.selectedProvider.value.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: ResponsiveHelper.isPhone(context) ? 2 : 3,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final channels = controller.getProviderChannels(
                        controller.selectedProvider.value,
                      );
                      if (index >= channels.length) return const SizedBox.shrink();
                      final item = channels[index];
                      return ChannelCard(
                        channel: item,
                        onTap: () => Get.toNamed(
                          AppRoutes.channelDetails,
                          parameters: {'channelId': item.id},
                        ),
                        onFavorite: () => controller.toggleFavorite(item),
                        showFavoriteButton: true,
                      );
                    },
                    childCount: controller.getProviderChannels(
                      controller.selectedProvider.value,
                    ).length,
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}
