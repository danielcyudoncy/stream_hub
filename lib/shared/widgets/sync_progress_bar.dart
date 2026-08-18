import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/services/provider_sync_service.dart';

/// A sleek, non-intrusive floating indicator displayed while providers and
/// catalogs are syncing in the background.
class SyncProgressBar extends StatelessWidget {
  const SyncProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ProviderSyncService>()) {
      return const SizedBox.shrink();
    }

    final syncService = Get.find<ProviderSyncService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final isSyncing = syncService.isSyncing.value;
      final message = syncService.currentSyncMessage.value;
      final progress = syncService.syncProgress.value;

      return AnimatedCrossFade(
        duration: const Duration(milliseconds: 300),
        crossFadeState:
            isSyncing ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        firstChild: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceVariant.withValues(alpha: 0.95)
                : AppColors.lightSurfaceVariant.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(AppRadius.mediumValue),
            border: Border.all(
              color: isDark
                  ? AppColors.darkPrimary.withValues(alpha: 0.3)
                  : AppColors.lightPrimary.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      message.isNotEmpty ? message : 'Updating playlists...',
                      style: AppTypography.getCaption(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ).copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: AppTypography.getCaption(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.smallValue),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  minHeight: 2.5,
                  backgroundColor: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        secondChild: const SizedBox(width: double.infinity, height: 0),
      );
    });
  }
}
