import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../data/repositories/provider_repository.dart';
import '../../modules/live_tv/controllers/live_tv_controller.dart';
import '../../modules/profiles/profile_controller.dart';
import '../../modules/provider_manager/provider_manager_controller.dart';
import 'sync_progress_bar.dart';
import 'tv_focusable.dart';

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
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  int _getSelectedIndex() {
    final route = Get.currentRoute;
    if (route == AppRoutes.search || route == AppRoutes.guideSearch) return 0;
    if (route == AppRoutes.home) return 1;
    if (route == AppRoutes.liveTV || route == AppRoutes.channelDetails) return 2;
    if (route == AppRoutes.movies ||
        route == AppRoutes.movieDetails ||
        route == AppRoutes.movieGenre ||
        route == AppRoutes.moviesCategory) {
      return 3;
    }
    if (route == AppRoutes.series ||
        route == AppRoutes.seriesDetails ||
        route == AppRoutes.seriesGenre ||
        route == AppRoutes.seriesCategory) {
      return 4;
    }
    if (route == AppRoutes.favorites) return 5;
    if (route == AppRoutes.multiView) return 6;
    if (route == AppRoutes.settings ||
        route == AppRoutes.providerManager ||
        route == AppRoutes.providerForm ||
        route == AppRoutes.providerDetails ||
        route == AppRoutes.profile ||
        route == AppRoutes.storage ||
        route == AppRoutes.about) {
      return 7;
    }
    return 1;
  }

  void _onItemTapped(int index) {
    if (_getSelectedIndex() == index) return;

    switch (index) {
      case 0:
        Get.offAllNamed(AppRoutes.search);
        break;
      case 1:
        Get.offAllNamed(AppRoutes.home);
        break;
      case 2:
        Get.offAllNamed(AppRoutes.liveTV);
        break;
      case 3:
        Get.offAllNamed(AppRoutes.movies);
        break;
      case 4:
        Get.offAllNamed(AppRoutes.series);
        break;
      case 5:
        Get.offAllNamed(AppRoutes.favorites);
        break;
      case 6:
        Get.offAllNamed(AppRoutes.multiView);
        break;
      case 7:
        Get.offAllNamed(AppRoutes.settings);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main Body pushed by 96px (collapsed sidebar width)
          Positioned.fill(
            left: 96.0,
            child: Focus(
              autofocus: true,
              child: Column(
                children: [
                  const SyncProgressBar(),
                  Expanded(child: widget.body),
                ],
              ),
            ),
          ),

          // Sidebar Navigation (Floats on top, expands on focus/hover)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Focus(
              onFocusChange: (hasFocus) {
                if (mounted && _isExpanded != hasFocus) {
                  setState(() => _isExpanded = hasFocus);
                }
              },
              child: MouseRegion(
                onEnter: (_) {
                  if (mounted && !_isExpanded) {
                    setState(() => _isExpanded = true);
                  }
                },
                onExit: (_) {
                  if (mounted && _isExpanded) {
                    setState(() => _isExpanded = false);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: _isExpanded ? 270.0 : 96.0,
                  decoration: BoxDecoration(
                    color: const Color(0xEE0E1116),
                    border: Border(
                      right: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 32,
                        spreadRadius: -4,
                        offset: const Offset(8, 0),
                      ),
                    ],
                  ),
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
                      child: SizedBox(
                        width: _isExpanded ? 270.0 : 96.0,
                        child: _buildSidebarContent(),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Profile & Provider Header
        _buildProfileHeader(),

        const Divider(color: Colors.white10, height: 1),

        // 2. Navigation Items List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
            children: [
              // Search
              _buildNavItem(
                icon: Icons.search_rounded,
                label: 'Search',
                isSelected: selectedIndex == 0,
                onTap: () => _onItemTapped(0),
              ),
              const SizedBox(height: 4),

              // Home
              _buildNavItem(
                icon: AppIcons.home,
                label: 'Home',
                isSelected: selectedIndex == 1,
                onTap: () => _onItemTapped(1),
              ),
              const SizedBox(height: 4),

              // Live TV
              _buildNavItem(
                icon: AppIcons.liveTv,
                label: 'Live TV',
                isSelected: selectedIndex == 2,
                onTap: () => _onItemTapped(2),
              ),
              const SizedBox(height: 4),

              // VOD Movies
              _buildNavItem(
                icon: Icons.movie_creation_outlined,
                label: 'VOD Movies',
                isSelected: selectedIndex == 3,
                onTap: () => _onItemTapped(3),
              ),
              const SizedBox(height: 4),

              // TV Series
              _buildNavItem(
                icon: Icons.video_library_outlined,
                label: 'Series',
                isSelected: selectedIndex == 4,
                onTap: () => _onItemTapped(4),
              ),
              const SizedBox(height: 4),

              // Favorites
              _buildNavItem(
                icon: Icons.star_rounded,
                label: 'Favorites',
                isSelected: selectedIndex == 5,
                onTap: () => _onItemTapped(5),
                badgeWidget: _buildFavoritesBadge(),
              ),
              const SizedBox(height: 4),

              // Multi-View
              _buildNavItem(
                icon: Icons.grid_view_rounded,
                label: 'Multi-View',
                isSelected: selectedIndex == 6,
                onTap: () => _onItemTapped(6),
              ),
            ],
          ),
        ),

        const Divider(color: Colors.white10, height: 1),

        // 3. Live Digital Clock & Network Health
        _buildClockAndNetworkFooter(),

        // 4. Settings Item (Bottom Pinned)
        Padding(
          padding: const EdgeInsets.fromLTRB(10.0, 4.0, 10.0, 20.0),
          child: _buildNavItem(
            icon: AppIcons.settings,
            label: 'Settings',
            isSelected: selectedIndex == 7,
            onTap: () => _onItemTapped(7),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    final profileCtrl =
        Get.isRegistered<ProfileController>() ? Get.find<ProfileController>() : null;
    final providerCtrl =
        Get.isRegistered<ProviderManagerController>() ? Get.find<ProviderManagerController>() : null;
    final providerRepo =
        Get.isRegistered<ProviderRepository>() ? Get.find<ProviderRepository>() : null;

    final profileName = profileCtrl?.activeProfile.value?.displayName ??
        profileCtrl?.displayName.value ??
        'Primary User';
    
    final activeId = providerRepo?.activeProviderId.value ?? '';
    final matchedProvider = providerCtrl?.providers.firstWhereOrNull(
      (p) => p.id == activeId || p.name == activeId,
    );
    final providerName = matchedProvider?.name ??
        (providerCtrl?.providers.isNotEmpty == true
            ? providerCtrl!.providers.first.name
            : 'IPTV Premium');

    return TvFocusable(
      onTap: () => Get.toNamed(AppRoutes.profile),
      scale: 1.02,
      borderRadius: BorderRadius.circular(12),
      onFocusChange: (focused) {
        if (focused && !_isExpanded && mounted) {
          setState(() => _isExpanded = true);
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: _isExpanded ? 16.0 : 8.0,
          vertical: 18.0,
        ),
        child: Row(
          mainAxisAlignment: _isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Avatar with Online Pulse Dot
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryContainer],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      profileName.isNotEmpty ? profileName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676), // Online Green
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0E1116), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            if (_isExpanded) ...[
              const SizedBox(width: 14),
              Expanded(
                child: ClipRect(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: '● ',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 8,
                              ),
                            ),
                            TextSpan(
                              text: providerName,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildFavoritesBadge() {
    final liveCtrl =
        Get.isRegistered<LiveTVController>() ? Get.find<LiveTVController>() : null;
    if (liveCtrl == null) return null;

    return Obx(() {
      final count = liveCtrl.favorites.length;
      if (count == 0) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.7), width: 0.8),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    });
  }

  Widget _buildClockAndNetworkFooter() {
    final timeStr = DateFormat('hh:mm a').format(_currentTime);
    final shortTimeStr = DateFormat('HH:mm').format(_currentTime);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: _isExpanded ? 18.0 : 8.0,
        vertical: 8.0,
      ),
      child: _isExpanded
          ? Row(
              children: [
                const SizedBox(width: 4.0),
                const Icon(
                  Icons.wifi_rounded,
                  color: Color(0xFF00E676),
                  size: 16,
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wifi_rounded,
                  color: Color(0xFF00E676),
                  size: 14,
                ),
                const SizedBox(height: 2),
                Text(
                  shortTimeStr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? badgeWidget,
  }) {
    // Vibrant Red Accent for active selection on TV (Highly visible from 10-ft distance)
    const selectedRedBg = Color(0xFFE50914);
    const selectedRedBorder = Color(0xFFFF4D5A);

    return TvFocusable(
      onTap: onTap,
      scale: 1.04,
      borderRadius: BorderRadius.circular(10),
      focusColor: selectedRedBorder,
      onFocusChange: (focused) {
        if (focused && !_isExpanded && mounted) {
          setState(() => _isExpanded = true);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          vertical: _isExpanded ? 11.0 : 8.0,
          horizontal: _isExpanded ? 14.0 : 4.0,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedRedBg
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? selectedRedBorder
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedRedBg.withValues(alpha: 0.55),
                    blurRadius: 14,
                    spreadRadius: 1.0,
                  ),
                ]
              : null,
        ),
        child: _isExpanded
            // Expanded Mode: Horizontal Row with Icon, Title, and Badge
            ? Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(width: 6.0),
                  Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.white70,
                    size: 22.0,
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        letterSpacing: isSelected ? 0.3 : 0.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badgeWidget != null) ...[
                    badgeWidget,
                    const SizedBox(width: 4.0),
                  ],
                ],
              )
            // Collapsed Mode: Vertical Stack with Icon on Top and Text Below
            : SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          icon,
                          color: isSelected ? Colors.white : Colors.white70,
                          size: 24.0,
                        ),
                        if (badgeWidget != null)
                          Positioned(
                            top: -4,
                            right: -10,
                            child: badgeWidget,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 10.0,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
