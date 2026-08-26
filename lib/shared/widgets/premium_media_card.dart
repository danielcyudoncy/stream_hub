import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/media_item.dart';
import 'cached_home_image.dart';
import 'glass_panel.dart';
import 'tv_focusable.dart';

class PremiumMediaCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final double width;
  final double aspectRatio;
  final String? overridePosterUrl;
  final ValueChanged<bool>? onFocusChange;
  final double? progress;
  final bool useGlassLabel;

  const PremiumMediaCard({
    super.key,
    required this.item,
    this.onTap,
    this.width = 140,
    this.aspectRatio = 2 / 3,
    this.overridePosterUrl,
    this.onFocusChange,
    this.progress,
    this.useGlassLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final posterUrl = overridePosterUrl ?? item.poster ?? item.thumbnail ?? item.backdrop;

    return TvFocusable(
      onTap: onTap,
      scale: 1.1,
      onFocusChange: onFocusChange,
      borderRadius: AppRadius.medium,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRRect(
                borderRadius: AppRadius.medium,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background placeholder
                    Container(color: AppColors.surfaceVariant),
                    
                    // Image
                    if (posterUrl != null && posterUrl.isNotEmpty)
                      Positioned.fill(
                        child: CachedHomeImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    else
                      const Center(child: Icon(Icons.movie, size: 40, color: AppColors.textSecondary)),
                    
                    // Glass overlay for rating
                    if (item.rating != null && item.rating! > 0 && !useGlassLabel)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GlassPanel(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: AppColors.secondary, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                item.rating!.toStringAsFixed(1),
                                style: AppTypography.getCaption(
                                  color: AppColors.textPrimary,
                                  scale: 0.9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Glass panel label for landscape mode
                    if (useGlassLabel)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: GlassPanel(
                          borderRadius: BorderRadius.zero,
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.title,
                                style: AppTypography.getLabel(
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle!,
                                  style: AppTypography.getCaption(
                                    color: AppColors.textSecondary,
                                    scale: 0.9,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (progress != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  height: 4,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          width: constraints.maxWidth * progress!,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.primary.withValues(alpha: 0.8),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Standard label (if not using glass overlay)
            if (!useGlassLabel)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        style: AppTypography.getCaption(
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                        AppSpacing.heightXXS,
                        Text(
                          item.subtitle!,
                          style: AppTypography.getCaption(
                            color: AppColors.textSecondary,
                            scale: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
