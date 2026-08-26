import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import 'app_app_bar.dart';
import 'sync_progress_bar.dart';
import 'tv_scaffold.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool showNavigation;
  final bool showAppBar;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.showNavigation = true,
    this.showAppBar = true,
    this.floatingActionButton,
  });

  int _getSelectedIndex() {
    final route = Get.currentRoute;
    if (route == AppRoutes.home) return 0;
    if (route == AppRoutes.liveTV) return 1;
    if (route == AppRoutes.movies || route == AppRoutes.movieDetails) return 2;
    if (route == AppRoutes.series || route == AppRoutes.seriesDetails) return 3;
    if (route == AppRoutes.settings ||
        route == AppRoutes.providerManager ||
        route == AppRoutes.providerForm ||
        route == AppRoutes.providerDetails) {
      return 4;
    }
    return 0;
  }

  void _onItemTapped(int index) {
    if (_getSelectedIndex() == index) {
      return;
    }
    switch (index) {
      case 0:
        Get.offAllNamed(AppRoutes.home);
        break;
      case 1:
        Get.offAllNamed(AppRoutes.liveTV);
        break;
      case 2:
        Get.offAllNamed(AppRoutes.movies);
        break;
      case 3:
        Get.offAllNamed(AppRoutes.series);
        break;
      case 4:
        Get.offAllNamed(AppRoutes.settings);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final List<NavigationDestination> destinations = [
      const NavigationDestination(
        icon: Icon(AppIcons.home),
        selectedIcon: Icon(AppIcons.home),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(AppIcons.liveTv),
        selectedIcon: Icon(AppIcons.liveTv),
        label: 'Live TV',
      ),
      const NavigationDestination(
        icon: Icon(Icons.movie_creation_outlined),
        selectedIcon: Icon(Icons.movie),
        label: 'VOD',
      ),
      const NavigationDestination(
        icon: Icon(Icons.video_library_outlined),
        selectedIcon: Icon(Icons.video_library),
        label: 'Series',
      ),
      const NavigationDestination(
        icon: Icon(AppIcons.settings),
        selectedIcon: Icon(AppIcons.settings),
        label: 'Settings',
      ),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: floatingActionButton,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          // Desktop / TV — persistent sidebar
          if (width >= 1024 && showNavigation) {
            return TvScaffold(body: body);
          }

          // Tablet — Navigation Rail
          if (width >= 600 && showNavigation) {
            return FocusTraversalGroup(
              policy: WidgetOrderTraversalPolicy(),
              child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _getSelectedIndex(),
                  onDestinationSelected: _onItemTapped,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: colorScheme.surface,
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
                      if (showAppBar) AppAppBar(title: title, actions: actions),
                      const SyncProgressBar(),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

          // Mobile — full-screen with bottom nav
          return Column(
            children: [
              if (showAppBar) AppAppBar(title: title, actions: actions),
              const SyncProgressBar(),
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
                return ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                    child: NavigationBarTheme(
                      data: NavigationBarThemeData(
                        labelTextStyle: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return AppTypography.getCaption(color: colorScheme.primary);
                          }
                          return AppTypography.getCaption(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          );
                        }),
                        iconTheme: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return IconThemeData(color: colorScheme.primary);
                          }
                          return IconThemeData(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          );
                        }),
                      ),
                      child: NavigationBar(
                        selectedIndex: _getSelectedIndex(),
                        onDestinationSelected: _onItemTapped,
                        backgroundColor: colorScheme.surface.withValues(alpha: 0.8),
                        surfaceTintColor: Colors.transparent,
                        indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.2),
                        destinations: destinations,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
