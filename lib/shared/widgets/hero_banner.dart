import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'cached_home_image.dart';
import 'tv_focusable.dart';

class HeroBanner extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String imageUrl;
  final VoidCallback? onPlayPressed;
  final VoidCallback? onInfoPressed;

  const HeroBanner({
    super.key,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.onPlayPressed,
    this.onInfoPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TvFocusable(
      onTap: onPlayPressed ?? onInfoPressed,
      scale: 1.02,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: AppRadius.large,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              CachedHomeImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
              
              // Gradient Overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black26,
                      AppColors.background,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              
              // Content
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      AppSpacing.heightXS,
                      Text(
                        subtitle!,
                        style: AppTypography.getBody(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    AppSpacing.heightSM,
                    Row(
                      children: [
                        if (onPlayPressed != null)
                          ElevatedButton.icon(
                            onPressed: onPlayPressed,
                            icon: const Icon(Icons.play_arrow, color: Colors.white),
                            label: const Text('Play Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        if (onPlayPressed != null && onInfoPressed != null)
                          AppSpacing.widthSM,
                        if (onInfoPressed != null)
                          OutlinedButton.icon(
                            onPressed: onInfoPressed,
                            icon: const Icon(Icons.info_outline, color: AppColors.textPrimary),
                            label: const Text('More Info', style: TextStyle(color: AppColors.textPrimary)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.textPrimary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
