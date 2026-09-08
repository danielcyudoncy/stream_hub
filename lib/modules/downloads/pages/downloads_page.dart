import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/data/models/download_item.dart';
import 'package:stream_hub/modules/downloads/controllers/downloads_controller.dart';
import 'package:stream_hub/shared/widgets/app_card.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

class DownloadsPage extends GetView<DownloadsController> {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Downloads',
      showNavigation: false,
      actions: [
        Obx(() {
          if (controller.downloads.isEmpty) return const SizedBox.shrink();
          return TvFocusable(
            borderRadius: AppRadius.medium,
            onTap: () => _confirmClearAll(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_sweep_outlined,
                      size: 20, color: colorScheme.error),
                  AppSpacing.widthXS,
                  Text(
                    'Clear All',
                    style: AppTypography.getCaption(
                      color: colorScheme.error,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
      body: Obx(() {
        if (controller.isLoading.value && controller.downloads.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            _buildStorageSummary(context, colorScheme),
            _buildFilterTabs(context, colorScheme),
            Expanded(
              child: controller.filteredDownloads.isEmpty
                  ? _buildEmptyState(context, colorScheme)
                  : _buildDownloadsList(context, colorScheme),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStorageSummary(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: AppCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: AppRadius.medium,
              ),
              child: Icon(
                Icons.folder_zip_outlined,
                color: colorScheme.primary,
                size: 28,
              ),
            ),
            AppSpacing.widthMD,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline Storage Used',
                    style: AppTypography.getCaption(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    controller.formatBytes(controller.storageUsedBytes.value),
                    style: AppTypography.getTitle(
                      color: colorScheme.onSurface,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${controller.completedCount} available',
                  style: AppTypography.getBody(
                    color: colorScheme.primary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                if (controller.activeCount > 0)
                  Text(
                    '${controller.activeCount} in progress',
                    style: AppTypography.getCaption(
                      color: AppColors.darkWarning,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          _buildFilterChip(
            context,
            filter: DownloadFilter.all,
            label: 'All (${controller.downloads.length})',
            colorScheme: colorScheme,
          ),
          AppSpacing.widthSM,
          _buildFilterChip(
            context,
            filter: DownloadFilter.active,
            label: 'Active (${controller.activeCount})',
            colorScheme: colorScheme,
          ),
          AppSpacing.widthSM,
          _buildFilterChip(
            context,
            filter: DownloadFilter.completed,
            label: 'Completed (${controller.completedCount})',
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required DownloadFilter filter,
    required String label,
    required ColorScheme colorScheme,
  }) {
    final isSelected = controller.selectedFilter.value == filter;
    return TvFocusable(
      borderRadius: AppRadius.large,
      onTap: () => controller.setFilter(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: AppRadius.large,
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.getCaption(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildDownloadsList(BuildContext context, ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: controller.filteredDownloads.length,
      itemBuilder: (context, index) {
        final item = controller.filteredDownloads[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildDownloadCard(context, item, colorScheme),
        );
      },
    );
  }

  Widget _buildDownloadCard(
    BuildContext context,
    DownloadItem item,
    ColorScheme colorScheme,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(item, colorScheme),
              AppSpacing.widthMD,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTypography.getBody(
                        color: colorScheme.onSurface,
                      ).copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildStatusBadge(item, colorScheme),
                        AppSpacing.widthSM,
                        Text(
                          item.fileExtension.toUpperCase(),
                          style: AppTypography.getCaption(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildTrailingActions(context, item, colorScheme),
            ],
          ),
          if (item.isDownloading || item.isPaused) ...[
            AppSpacing.heightSM,
            ClipRRect(
              borderRadius: AppRadius.small,
              child: LinearProgressIndicator(
                value: item.progress > 0 ? item.progress : null,
                backgroundColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                color: item.isPaused ? AppColors.darkWarning : colorScheme.primary,
                minHeight: 4,
              ),
            ),
            AppSpacing.heightXS,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${controller.formatBytes(item.downloadedBytes)} of ${item.totalBytes > 0 ? controller.formatBytes(item.totalBytes) : 'Unknown'}',
                  style: AppTypography.getCaption(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (item.isDownloading && item.speedBytesPerSecond > 0)
                  Text(
                    controller.formatSpeed(item.speedBytesPerSecond),
                    style: AppTypography.getCaption(
                      color: colorScheme.primary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  )
                else if (item.isPaused)
                  Text(
                    'Paused',
                    style: AppTypography.getCaption(
                      color: AppColors.darkWarning,
                    ),
                  ),
              ],
            ),
          ],
          if (item.isFailed && item.error != null) ...[
            AppSpacing.heightXS,
            Text(
              'Error: ${item.error}',
              style: AppTypography.getCaption(
                color: colorScheme.error,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThumbnail(DownloadItem item, ColorScheme colorScheme) {
    const width = 60.0;
    const height = 60.0;

    if (item.posterUrl != null && item.posterUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: AppRadius.medium,
        child: CachedNetworkImage(
          imageUrl: item.posterUrl!,
          width: width,
          height: height,
          fit: BoxFit.cover,
          placeholder: (ctx, url) => Container(
            width: width,
            height: height,
            color: colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.movie_outlined, size: 24),
          ),
          errorWidget: (ctx, url, err) => Container(
            width: width,
            height: height,
            color: colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.movie_outlined, size: 24),
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.medium,
      ),
      child: Icon(
        item.mediaType == 'series'
            ? Icons.tv_outlined
            : Icons.movie_outlined,
        color: colorScheme.primary,
        size: 28,
      ),
    );
  }

  Widget _buildStatusBadge(DownloadItem item, ColorScheme colorScheme) {
    Color badgeColor;
    String text;

    switch (item.status) {
      case DownloadStatus.completed:
        badgeColor = Colors.green;
        text = 'Ready';
        break;
      case DownloadStatus.downloading:
        badgeColor = colorScheme.primary;
        text = '${(item.progress * 100).toInt()}%';
        break;
      case DownloadStatus.paused:
        badgeColor = Colors.amber;
        text = 'Paused';
        break;
      case DownloadStatus.queued:
        badgeColor = Colors.blueGrey;
        text = 'Queued';
        break;
      case DownloadStatus.failed:
        badgeColor = colorScheme.error;
        text = 'Failed';
        break;
      case DownloadStatus.cancelled:
        badgeColor = colorScheme.outline;
        text = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: AppRadius.small,
      ),
      child: Text(
        text,
        style: AppTypography.getCaption(
          color: badgeColor,
        ).copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTrailingActions(
    BuildContext context,
    DownloadItem item,
    ColorScheme colorScheme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.isCompleted) ...[
          TvFocusable(
            borderRadius: AppRadius.large,
            onTap: () => controller.playDownload(item),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow,
                size: 20,
                color: colorScheme.onPrimary,
              ),
            ),
          ),
          AppSpacing.widthSM,
          TvFocusable(
            borderRadius: AppRadius.large,
            onTap: () => _confirmDelete(context, item),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.delete_outline,
                size: 20,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ] else if (item.isDownloading) ...[
          TvFocusable(
            borderRadius: AppRadius.large,
            onTap: () => controller.pauseDownload(item.id),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.pause_circle_outline,
                size: 24,
                color: colorScheme.primary,
              ),
            ),
          ),
          AppSpacing.widthXS,
          TvFocusable(
            borderRadius: AppRadius.large,
            onTap: () => controller.cancelDownload(item.id),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.cancel_outlined,
                size: 22,
                color: colorScheme.error,
              ),
            ),
          ),
        ] else if (item.isPaused) ...[
          TvFocusable(
            borderRadius: AppRadius.large,
            onTap: () => controller.resumeDownload(item.id),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.play_circle_outline,
                size: 24,
                color: colorScheme.primary,
              ),
            ),
          ),
          AppSpacing.widthXS,
          TvFocusable(
            borderRadius: AppRadius.large,
            onTap: () => controller.cancelDownload(item.id),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.cancel_outlined,
                size: 22,
                color: colorScheme.error,
              ),
            ),
          ),
        ] else if (item.isFailed) ...[
          TvFocusable(
            borderRadius: AppRadius.large,
            onTap: () => controller.retryDownload(item.id),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.refresh_outlined,
                size: 22,
                color: colorScheme.primary,
              ),
            ),
          ),
          AppSpacing.widthXS,
          TvFocusable(
            borderRadius: AppRadius.large,
            onTap: () => controller.deleteDownload(item.id),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.delete_outline,
                size: 20,
                color: colorScheme.error,
              ),
            ),
          ),
        ] else ...[
          TvFocusable(
            borderRadius: AppRadius.large,
            onTap: () => controller.deleteDownload(item.id),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.delete_outline,
                size: 20,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_for_offline_outlined,
              size: 64,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            AppSpacing.heightMD,
            Text(
              'No Downloads',
              style: AppTypography.getTitle(
                color: colorScheme.onSurface,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
            AppSpacing.heightXS,
            Text(
              'Movies and series you download for offline viewing will appear here.',
              textAlign: TextAlign.center,
              style: AppTypography.getBody(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, DownloadItem item) {
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
      title: Text('Delete Download', style: AppTypography.getHeadline()),
      content: Text(
        'Are you sure you want to delete "${item.title}" from your device? This cannot be undone.',
        style: AppTypography.getBody(),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () {
            Get.back();
            controller.deleteDownload(item.id);
          },
          child: const Text('Delete'),
        ),
      ],
    ));
  }

  void _confirmClearAll(BuildContext context) {
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
      title: Text('Clear All Downloads', style: AppTypography.getHeadline()),
      content: Text(
        'This will delete all downloaded offline media from this device. Continue?',
        style: AppTypography.getBody(),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () {
            Get.back();
            controller.clearAll();
          },
          child: const Text('Clear All'),
        ),
      ],
    ));
  }
}
