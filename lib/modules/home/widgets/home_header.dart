import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/tv_focusable.dart';

class HomeHeader extends StatelessWidget {
  final String greeting;

  const HomeHeader({
    super.key,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final greetingText = greeting;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Greeting and App Badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4.0),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: AppColors.primaryGradient,
                          ),
                        ),
                        child: const Icon(
                          AppIcons.play,
                          color: Colors.white,
                          size: 12.0,
                        ),
                      ),
                      AppSpacing.widthXS,
                      Text(
                        'STREAMHUB PRO',
                        style: AppTypography.getCaption(
                          color: colorScheme.primary,
                          scale: 0.85,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  AppSpacing.heightXXS,
                  Text(
                    greetingText,
                    style: AppTypography.getTitle(
                      color: colorScheme.onSurface,
                    ).copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Header Actions (Search & Profile/Settings)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TvFocusable(
                  onTap: () => Get.toNamed(AppRoutes.search),
                  borderRadius: AppRadius.pill,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      AppIcons.search,
                      color: colorScheme.onSurface,
                      size: 20.0,
                    ),
                  ),
                ),
                AppSpacing.widthSM,
                TvFocusable(
                  onTap: () => Get.toNamed(AppRoutes.settings),
                  borderRadius: AppRadius.pill,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      AppIcons.settings,
                      color: colorScheme.onSurface,
                      size: 20.0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
