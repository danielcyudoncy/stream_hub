import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/app_update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/app_update_info.dart';
import '../widgets/tv_focusable.dart';

class AppUpdateDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;

  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
  });

  static Future<void> show({
    required AppUpdateInfo updateInfo,
  }) async {
    await Get.dialog(
      AppUpdateDialog(updateInfo: updateInfo),
      barrierDismissible: !updateInfo.forceUpdate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final updateService = Get.find<AppUpdateService>();

    return PopScope(
      canPop: !updateInfo.forceUpdate,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.lg),
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: AppRadius.large,
                border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.12),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Obx(() {
                final status = updateService.status.value;
                final isDownloading = status == AppUpdateStatus.downloading;
                final isInstalling = status == AppUpdateStatus.installing || status == AppUpdateStatus.downloaded;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context, colorScheme),
                    AppSpacing.heightMD,
                    if (updateInfo.forceUpdate) ...[
                      _buildMandatoryBanner(context),
                      AppSpacing.heightMD,
                    ],
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (updateInfo.releaseNotes.isNotEmpty) ...[
                              Text(
                                "What's New:",
                                style: AppTypography.getBody(
                                  color: colorScheme.onSurface,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                              AppSpacing.heightSM,
                              ...updateInfo.releaseNotes.map(
                                (note) => Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '• ',
                                        style: AppTypography.getBody(
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          note,
                                          style: AppTypography.getBody(
                                            color: colorScheme.onSurface.withValues(alpha: 0.85),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              AppSpacing.heightMD,
                            ],
                            if (isDownloading) ...[
                              _buildDownloadProgress(context, colorScheme, updateService),
                            ] else if (isInstalling) ...[
                              _buildInstallingIndicator(context, colorScheme),
                            ] else if (status == AppUpdateStatus.error) ...[
                              _buildErrorBanner(context, updateService.errorMessage.value),
                            ],
                          ],
                        ),
                      ),
                    ),
                    AppSpacing.heightLG,
                    _buildActions(context, colorScheme, updateService, isDownloading, isInstalling),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.primaryGradient),
            borderRadius: AppRadius.medium,
          ),
          child: const Icon(
            Icons.system_update_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        AppSpacing.widthMD,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update Available',
                style: AppTypography.getHeadline(color: colorScheme.onSurface),
              ),
              AppSpacing.heightXS,
              Text(
                'v${updateInfo.latestVersion} (Build ${updateInfo.buildNumber})',
                style: AppTypography.getCaption(
                  color: colorScheme.primary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMandatoryBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: AppRadius.small,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
          AppSpacing.widthSM,
          Expanded(
            child: Text(
              'This update is required to continue enjoying StreamHub Pro.',
              style: AppTypography.getCaption(color: AppColors.warning).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress(
    BuildContext context,
    ColorScheme colorScheme,
    AppUpdateService service,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Downloading update...',
              style: AppTypography.getBody(color: colorScheme.onSurface),
            ),
            Text(
              '${(service.downloadProgress.value * 100).toInt()}%',
              style: AppTypography.getBody(color: colorScheme.primary).copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        AppSpacing.heightXS,
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: service.downloadProgress.value > 0 ? service.downloadProgress.value : null,
            backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            minHeight: 8,
          ),
        ),
        AppSpacing.heightXS,
        Text(
          service.downloadStatusMessage.value,
          style: AppTypography.getCaption(color: colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  Widget _buildInstallingIndicator(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: AppRadius.small,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          AppSpacing.widthMD,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Launching installer...',
                  style: AppTypography.getBody(color: colorScheme.onSurface).copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'If prompted by Android, allow "Install unknown apps" to complete.',
                  style: AppTypography.getCaption(color: colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: AppRadius.small,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          AppSpacing.widthSM,
          Expanded(
            child: Text(
              error.isNotEmpty ? error : 'Download failed. Please check connection.',
              style: AppTypography.getCaption(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    ColorScheme colorScheme,
    AppUpdateService service,
    bool isDownloading,
    bool isInstalling,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!updateInfo.forceUpdate && !isInstalling) ...[
          TvFocusable(
            onTap: () {
              if (isDownloading) {
                service.cancelDownload();
              }
              Get.back();
            },
            borderRadius: AppRadius.medium,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: AppRadius.medium,
                border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.2)),
              ),
              child: Text(
                isDownloading ? 'Cancel' : 'Later',
                style: AppTypography.getBody(color: colorScheme.onSurface),
              ),
            ),
          ),
          AppSpacing.widthMD,
        ],
        if (!isInstalling)
          TvFocusable(
            autofocus: true,
            onTap: isDownloading
                ? null
                : () async {
                    await service.startDownloadAndInstall(updateInfo);
                  },
            borderRadius: AppRadius.medium,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.primaryGradient),
                borderRadius: AppRadius.medium,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                  AppSpacing.widthXS,
                  Text(
                    isDownloading ? 'Downloading...' : 'Update Now',
                    style: AppTypography.getBody(color: Colors.white).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
