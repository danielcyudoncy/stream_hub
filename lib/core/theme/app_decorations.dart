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
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.1),
        width: 1.0,
      ),
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
          colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
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
      color: surfaceColor.withValues(alpha: 0.8),
      borderRadius: AppRadius.medium,
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.1),
        width: 1.0,
      ),
    );
  }

  static final Border glassBorder = Border.all(
    color: Colors.white.withValues(alpha: 0.1),
    width: 1.0,
  );
}
