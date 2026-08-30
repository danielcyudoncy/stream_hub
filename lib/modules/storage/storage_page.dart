import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/shared/widgets/app_card.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/section_header.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

class StoragePage extends StatelessWidget {
  const StoragePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Storage',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Storage Overview', subtitle: 'Local data and cache usage'),
            AppSpacing.heightXS,
            AppCard(
              child: Column(
                children: [
                  _buildStatRow(context, 'Database Size', 'Calculating...', Icons.storage_outlined),
                  _buildStatRow(context, 'Cache Size', 'Calculating...', Icons.cleaning_services_outlined),
                  _buildStatRow(context, 'Providers', '0', Icons.playlist_play_outlined),
                  _buildStatRow(context, 'Favorites', '0', Icons.favorite_border_outlined),
                  _buildStatRow(context, 'Downloads', '0', Icons.download_outlined, showDivider: false),
                ],
              ),
            ),
            AppSpacing.heightXL,
            const SectionHeader(title: 'Cache Management', subtitle: 'Clear and optimize cache'),
            AppSpacing.heightXS,
            AppCard(
              child: Column(
                children: [
                  TvFocusable(
                    borderRadius: AppRadius.medium,
                    scale: 1.02,
                    onTap: () => _showClearCacheDialog(context),
                    child: ListTile(
                      leading: Icon(Icons.cleaning_services_outlined, color: colorScheme.primary),
                      title: Text('Clear Cache', style: AppTypography.getBody(color: colorScheme.onSurface)),
                      subtitle: Text('Delete temporary files and cached images', style: AppTypography.getCaption(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                  ),
                  TvFocusable(
                    borderRadius: AppRadius.medium,
                    scale: 1.02,
                    onTap: () => _showOptimizeDialog(context),
                    child: ListTile(
                      leading: Icon(Icons.storage_outlined, color: colorScheme.primary),
                      title: Text('Optimize Storage', style: AppTypography.getBody(color: colorScheme.onSurface)),
                      subtitle: Text('Compact database and remove orphaned records', style: AppTypography.getCaption(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.heightXL,
            const SectionHeader(title: 'Data Transfer', subtitle: 'Import and export settings'),
            AppSpacing.heightXS,
            AppCard(
              child: Column(
                children: [
                  TvFocusable(
                    borderRadius: AppRadius.medium,
                    scale: 1.02,
                    onTap: () => _showExportDialog(context),
                    child: ListTile(
                      leading: Icon(Icons.upload_file_outlined, color: colorScheme.primary),
                      title: Text('Export Settings', style: AppTypography.getBody(color: colorScheme.onSurface)),
                      subtitle: Text('Export app settings to a file', style: AppTypography.getCaption(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                  ),
                  TvFocusable(
                    borderRadius: AppRadius.medium,
                    scale: 1.02,
                    onTap: () => _showImportDialog(context),
                    child: ListTile(
                      leading: Icon(Icons.download_for_offline_outlined, color: colorScheme.primary),
                      title: Text('Import Settings', style: AppTypography.getBody(color: colorScheme.onSurface)),
                      subtitle: Text('Import settings from a file', style: AppTypography.getCaption(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value, IconData icon, {bool showDivider = true}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: colorScheme.primary, size: 22),
          title: Text(label, style: AppTypography.getBody(color: colorScheme.onSurface)),
          trailing: Text(value, style: AppTypography.getTitle(color: colorScheme.onSurface)),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outline.withValues(alpha: 0.08),
            indent: 56,
            endIndent: 16,
          ),
      ],
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
      title: Text('Clear Cache', style: AppTypography.getHeadline()),
      content: Text('This will delete all cached images, EPG data, and temporary files. Continue?', style: AppTypography.getBody()),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Get.back(), child: const Text('Clear')),
      ],
    ));
  }

  void _showOptimizeDialog(BuildContext context) {
    Get.snackbar(
      'Optimize Storage',
      'Storage optimization will be available in a future update.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _showExportDialog(BuildContext context) {
    Get.snackbar(
      'Export Settings',
      'Settings export will be available in a future update.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _showImportDialog(BuildContext context) {
    Get.snackbar(
      'Import Settings',
      'Settings import will be available in a future update.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
