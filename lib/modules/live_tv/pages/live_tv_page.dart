import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/channel.dart';
import '../controllers/live_tv_controller.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/channel_card.dart';
import '../../../shared/widgets/empty_library.dart';
import '../../../shared/widgets/live_badge.dart';

class LiveTVPage extends GetView<LiveTVController> {
  const LiveTVPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTV = ResponsiveHelper.isTV(context);

    return AppScaffold(
      title: 'Live TV',
      body: Column(
        children: [
          _buildFilterBar(context, colorScheme),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (controller.filteredChannels.isEmpty) {
                return EmptyLibrary(
                  title: 'No Channels',
                  description:
                      'No channels match your current filters. Try adjusting your filter criteria.',
                  actionLabel: 'Clear Filters',
                  onAction: _clearFilters,
                );
              }

              return _buildChannelList(context, colorScheme, isTV);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(
              context,
              label: 'All',
              isSelected: controller.selectedCategory.value == 'All Channels',
              onTap: () => controller.setCategory('All Channels'),
            ),
            for (final category in controller.categories.skip(1))
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: _filterChip(
                  context,
                  label: category,
                  isSelected: controller.selectedCategory.value == category,
                  onTap: () => controller.setCategory(category),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        margin: const EdgeInsets.only(right: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.pill,
        ),
        child: Text(
          label,
          style: AppTypography.getCaption(
            color: isSelected ? Colors.white : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildChannelList(BuildContext context, ColorScheme colorScheme, bool isTV) {
    if (controller.selectedView.value == 'grid') {
      return GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isTV ? 5 : (ResponsiveHelper.isDesktop(context) ? 4 : (ResponsiveHelper.isTablet(context) ? 3 : 2)),
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: isTV ? 0.6 : 0.75,
        ),
        itemCount: controller.filteredChannels.length,
        itemBuilder: (context, index) {
          final item = controller.filteredChannels[index];
          return GestureDetector(
            onTap: () => controller.openChannel(item),
            child: ChannelCard(
              channel: item,
              showFavoriteButton: true,
              showChannelNumber: true,
              showHD: true,
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: controller.filteredChannels.length,
      itemBuilder: (context, index) {
        final item = controller.filteredChannels[index];
        final isChannel = item is Channel;
        final isLive = isChannel && item.isLive;
        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.small,
            ),
            child: Center(
              child: Icon(
                Icons.live_tv_outlined,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
          ),
          title: Text(item.title),
          subtitle: item.subtitle != null &&
                  !Validators.isValidUrl(item.subtitle)
              ? Text(item.subtitle!)
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLive) const LiveBadge(),
              IconButton(
                icon: Icon(
                  item.favorite ? Icons.favorite : Icons.favorite_border,
                  color: item.favorite ? AppColors.darkError : null,
                ),
                onPressed: () => controller.toggleFavorite(item),
              ),
            ],
          ),
          onTap: () => Get.toNamed(
            AppRoutes.channelDetails,
            parameters: {'channelId': item.id},
          ),
        );
      },
    );
  }

  void _clearFilters() {
    controller.setCategory('All Channels');
    controller.setProvider('');
    controller.setLanguage('');
    controller.setCountry('');
    controller.setResolution('');
    controller.setFavoritesOnly(false);
    controller.setRecentlyAdded(false);
  }
}
