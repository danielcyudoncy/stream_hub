import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
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
            colors: [colorScheme.surface, colorScheme.surfaceContainerHighest],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
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
                      size: 56.0,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  AppSpacing.heightLG,

                  // App name
                  Text(
                    'StreamHub Pro',
                    style:
                        AppTypography.getDisplay(
                          color: colorScheme.onSurface,
                          scale: 1.0,
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
                    style: AppTypography.getLabel(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  Text(
                    'By ChamDTech',
                    style: AppTypography.getLabel(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32.0),

                  // Loading spinner
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.secondary,
                    ),
                    strokeWidth: 3.0,
                  ),
                  AppSpacing.heightMD,

                  // Status message
                  Obx(
                    () => Text(
                      controller.statusMessage.value,
                      style: AppTypography.getCaption(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
