import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'splash_controller.dart';

class SplashPage extends GetView<SplashController> {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerHighest,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glowing logo badge
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: AppColors.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.5),
                      blurRadius: 30.0,
                      spreadRadius: 2.0,
                    ),
                  ],
                ),
                child: Icon(
                  AppIcons.play,
                  size: 64.0,
                  color: colorScheme.onPrimary,
                ),
              ),
              AppSpacing.heightXL,

              // App name
              Text(
                'StreamHub Pro',
                style: AppTypography.getDisplay(
                  color: colorScheme.onSurface,
                  scale: 1.1,
                ).copyWith(
                  shadows: [
                    Shadow(
                      color: colorScheme.shadow.withValues(alpha: 0.3),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
              AppSpacing.heightXXS,

              // Tagline
              Text(
                'Premium IPTV Client',
                style: AppTypography.getLabel(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 48.0),

              // Status message
              Obx(
                () => Text(
                  controller.statusMessage.value,
                  style: AppTypography.getCaption(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
              ),
              AppSpacing.heightLG,

              // Progress section
              Obx(() {
                final total = controller.syncTotal.value;
                final completed = controller.syncCompleted.value;
                final current = controller.syncCurrentProvider.value;

                if (total == 0) {
                  return const SizedBox.shrink();
                }

                final fraction = total == 0 ? 0.0 : completed / total;

                return Column(
                  children: [
                    Text(
                      current.isNotEmpty ? '$current ($completed/$total)' : '$completed/$total',
                      style: AppTypography.getCaption(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    AppSpacing.heightSM,
                    ClipRRect(
                      borderRadius: AppRadius.pill,
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 6.0,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    ),
                    AppSpacing.heightXS,
                    Text(
                      '${(fraction * 100).toInt()}%',
                      style: AppTypography.getCaption(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
