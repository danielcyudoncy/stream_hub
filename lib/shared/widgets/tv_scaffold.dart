import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'sync_progress_bar.dart';

class TvScaffold extends StatefulWidget {
  final Widget body;

  const TvScaffold({
    super.key,
    required this.body,
  });

  @override
  State<TvScaffold> createState() => _TvScaffoldState();
}

class _TvScaffoldState extends State<TvScaffold> {
  bool _isExpanded = false;

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
    if (_getSelectedIndex() == index) return;
    
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main Body pushed by 96px (collapsed sidebar width)
          Positioned.fill(
            left: 96.0,
            child: Column(
              children: [
                const SyncProgressBar(),
                Expanded(child: widget.body),
              ],
            ),
          ),

          // Sidebar Navigation (Floats on top, expands on focus/hover)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Focus(
              onFocusChange: (hasFocus) {
                setState(() {
                  _isExpanded = hasFocus;
                });
              },
              child: MouseRegion(
                onEnter: (_) => setState(() => _isExpanded = true),
                onExit: (_) => setState(() => _isExpanded = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: _isExpanded ? 256.0 : 96.0,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.8),
                    border: Border(
                      right: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryContainer.withValues(alpha: 0.2),
                        blurRadius: 40,
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: 1.0,
                        child: OverflowBox(
                          minWidth: 256.0,
                          maxWidth: 256.0,
                          alignment: Alignment.centerLeft,
                          child: _buildSidebarContent(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent() {
    final selectedIndex = _getSelectedIndex();

    return Column(
      children: [
        // Brand Header
        Padding(
          padding: const EdgeInsets.only(top: 32.0, bottom: 48.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              AppSpacing.widthLG,
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceVariant,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Icon(AppIcons.profile, color: AppColors.primary, size: 28),
              ),
              AppSpacing.widthMD,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'IPTV Premium',
                      style: AppTypography.getTitle(color: AppColors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Cinematic Experience',
                      style: AppTypography.getLabel(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AppSpacing.widthMD,
            ],
          ),
        ),

        // Navigation Links
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            children: [
              _buildNavItem(
                icon: AppIcons.home,
                label: 'Home',
                isSelected: selectedIndex == 0,
                onTap: () => _onItemTapped(0),
              ),
              AppSpacing.heightSM,
              _buildNavItem(
                icon: AppIcons.liveTv,
                label: 'Live TV',
                isSelected: selectedIndex == 1,
                onTap: () => _onItemTapped(1),
              ),
              AppSpacing.heightSM,
              _buildNavItem(
                icon: Icons.movie_creation_outlined,
                label: 'VOD',
                isSelected: selectedIndex == 2,
                onTap: () => _onItemTapped(2),
              ),
              AppSpacing.heightSM,
              _buildNavItem(
                icon: Icons.video_library_outlined,
                label: 'Series',
                isSelected: selectedIndex == 3,
                onTap: () => _onItemTapped(3),
              ),
            ],
          ),
        ),

        // Settings (Bottom)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 32.0),
          child: _buildNavItem(
            icon: AppIcons.settings,
            label: 'Settings',
            isSelected: selectedIndex == 4,
            onTap: () => _onItemTapped(4),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.horizontal(
        left: Radius.circular(4),
        right: Radius.circular(8),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(4),
            right: Radius.circular(8),
          ),
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 4.0,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(width: 36.0), // Center the icon in the 96px collapsed state
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 24.0,
            ),
            AppSpacing.widthMD,
            Expanded(
              child: Text(
                label,
                style: AppTypography.getTitle(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
