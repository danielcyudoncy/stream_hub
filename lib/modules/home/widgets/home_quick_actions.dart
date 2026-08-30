import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/tv_focusable.dart';

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTv = PlatformHelper.isTV;
    final width = MediaQuery.of(context).size.width;

    final actions = [
      _QuickActionItem(
        icon: AppIcons.liveTv,
        label: 'Live TV',
        color: const Color(0xFFEF4444), // Crimson/Red
        route: AppRoutes.liveTV,
      ),
      _QuickActionItem(
        icon: Icons.tv_rounded,
        label: 'Free TV',
        color: const Color(0xFF3B82F6), // Blue
        route: AppRoutes.freeLiveTV,
      ),
      _QuickActionItem(
        icon: AppIcons.movies,
        label: 'Movies',
        color: const Color(0xFF6366F1), // Indigo
        route: AppRoutes.movies,
      ),
      _QuickActionItem(
        icon: AppIcons.series,
        label: 'Series',
        color: const Color(0xFF14B8A6), // Teal
        route: AppRoutes.series,
      ),
      _QuickActionItem(
        icon: AppIcons.favorites,
        label: 'My List',
        color: const Color(0xFFEC4899), // Pink
        route: AppRoutes.favorites,
      ),
      _QuickActionItem(
        icon: AppIcons.search,
        label: 'Search',
        color: const Color(0xFFF59E0B), // Amber
        route: AppRoutes.search,
      ),
    ];

    if (isTv || width >= 900) {
      // Large TV / Desktop layout: row of focusable tiles
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: actions.map((action) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: TvFocusable(
                  onTap: () => Get.toNamed(action.route),
                  borderRadius: AppRadius.medium,
                  scale: 1.05,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: AppRadius.medium,
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: action.color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            action.icon,
                            color: action.color,
                            size: 20.0,
                          ),
                        ),
                        AppSpacing.widthSM,
                        Text(
                          action.label,
                          style: AppTypography.getLabel(
                            color: colorScheme.onSurface,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    // Mobile / Tablet layout: horizontal scrolling chips
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return Container(
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            child: TvFocusable(
              onTap: () => Get.toNamed(action.route),
              borderRadius: AppRadius.pill,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: AppRadius.pill,
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      action.icon,
                      color: action.color,
                      size: 16.0,
                    ),
                    AppSpacing.widthXS,
                    Text(
                      action.label,
                      style: AppTypography.getCaption(
                        color: colorScheme.onSurface,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final String route;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });
}
