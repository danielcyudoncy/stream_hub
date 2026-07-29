import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_shadows.dart';

class AppDecorations {
  static BoxDecoration cardDecoration({
    required Color surfaceColor,
  }) {
    return BoxDecoration(
      color: surfaceColor,
      borderRadius: AppRadius.medium,
      boxShadow: [AppShadows.card],
    );
  }

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

  /// Premium glassmorphism card effect.
  static BoxDecoration glassDecoration({
    required Color surfaceColor,
    required Color textMutedColor,
  }) {
    return BoxDecoration(
      color: surfaceColor.withValues(alpha: 0.7),
      borderRadius: AppRadius.medium,
      border: Border.all(
        color: textMutedColor.withValues(alpha: 0.15),
        width: 1.0,
      ),
    );
  }
}
