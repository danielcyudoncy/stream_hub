import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'app_app_bar.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool showNavigation;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.showNavigation = true,
    this.floatingActionButton,
  });

  int _getSelectedIndex() {
    final route = Get.currentRoute;
    if (route == AppRoutes.providerManager) return 1;
    if (route == AppRoutes.settings) return 2;
    return 0;
  }

  void _onItemTapped(int index) {
    if (_getSelectedIndex() == index) return;
    switch (index) {
      case 0:
        Get.offAllNamed(AppRoutes.dashboard);
        break;
      case 1:
        Get.offAllNamed(AppRoutes.providerManager);
        break;
      case 2:
        Get.offAllNamed(AppRoutes.settings);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final List<NavigationDestination> destinations = [
      const NavigationDestination(
        icon: Icon(AppIcons.dashboard),
        selectedIcon: Icon(AppIcons.dashboard, color: AppColors.darkPrimary),
        label: 'Dashboard',
      ),
      const NavigationDestination(
        icon: Icon(AppIcons.providers),
        selectedIcon: Icon(AppIcons.providers, color: AppColors.darkPrimary),
        label: 'Providers',
      ),
      const NavigationDestination(
        icon: Icon(AppIcons.settings),
        selectedIcon: Icon(AppIcons.settings, color: AppColors.darkPrimary),
        label: 'Settings',
      ),
    ];

    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          // Desktop / TV — persistent sidebar
          if (width >= 1024 && showNavigation) {
            return Row(
              children: [
                _buildSidebar(context, isDark, colorScheme),
                Expanded(
                  child: Column(
                    children: [
                      AppAppBar(title: title, actions: actions),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ],
            );
          }

          // Tablet — Navigation Rail
          if (width >= 600 && showNavigation) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _getSelectedIndex(),
                  onDestinationSelected: _onItemTapped,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor:
                      isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  selectedIconTheme:
                      IconThemeData(color: colorScheme.primary),
                  selectedLabelTextStyle:
                      AppTypography.getCaption(color: colorScheme.primary),
                  unselectedLabelTextStyle: AppTypography.getCaption(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  destinations: destinations
                      .map(
                        (d) => NavigationRailDestination(
                          icon: d.icon,
                          selectedIcon: d.selectedIcon,
                          label: Text(d.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Column(
                    children: [
                      AppAppBar(title: title, actions: actions),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ],
            );
          }

          // Mobile — full-screen with bottom nav
          return Column(
            children: [
              AppAppBar(title: title, actions: actions),
              Expanded(child: body),
            ],
          );
        },
      ),
      bottomNavigationBar: !showNavigation
          ? null
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 600) return const SizedBox.shrink();
                return NavigationBar(
                  selectedIndex: _getSelectedIndex(),
                  onDestinationSelected: _onItemTapped,
                  backgroundColor:
                      isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  indicatorColor:
                      colorScheme.primary.withValues(alpha: 0.12),
                  destinations: destinations,
                );
              },
            ),
    );
  }

  Widget _buildSidebar(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
    final selectedIndex = _getSelectedIndex();

    return Container(
      width: 260.0,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          right: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        LinearGradient(colors: AppColors.primaryGradient),
                  ),
                  child: const Icon(AppIcons.play,
                      color: Colors.white, size: 20.0),
                ),
                AppSpacing.widthSM,
                Text(
                  'StreamHub Pro',
                  style: AppTypography.getTitle(color: colorScheme.onSurface),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          AppSpacing.heightMD,

          // Navigation items
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              children: [
                _buildSidebarItem(
                  icon: AppIcons.dashboard,
                  label: 'Dashboard',
                  isSelected: selectedIndex == 0,
                  onTap: () => _onItemTapped(0),
                  colorScheme: colorScheme,
                ),
                AppSpacing.heightXXS,
                _buildSidebarItem(
                  icon: AppIcons.providers,
                  label: 'Providers',
                  isSelected: selectedIndex == 1,
                  onTap: () => _onItemTapped(1),
                  colorScheme: colorScheme,
                ),
                AppSpacing.heightXXS,
                _buildSidebarItem(
                  icon: AppIcons.settings,
                  label: 'Settings',
                  isSelected: selectedIndex == 2,
                  onTap: () => _onItemTapped(2),
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),

          // Footer / profile placeholder
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  AppIcons.profile,
                  size: 36.0,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                AppSpacing.widthSM,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Local User',
                        style:
                            AppTypography.getLabel(color: colorScheme.onSurface),
                      ),
                      Text(
                        'Offline Mode',
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.medium,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: AppRadius.medium,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.7),
              size: 22.0,
            ),
            AppSpacing.widthMD,
            Text(
              label,
              style: AppTypography.getLabel(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
