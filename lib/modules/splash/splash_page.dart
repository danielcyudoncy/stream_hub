import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'splash_controller.dart';

class SplashPage extends GetView<SplashController> {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppDecorations.gradientBackgroundDark,
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
                      color: AppColors.darkPrimary.withValues(alpha: 0.5),
                      blurRadius: 30.0,
                      spreadRadius: 2.0,
                    ),
                  ],
                ),
                child: const Icon(
                  AppIcons.play,
                  size: 64.0,
                  color: AppColors.darkTextPrimary,
                ),
              ),
              AppSpacing.heightXL,

              // App name
              Text(
                'StreamHub Pro',
                style: AppTypography.getDisplay(
                  color: AppColors.darkTextPrimary,
                  scale: 1.1,
                ),
              ),
              AppSpacing.heightXXS,

              // Tagline
              Text(
                'Premium IPTV Client',
                style: AppTypography.getLabel(color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: 64.0),

              // Loading spinner
              const CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.darkSecondary),
                strokeWidth: 3.0,
              ),
              AppSpacing.heightLG,

              // Status message
              Obx(
                () => Text(
                  controller.statusMessage.value,
                  style: AppTypography.getCaption(color: AppColors.darkTextMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
