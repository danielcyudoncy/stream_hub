import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/helpers/platform_helper.dart';
import '../../core/media/enums/playback_state.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/responsive_helper.dart';
import '../../modules/player/controllers/player_controller.dart';
import '../../modules/player/pages/floating_player_page.dart';
import '../../modules/player/pages/mini_player_page.dart';
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
  final Widget? leading;
  final bool? showBackButton;
  final VoidCallback? onBack;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.showNavigation = true,
    this.showAppBar = true,
    this.floatingActionButton,
    this.leading,
    this.showBackButton,
    this.onBack,
  });

  int _getSelectedIndex() {
    final route = Get.currentRoute;
    if (route == AppRoutes.home) return 0;
    if (route == AppRoutes.liveTV || route == AppRoutes.channelDetails) {
      return 1;
    }
    if (route == AppRoutes.freeLiveTV) return 2;
    if (route == AppRoutes.movies || route == AppRoutes.movieDetails) return 3;
    if (route == AppRoutes.series || route == AppRoutes.seriesDetails) return 4;
    if (route == AppRoutes.favorites) return 5;
    return 0;
  }

  static const _rootRoutes = [
    AppRoutes.home, // 0
    AppRoutes.liveTV, // 1
    AppRoutes.freeLiveTV, // 2
    AppRoutes.movies, // 3
    AppRoutes.series, // 4
    AppRoutes.favorites, // 5
  ];

  void _onItemTapped(int index) {
    if (index < 0 || index >= _rootRoutes.length) return;
    final targetRoute = _rootRoutes[index];
    if (Get.currentRoute == targetRoute) return;

    Get.offAllNamed(targetRoute);
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
        icon: Icon(Icons.tv_rounded),
        selectedIcon: Icon(Icons.tv_rounded),
        label: 'Free TV',
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
        icon: Icon(Icons.star_rounded),
        selectedIcon: Icon(Icons.star_rounded),
        label: 'Favorites',
      ),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: floatingActionButton,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isTvMode =
              PlatformHelper.isTV || ResponsiveHelper.isTV(context);

          // Desktop / TV — persistent sidebar
          if ((width >= 1024 || isTvMode) && showNavigation) {
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
                    selectedIconTheme: IconThemeData(
                      color: colorScheme.primary,
                    ),
                    selectedLabelTextStyle: AppTypography.getCaption(
                      color: colorScheme.primary,
                    ),
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
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            if (showAppBar)
                              AppAppBar(
                                title: title,
                                actions: actions,
                                leading: leading,
                                showBackButton: showBackButton ?? false,
                                onBack: onBack,
                              ),
                            const SyncProgressBar(),
                            Expanded(child: body),
                          ],
                        ),
                        if (Get.isRegistered<PlayerController>() &&
                            Get.currentRoute != AppRoutes.fullscreenPlayer &&
                            Get.currentRoute != AppRoutes.liveTV)
                          Obx(() {
                            final state =
                                Get.find<PlayerController>().stateRx.value;
                            if (state == PlaybackState.idle ||
                                state == PlaybackState.stopped) {
                              return const SizedBox.shrink();
                            }
                            return const FloatingPlayerPage();
                          }),
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
              if (showAppBar)
                AppAppBar(
                  title: title,
                  actions: actions,
                  leading: leading,
                  showBackButton: showBackButton ?? false,
                  onBack: onBack,
                ),
              const SyncProgressBar(),
              Expanded(child: body),
            ],
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final isTvMode =
              PlatformHelper.isTV || ResponsiveHelper.isTV(context);
          if (constraints.maxWidth >= 600 || isTvMode) {
            return const SizedBox.shrink();
          }

          final hasPlayerController = Get.isRegistered<PlayerController>();
          final isFullscreenOrLive =
              Get.currentRoute == AppRoutes.fullscreenPlayer ||
              Get.currentRoute == AppRoutes.liveTV;

          final showMiniPlayer =
              hasPlayerController &&
              !isFullscreenOrLive &&
              Get.find<PlayerController>().stateRx.value !=
                  PlaybackState.idle &&
              Get.find<PlayerController>().stateRx.value !=
                  PlaybackState.stopped;

          if (!showNavigation && !hasPlayerController) {
            return const SizedBox.shrink();
          }

          return SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showMiniPlayer)
                  Obx(() {
                    final state = Get.find<PlayerController>().stateRx.value;
                    if (state == PlaybackState.idle ||
                        state == PlaybackState.stopped) {
                      return const SizedBox.shrink();
                    }
                    return const MiniPlayerPage();
                  }),
                if (showNavigation)
                  ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                      child: NavigationBarTheme(
                        data: NavigationBarThemeData(
                          labelTextStyle: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return AppTypography.getCaption(
                                color: colorScheme.primary,
                              );
                            }
                            return AppTypography.getCaption(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            );
                          }),
                          iconTheme: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return IconThemeData(color: colorScheme.primary);
                            }
                            return IconThemeData(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            );
                          }),
                        ),
                        child: NavigationBar(
                          selectedIndex: _getSelectedIndex(),
                          onDestinationSelected: _onItemTapped,
                          backgroundColor: colorScheme.surface.withValues(
                            alpha: 0.8,
                          ),
                          surfaceTintColor: Colors.transparent,
                          indicatorColor: colorScheme.primaryContainer
                              .withValues(alpha: 0.2),
                          destinations: destinations,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
