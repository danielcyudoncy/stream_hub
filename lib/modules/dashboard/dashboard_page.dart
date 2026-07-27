import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/section_header.dart';
import 'dashboard_controller.dart';

class DashboardPage extends GetView<DashboardController> {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Dashboard',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome banner
            AppCard(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome to StreamHub Pro!',
                          style: AppTypography.getHeadline(
                              color: colorScheme.primary),
                        ),
                        AppSpacing.heightXS,
                        Text(
                          'Connect your IPTV providers in the Providers tab to start watching Live TV, Movies, and Series.',
                          style: AppTypography.getBody(
                            color: colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.heightXL,

            const SectionHeader(
              title: 'Quick Access',
              subtitle: 'Navigate to app features and configurations',
            ),
            AppSpacing.heightXS,

            GridView.count(
              crossAxisCount: context.isPhone ? 1 : 3,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildQuickActionCard(
                  icon: AppIcons.providers,
                  title: 'Manage Providers',
                  description:
                      'Add or configure M3U playlists, Xtream API, or Stalker Portal credentials.',
                  onTap: () => Get.offAllNamed(AppRoutes.providerManager),
                  colorScheme: colorScheme,
                ),
                _buildQuickActionCard(
                  icon: AppIcons.settings,
                  title: 'System Settings',
                  description:
                      'Configure appearance themes, language locales, and other playback options.',
                  onTap: () => Get.offAllNamed(AppRoutes.settings),
                  colorScheme: colorScheme,
                ),
                _buildQuickActionCard(
                  icon: AppIcons.profile,
                  title: 'Authentication',
                  description:
                      'Sign in to cloud servers to synchronize playlists and profiles across devices.',
                  onTap: () => Get.offAllNamed(AppRoutes.auth),
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colorScheme.primary, size: 24.0),
          ),
          AppSpacing.heightMD,
          Text(
            title,
            style: AppTypography.getTitle(color: colorScheme.onSurface),
          ),
          AppSpacing.heightXXS,
          Expanded(
            child: Text(
              description,
              style: AppTypography.getCaption(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
