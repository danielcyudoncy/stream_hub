import 'package:flutter/material.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/tv_focusable.dart';

/// A button that allows users to skip an intro/outro segment during playback.
class SkipIntroButton extends StatelessWidget {
  final VoidCallback onSkip;
  final String label;

  const SkipIntroButton({
    super.key,
    required this.onSkip,
    this.label = 'Skip Intro',
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: AppSpacing.xxl + 40,
      right: AppSpacing.xxl,
      child: Material(
        color: Colors.transparent,
        child: TvFocusable(
          onTap: onSkip,
          borderRadius: AppRadius.pill,
          scale: 1.05,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: AppRadius.pill,
              border: Border.all(
                color: Colors.white70,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10.0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  AppIcons.forward,
                  size: 18.0,
                  color: Colors.white,
                ),
                AppSpacing.widthXS,
                Text(
                  label,
                  style: AppTypography.getButton(
                    color: Colors.white,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
