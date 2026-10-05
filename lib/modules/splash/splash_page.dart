import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_assets.dart';
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
      backgroundColor: const Color(0xFF040812),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF040812), Color(0xFF0A1128)],
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
                  // App brand logo with subtle glow
                  Container(
                    width: 128.0,
                    height: 128.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.35),
                          blurRadius: 36.0,
                          spreadRadius: 4.0,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      AppAssets.logo,
                      fit: BoxFit.contain,
                    ),
                  ),
                  AppSpacing.heightLG,

                  // App name
                  Text(
                    'StreamHub Pro',
                    style:
                        AppTypography.getHeadline(
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
