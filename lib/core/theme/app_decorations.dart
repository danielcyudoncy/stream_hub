import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_shadows.dart';

class AppDecorations {
  static BoxDecoration get cardDecorationDark => const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.medium,
        boxShadow: [AppShadows.card],
      );

  static BoxDecoration get cardDecorationLight => const BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: AppRadius.medium,
        boxShadow: [AppShadows.card],
      );

  static BoxDecoration get gradientBackgroundDark => const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.darkBackgroundGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );

  static BoxDecoration get gradientBackgroundLight => const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.lightBackgroundGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );

  /// Premium glassmorphism card effect — dark variant.
  static BoxDecoration get glassDecorationDark => BoxDecoration(
        color: AppColors.darkSurface.withValues(alpha: 0.7),
        borderRadius: AppRadius.medium,
        border: Border.all(
          color: AppColors.darkTextMuted.withValues(alpha: 0.15),
          width: 1.0,
        ),
      );

  /// Premium glassmorphism card effect — light variant.
  static BoxDecoration get glassDecorationLight => BoxDecoration(
        color: AppColors.lightSurface.withValues(alpha: 0.7),
        borderRadius: AppRadius.medium,
        border: Border.all(
          color: AppColors.lightTextMuted.withValues(alpha: 0.15),
          width: 1.0,
        ),
      );
}
