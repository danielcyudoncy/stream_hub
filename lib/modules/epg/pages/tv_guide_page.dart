// modules/epg/pages/tv_guide_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/core/services/tv_navigation_service.dart';
import 'package:stream_hub/core/utils/date_formatter.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/core/utils/responsive_helper.dart';
import 'package:stream_hub/data/models/channel.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/modules/epg/controllers/guide_controller.dart';
import 'package:stream_hub/modules/epg/models/epg_channel.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/modules/epg/widgets/guide_grid.dart';
import 'package:stream_hub/modules/epg/widgets/mini_guide.dart';
import 'package:stream_hub/modules/epg/widgets/channel_column.dart';
import 'package:stream_hub/modules/live_tv/controllers/live_tv_controller.dart';
import 'package:stream_hub/modules/live_tv/widgets/live_tv_channel_card.dart';
import 'package:stream_hub/modules/live_tv/widgets/live_tv_embedded_player.dart';
import 'package:stream_hub/modules/live_tv/widgets/live_tv_skeleton.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/empty_view.dart';
import 'package:stream_hub/shared/loading/loading_indicator.dart';
import 'package:stream_hub/shared/widgets/error_view.dart';
import 'package:stream_hub/shared/widgets/provider_selector_button.dart';
import 'package:stream_hub/shared/widgets/tv_body_focus_registry.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

class TVGuidePage extends StatefulWidget {
  const TVGuidePage({super.key});

  @override
  State<TVGuidePage> createState() => _TVGuidePageState();
}

class _TVGuidePageState extends State<TVGuidePage> {
  GuideController get controller => Get.find<GuideController>();

  final GlobalKey _guideRootKey = GlobalKey(debugLabel: 'TvGuideRootKey');
  final GlobalKey<LiveTvEmbeddedPlayerState> _embeddedPlayerKey =
      GlobalKey<LiveTvEmbeddedPlayerState>();
  final FocusNode _viewModeFocusNode = FocusNode(debugLabel: 'TvGuide_ViewMode');
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'TvGuide_Search');
  final FocusNode _refreshFocusNode = FocusNode(debugLabel: 'TvGuide_Refresh');
  Worker? _selectedViewWorker;

  final Map<String, FocusNode> _categoryFocusNodes = <String, FocusNode>{};
  String? _lastFocusedCategory;

  FocusNode _getCategoryFocusNode(String cat) {
    return _categoryFocusNodes.putIfAbsent(
      cat,
      () => FocusNode(debugLabel: 'TvGuide_Category_$cat'),
    );
  }

  void _focusActiveCategory() {
    if (!mounted) return;
    final liveCtrl = Get.isRegistered<LiveTVController>()
        ? Get.find<LiveTVController>()
        : null;
    final selectedCat = liveCtrl?.selectedCategory.value ??
        controller.selectedCategory.value;
    final catToFocus = _lastFocusedCategory ??
        (selectedCat.isNotEmpty ? selectedCat : 'All Channels');
    final node = _categoryFocusNodes[catToFocus] ??
        _categoryFocusNodes.values.firstOrNull;
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
    }
  }

  bool _isFocusInGuideBody(FocusNode focus) {
    final ctx = focus.context;
    final guideCtx = _guideRootKey.currentContext;
    if (ctx == null || guideCtx == null) return false;
    var inside = false;
    ctx.visitAncestorElements((el) {
      if (el == guideCtx) {
        inside = true;
        return false;
      }
      return true;
    });
    return inside;
  }

  void _initialFocus() {
    if (!mounted) return;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || !_isFocusInGuideBody(primary)) {
      if (Get.isRegistered<TvNavigationService>()) {
        final restored = TvNavigationService.to.restoreFocus('live_channels');
        if (restored) return;
      }
      _focusActiveCategory();
    }
  }

  KeyEventResult _handleShowcaseKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (node == _refreshFocusNode &&
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        final playerState = _embeddedPlayerKey.currentState;
        if (playerState != null) {
          playerState.focusPlayer();
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _focusActiveCategory();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleCategoryKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (Get.isRegistered<TvNavigationService>()) {
        final restored = TvNavigationService.to.restoreFocus('live_channels');
        if (restored) return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_viewModeFocusNode.canRequestFocus) {
        _viewModeFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    final liveCtrl = Get.isRegistered<LiveTVController>()
        ? Get.find<LiveTVController>()
        : null;
    if (liveCtrl != null) {
      _selectedViewWorker = ever(liveCtrl.selectedView, (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _initialFocus();
        });
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialFocus();
    });
  }

  @override
  void dispose() {
    _selectedViewWorker?.dispose();
    _viewModeFocusNode.dispose();
    _searchFocusNode.dispose();
    _refreshFocusNode.dispose();
    for (final node in _categoryFocusNodes.values) {
      node.dispose();
    }
    _categoryFocusNodes.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTV = ResponsiveHelper.isTV(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final liveCtrl = Get.isRegistered<LiveTVController>()
        ? Get.find<LiveTVController>()
        : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (liveCtrl != null && !liveCtrl.isLoading.value) {
        if (liveCtrl.channels.isEmpty) {
          liveCtrl.reloadLiveTVData();
        }
        liveCtrl.handleNavigationArguments();
        _initialFocus();
      }
    });

    // If on phone/small screen, show the mobile layout
    if (!isTV && !isDesktop) {
      return AppScaffold(
        title: 'TV Guide',
        actions: [
          TvFocusable(
            onTap: () {
              controller.refreshGuide();
              liveCtrl?.reloadLiveTVData();
            },
            scale: 1.0,
            borderRadius: BorderRadius.circular(8),
            child: const IconButton(icon: Icon(Icons.refresh), onPressed: null),
          ),
          TvFocusable(
            onTap: () => Get.toNamed(AppRoutes.guideSearch),
            scale: 1.0,
            borderRadius: BorderRadius.circular(8),
            child: const IconButton(icon: Icon(Icons.search), onPressed: null),
          ),
        ],
        body: Column(
          children: [
            _buildTimeNavigation(context),
            _buildMobileCategoryBar(context, liveCtrl),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value ||
                    (liveCtrl != null && liveCtrl.isLoading.value)) {
                  return const Center(child: LoadingIndicator());
                }
                if (controller.error.value.isNotEmpty &&
                    (liveCtrl == null || liveCtrl.channels.isEmpty)) {
                  return ErrorView(
                    message: controller.error.value,
                    onRetry: () {
                      controller.loadGuide();
                      liveCtrl?.reloadLiveTVData();
                    },
                  );
                }
                return _buildMobileLayout(context, liveCtrl);
              }),
            ),
          ],
        ),
      );
    }

    // TV Layout (Cinematic Neon)

    return Obx(() {
      if (liveCtrl != null && liveCtrl.isFullscreenMode.value) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            liveCtrl.exitFullscreen();
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SizedBox.expand(
              child: LiveTvEmbeddedPlayer(
                key: _embeddedPlayerKey,
                controller: liveCtrl,
                isFullscreen: true,
                autofocus: true,
              ),
            ),
          ),
        );
      }

      return AppScaffold(
        title: 'TV Guide',
        showAppBar: false,
        body: KeyedSubtree(
          key: _guideRootKey,
          child: Obx(() {
            if (liveCtrl != null &&
                liveCtrl.isLoading.value &&
                liveCtrl.channels.isEmpty &&
                liveCtrl.filteredChannels.isEmpty) {
              return const LiveTvSkeleton();
            }

            final isTimeline = liveCtrl?.selectedView.value == 'timeline';
            if (isTimeline) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Sleek Compact Header matching Xfinity (Brand, Filter, Mini Player)
                  _buildTimelineTopBar(context, liveCtrl),

                  // 2. Full-Screen Guide Grid taking all remaining height
                  Expanded(
                    child: _buildTVLayout(context),
                  ),

                  // 3. Status Bar (Time, Weather, Remote Key Hints)
                  _buildRemoteLegendBar(),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Showcase: Channel Info on Left, Large 16:9 Live Player on Right
                _buildTopShowcase(context),

                // 2. Full-Width Category Rail Below the Player
                _buildCategoryBar(context),

                AppSpacing.heightXS,

                // 3. Full Guide / Channel Catalog Grid Below
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: _buildTVLayout(context),
                  ),
                ),

                // 4. TV Remote D-Pad Navigation Legend Bar
                _buildRemoteLegendBar(),
              ],
            );
          }),
        ),
      );
    });
  }

  void _showCategoryFilterDialog(BuildContext context, LiveTVController? liveCtrl) {
    if (liveCtrl == null) return;
    final categories = liveCtrl.categories.isNotEmpty
        ? liveCtrl.categories
        : (controller.categories.isNotEmpty
            ? controller.categories
            : ['All Channels']);
    final selectedCat = liveCtrl.selectedCategory.value;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: const Color(0xFF161920),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white24, width: 1),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360, maxHeight: 480),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.filter_list, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Filter Channels by Genre',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: categories.length,
                      itemBuilder: (ctx, index) {
                        final cat = categories[index];
                        final isSelected =
                            (selectedCat.isEmpty && index == 0) || selectedCat == cat;
                        return ListTile(
                          dense: true,
                          title: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: AppColors.primary, size: 18)
                              : null,
                          onTap: () {
                            liveCtrl.setCategory(cat);
                            controller.setCategory(cat);
                            Navigator.of(dialogCtx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineTopBar(BuildContext context, LiveTVController? liveCtrl) {
    final providerRepo = Get.isRegistered<ProviderRepository>()
        ? Get.find<ProviderRepository>()
        : null;

    final currentProvider = liveCtrl?.selectedProvider.value ??
        providerRepo?.activeProviderId.value ??
        '';

    final activeCategory = liveCtrl?.selectedCategory.value ?? 'All Channels';
    final hasCategoryFilter = activeCategory.isNotEmpty && activeCategory != 'All Channels';

    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 8.0),
      color: const Color(0xFF0F1218),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Brand & Primary Actions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // StreamHub | Guide Brand Header + ▲ FILTER
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'streamhub',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        '|',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    Text(
                      'Guide',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        shadows: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 8.0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Exact Xfinity "▲ FILTER" action button
                    TvFocusable(
                      focusColor: const Color(0xFFFFD54F),
                      onKeyEvent: _handleShowcaseKeyEvent,
                      onTap: () => _showCategoryFilterDialog(context, liveCtrl),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: hasCategoryFilter
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : const Color(0xFF232832),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: hasCategoryFilter
                                ? AppColors.primary
                                : Colors.white24,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 13,
                              color: Color(0xFFFFD54F),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              hasCategoryFilter ? 'FILTER: $activeCategory' : 'FILTER',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Controls Row: View Mode Toggle, Provider, Search, Refresh
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (currentProvider.isNotEmpty) ...[
                      ProviderSelectorButton(
                        selectedProviderId: currentProvider,
                        onSelectProvider: (newProviderId) {
                          liveCtrl?.setProvider(newProviderId);
                          controller.setProvider(newProviderId);
                          providerRepo?.setActiveProviderId(newProviderId);
                        },
                        sheetTitle: 'TV Guide Provider',
                        isCompact: true,
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (liveCtrl != null)
                      TvFocusable(
                        focusNode: _viewModeFocusNode,
                        onKeyEvent: _handleShowcaseKeyEvent,
                        onTap: () {
                          liveCtrl.setView('grid');
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF232832),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.grid_view, size: 13, color: Colors.white70),
                              SizedBox(width: 5),
                              Text(
                                'Grid View',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                    TvFocusable(
                      focusNode: _searchFocusNode,
                      onKeyEvent: _handleShowcaseKeyEvent,
                      onTap: () => Get.toNamed(AppRoutes.search),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF232832),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(Icons.search, size: 14, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TvFocusable(
                      focusNode: _refreshFocusNode,
                      onKeyEvent: _handleShowcaseKeyEvent,
                      onTap: () {
                        controller.refreshGuide();
                        liveCtrl?.refresh();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF232832),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(Icons.refresh, size: 14, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right: 16:9 Live Embedded Mini-Player
          if (liveCtrl != null)
            Container(
              width: 220,
              height: 124,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white24,
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 15,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LiveTvEmbeddedPlayer(
                  key: _embeddedPlayerKey,
                  controller: liveCtrl,
                  isFullscreen: false,
                  autofocus: false,
                  onMoveLeft: () => _refreshFocusNode.requestFocus(),
                  onMoveDown: _focusActiveCategory,
                  onMoveUp: () => _refreshFocusNode.requestFocus(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopShowcase(BuildContext context) {
    final liveCtrl = Get.isRegistered<LiveTVController>()
        ? Get.find<LiveTVController>()
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xs,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTimeline = liveCtrl?.selectedView.value == 'timeline';
          final playerWidth = isTimeline
              ? (constraints.maxWidth * 0.35).clamp(240.0, 360.0)
              : (constraints.maxWidth * 0.42).clamp(280.0, 440.0);
          final playerHeight = playerWidth * (9.0 / 16.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Pane: Header and Active Channel Information Showcase
              Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Top Action Row: Title, Today Badge, View Mode Switch, Search, Refresh
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'streamhub',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6.0),
                                child: Text(
                                  '|',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              ),
                              Text(
                                'Guide',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                  shadows: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 8.0,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // Exact Xfinity "▲ FILTER" action button
                          TvFocusable(
                            focusColor: const Color(0xFFFFD54F),
                            onKeyEvent: _handleShowcaseKeyEvent,
                            onTap: _focusActiveCategory,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.15),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 13,
                                    color: Color(0xFFFFD54F),
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'FILTER',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dual View Mode Toggle Button (Grid ↔ Timeline)
                    if (liveCtrl != null)
                      Obx(() {
                        final isTimeline =
                            liveCtrl.selectedView.value == 'timeline';
                        final colorScheme = Theme.of(context).colorScheme;
                        return TvFocusable(
                          focusNode: _viewModeFocusNode,
                          onKeyEvent: _handleShowcaseKeyEvent,
                          onTap: () {
                            _viewModeFocusNode.requestFocus();
                            liveCtrl.setView(
                              isTimeline ? 'grid' : 'timeline',
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isTimeline
                                    ? colorScheme.primary
                                    : colorScheme.outline.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isTimeline
                                      ? Icons.grid_view_rounded
                                      : Icons.view_timeline_outlined,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isTimeline ? 'Grid View' : 'Timeline EPG',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    AppSpacing.widthSM,
                    TvFocusable(
                      focusNode: _searchFocusNode,
                      onKeyEvent: _handleShowcaseKeyEvent,
                      onTap: () => Get.toNamed(AppRoutes.guideSearch),
                      scale: 1.15,
                      borderRadius: BorderRadius.circular(24),
                      child: IconButton(
                        icon: const Icon(Icons.search),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        onPressed: null,
                      ),
                    ),
                    AppSpacing.widthSM,
                    TvFocusable(
                      focusNode: _refreshFocusNode,
                      onKeyEvent: _handleShowcaseKeyEvent,
                      onTap: () => controller.refreshGuide(),
                      scale: 1.15,
                      borderRadius: BorderRadius.circular(24),
                      child: IconButton(
                        icon: const Icon(Icons.refresh),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        onPressed: null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 2. Active Playing / Focused Channel Showcase Info with Live Progress
                if (liveCtrl != null)
                  Obx(() {
                    final active =
                        liveCtrl.activePlayingChannel.value ??
                        liveCtrl.featuredChannel.value ??
                        (liveCtrl.channels.isNotEmpty
                            ? liveCtrl.channels.first
                            : null);

                    if (active == null) {
                      return const SizedBox(height: 100);
                    }

                    final categoryName =
                        active.metadata['category_name']?.toString() ??
                        (active.genres.isNotEmpty
                            ? active.genres.first
                            : 'Live TV');
                    final resolution =
                        active.metadata['resolution']?.toString() ?? 'HD';
                    final description =
                        active.description ??
                        active.subtitle ??
                        'Live Broadcast';

                    final now = DateTime.now();
                    final guideCtrl = Get.isRegistered<GuideController>()
                        ? Get.find<GuideController>()
                        : null;
                    final guidePrograms = guideCtrl?.programs ?? <EPGProgram>[];
                    final currentProgram = guidePrograms.firstWhereOrNull(
                      (p) => p.channelId == active.id && p.isCurrentlyPlaying,
                    );
                    final nextProgram = guidePrograms.firstWhereOrNull(
                      (p) =>
                          p.channelId == active.id && p.startTime.isAfter(now),
                    );
                    final double progPercent = currentProgram != null
                        ? (now.difference(currentProgram.startTime).inSeconds /
                                  (currentProgram.endTime
                                              .difference(
                                                currentProgram.startTime,
                                              )
                                              .inSeconds >
                                          0
                                      ? currentProgram.endTime
                                            .difference(
                                              currentProgram.startTime,
                                            )
                                            .inSeconds
                                      : 1))
                              .clamp(0.0, 1.0)
                        : 0.35;

                    final colorScheme = Theme.of(context).colorScheme;
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Channel Logo or Avatar
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: colorScheme.outline.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Center(
                                  child:
                                      (active.poster != null &&
                                          active.poster!.isNotEmpty)
                                      ? Image.network(
                                          active.poster!,
                                          width: 38,
                                          height: 38,
                                          errorBuilder: (_, _, _) => Icon(
                                            Icons.tv,
                                            color: colorScheme.onSurface,
                                          ),
                                        )
                                      : Text(
                                          active.title.isNotEmpty
                                              ? active.title
                                                    .substring(0, 1)
                                                    .toUpperCase()
                                              : 'TV',
                                          style: AppTypography.getTitle(
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                ),
                              ),
                              AppSpacing.widthMD,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            active.title,
                                            style:
                                                AppTypography.getHeadline(
                                                  color: colorScheme.onSurface,
                                                ).copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primaryContainer
                                                .withValues(alpha: 0.4),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                          child: Text(
                                            resolution,
                                            style: TextStyle(
                                              color: colorScheme.primary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      categoryName,
                                      style: AppTypography.getLabel(
                                        color: colorScheme.onSurfaceVariant,
                                      ).copyWith(fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Live Progress Bar & Program details
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  currentProgram?.title ?? description,
                                  style:
                                      AppTypography.getBody(
                                        color: colorScheme.onSurface,
                                      ).copyWith(
                                        fontSize: 13,
                                        fontWeight: currentProgram != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (currentProgram != null)
                                Text(
                                  DateFormatter.formatTimeRange(
                                    currentProgram.startTime,
                                    currentProgram.endTime,
                                  ),
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progPercent,
                              minHeight: 3.0,
                              backgroundColor: colorScheme.outline.withValues(
                                alpha: 0.15,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary,
                              ),
                            ),
                          ),
                          if (nextProgram != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Up Next: ${nextProgram.title} (${DateFormat('HH:mm').format(nextProgram.startTime)})',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          // Right Pane: Prominent 16:9 Live Mini-Player
          if (liveCtrl != null) ...[
            AppSpacing.widthLG,
            Container(
              width: playerWidth,
              height: playerHeight,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                 child: LiveTvEmbeddedPlayer(
                   key: _embeddedPlayerKey,
                   controller: liveCtrl,
                   isFullscreen: false,
                   autofocus: false,
                   onMoveLeft: () => _refreshFocusNode.requestFocus(),
                   onMoveDown: _focusActiveCategory,
                   onMoveUp: () => _refreshFocusNode.requestFocus(),
                 ),
               ),
             ),
            ],
          ],
        );
        },
      ),
    );
  }

  Widget _buildCategoryBar(BuildContext context) {
    final liveCtrl = Get.isRegistered<LiveTVController>()
        ? Get.find<LiveTVController>()
        : null;
    final providerRepo = Get.isRegistered<ProviderRepository>()
        ? Get.find<ProviderRepository>()
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs,
      ),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            if (liveCtrl != null || providerRepo != null)
              Obx(() {
                final currentProvider =
                    liveCtrl?.selectedProvider.value ??
                    providerRepo?.activeProviderId.value ??
                    '';
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: ProviderSelectorButton(
                    selectedProviderId: currentProvider,
                    onSelectProvider: (newProviderId) {
                      liveCtrl?.setProvider(newProviderId);
                      controller.setProvider(newProviderId);
                      providerRepo?.setActiveProviderId(newProviderId);
                    },
                    sheetTitle: 'TV Guide Provider',
                    isCompact: true,
                  ),
                );
              }),
            Expanded(
              child: Obx(() {
                final categories =
                    liveCtrl != null && liveCtrl.categories.isNotEmpty
                    ? liveCtrl.categories
                    : (controller.categories.isNotEmpty
                          ? controller.categories
                          : ['All Channels']);

                final selectedCat =
                    liveCtrl?.selectedCategory.value ??
                    controller.selectedCategory.value;

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => AppSpacing.widthSM,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected =
                        (selectedCat.isEmpty && index == 0) ||
                        selectedCat == cat;
                    final focusNode = _getCategoryFocusNode(cat);
                    return _buildFilterPill(
                      cat,
                      isSelected,
                      () {
                        liveCtrl?.setCategory(cat);
                        controller.setCategory(cat);
                      },
                      focusNode: focusNode,
                      onFocusChange: (hasKeyboardFocus) {
                        if (hasKeyboardFocus) {
                          _lastFocusedCategory = cat;
                        }
                      },
                      onKeyEvent: (node, event) {
                        if (index == 0) {
                          final result =
                              _openSidebarOnLeft(context)(node, event);
                          if (result == KeyEventResult.handled) return result;
                        }
                        return _handleCategoryKeyEvent(node, event);
                      },
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  FocusOnKeyEventCallback _openSidebarOnLeft(BuildContext context) {
    return (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        final registry = TvBodyFocusRegistry.maybeOf(context);
        if (registry != null) {
          registry.openSidebar?.call();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
  }

  Widget _buildFilterPill(
    String label,
    bool isSelected,
    VoidCallback onTap, {
    FocusNode? focusNode,
    ValueChanged<bool>? onFocusChange,
    FocusOnKeyEventCallback? onKeyEvent,
  }) {
    return TvFocusable(
      focusNode: focusNode,
      onFocusChange: onFocusChange,
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      onKeyEvent: onKeyEvent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style:
                AppTypography.getLabel(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ).copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildTVLayout(BuildContext context) {
    final liveCtrl = Get.isRegistered<LiveTVController>()
        ? Get.find<LiveTVController>()
        : null;
    final isTimeline = liveCtrl?.selectedView.value == 'timeline';

    final content = Obx(() {
      if (liveCtrl != null && liveCtrl.isLoading.value) {
        return const Center(child: LoadingIndicator());
      }

      // TV Live Channel Catalog Grid based on selected category & filters
      List<MediaItem> channels = <MediaItem>[];
      if (liveCtrl != null) {
        if (liveCtrl.filteredChannels.isNotEmpty) {
          channels = liveCtrl.filteredChannels.toList();
        } else if (liveCtrl.channels.isNotEmpty &&
            (liveCtrl.selectedCategory.value == 'All Channels' ||
                liveCtrl.selectedCategory.value.isEmpty)) {
          channels = liveCtrl.channels.toList();
        }
      }
      if (channels.isEmpty && controller.channels.isNotEmpty) {
        channels = controller.channels.toList();
      }

      if (channels.isNotEmpty) {
        if (isTimeline) {
          return _buildTimelineEpgView(channels, liveCtrl!);
        }
        return _buildTvChannelCatalogGrid(channels, liveCtrl!);
      }

      if (liveCtrl != null &&
          liveCtrl.channels.isEmpty &&
          controller.channels.isEmpty) {
        return const EmptyView(
          title: 'No Live Channels Available',
          description:
              'Connect an IPTV provider to start watching Live TV.',
        );
      }

      if (channels.isEmpty &&
          liveCtrl != null &&
          liveCtrl.channels.isNotEmpty &&
          liveCtrl.selectedCategory.value != 'All Channels') {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tv_off,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              AppSpacing.heightMD,
              Text(
                'No channels in "${liveCtrl.selectedCategory.value}"',
                style: AppTypography.getHeadline(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              AppSpacing.heightMD,
              ElevatedButton.icon(
                onPressed: () => liveCtrl.setCategory('All Channels'),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Show All Channels'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor:
                      Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        );
      }

      return const EmptyView(
        title: 'No Live Channels Available',
        description:
            'Connect an IPTV provider to start watching Live TV.',
      );
    });

    if (isTimeline) {
      return content;
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: content,
        ),
      ),
    );
  }

  Widget _buildTvChannelCatalogGrid(
    List<MediaItem> channels,
    LiveTVController liveCtrl,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 16 / 10,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final item = channels[index];
        return Obx(() {
          final isPlaying = liveCtrl.activePlayingChannel.value?.id == item.id;
          return LiveTvChannelCard(
            channel: item,
            isPlaying: isPlaying,
            regionId: 'live_channels',
            itemId: item.id,
            itemIndex: index,
            onMoveUp: index < 4 ? _focusActiveCategory : null,
            onTap: isPlaying
                ? liveCtrl.expandToFullscreen
                : () => liveCtrl.openChannel(item),
            onFavorite: () => liveCtrl.toggleFavorite(item),
          );
        });
      },
    );
  }

  Widget _buildTimelineEpgView(
    List<MediaItem> channels,
    LiveTVController liveCtrl,
  ) {
    final List<EPGChannel> epgChannels = channels
        .map(
          (c) => EPGChannel(
            id: c.id,
            providerId: c.providerId,
            providerType: c.providerType,
            title: c.title,
            mediaType: c.mediaType,
            poster: c.poster,
            thumbnail: c.thumbnail,
            createdAt: c.createdAt,
            updatedAt: c.updatedAt,
            number: c.metadata['number']?.toString(),
          ),
        )
        .toList();

    // Group available programs by channelId in a single O(N) pass
    final Map<String, List<EPGProgram>> channelProgramsMap = {};
    final guideCtrl = Get.isRegistered<GuideController>()
        ? Get.find<GuideController>()
        : null;
    final guidePrograms = guideCtrl?.programs ?? <EPGProgram>[];
    for (final p in guidePrograms) {
      final chId = p.channelId;
      if (chId != null &&
          chId.isNotEmpty &&
          p.endTime.difference(p.startTime).inMinutes >= 15) {
        (channelProgramsMap[chId] ??= []).add(p);
      }
    }

    return GuideGrid(
      channels: epgChannels,
      programs: guidePrograms,
      channelProgramsMap: channelProgramsMap,
      activePlayingChannelId: liveCtrl.activePlayingChannel.value?.id,
      onMoveUp: _focusActiveCategory,
      onChannelTap: (epgChannel) {
        final match = channels.firstWhereOrNull((c) => c.id == epgChannel.id);
        if (match != null) {
          if (liveCtrl.activePlayingChannel.value?.id == match.id) {
            liveCtrl.expandToFullscreen();
          } else {
            liveCtrl.openChannel(match);
          }
        }
      },
      onProgramTap: (prog) {
        final match = channels.firstWhereOrNull((c) => c.id == prog.channelId);
        if (match != null) {
          if (liveCtrl.activePlayingChannel.value?.id == match.id) {
            liveCtrl.expandToFullscreen();
          } else {
            liveCtrl.openChannel(match);
          }
        }
      },
    );
  }

  Widget _buildRemoteLegendBar() {
    final now = DateTime.now();
    final timeStr = DateFormat('h:mma').format(now).toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                timeStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(
                  '|',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 15,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              const Text(
                '59°F',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _legendItem(Icons.play_circle_fill, 'OK: Play Fullscreen'),
                AppSpacing.widthLG,
                _legendItem(Icons.touch_app, 'Long-press OK: Channel Info'),
                AppSpacing.widthLG,
                _legendItem(Icons.swap_horiz, '◄ / ►: Categories & Hours'),
                AppSpacing.widthLG,
                _legendItem(Icons.grid_view, 'View: Toggle Grid / Timeline EPG'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // --- Mobile Layout Helpers (Unchanged) ---
  Widget _buildTimeNavigation(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _navButton(
              context,
              'Now',
              () => controller.setTimelineWindowHours(6),
            ),
            _navButton(context, 'Morning', controller.scrollToMorning),
            _navButton(context, 'Afternoon', controller.scrollToAfternoon),
            _navButton(context, 'Evening', controller.scrollToEvening),
            _navButton(context, 'Tomorrow', controller.scrollToTomorrow),
          ],
        ),
      ),
    );
  }

  Widget _navButton(BuildContext context, String label, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildMobileCategoryBar(
    BuildContext context,
    LiveTVController? liveCtrl,
  ) {
    final providerRepo = Get.isRegistered<ProviderRepository>()
        ? Get.find<ProviderRepository>()
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: SizedBox(
        height: 38,
        child: Row(
          children: [
            if (liveCtrl != null || providerRepo != null)
              Obx(() {
                final currentProvider =
                    liveCtrl?.selectedProvider.value ??
                    providerRepo?.activeProviderId.value ??
                    '';
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ProviderSelectorButton(
                    selectedProviderId: currentProvider,
                    onSelectProvider: (newProviderId) {
                      liveCtrl?.setProvider(newProviderId);
                      controller.setProvider(newProviderId);
                      providerRepo?.setActiveProviderId(newProviderId);
                    },
                    sheetTitle: 'TV Guide Provider',
                    isCompact: true,
                  ),
                );
              }),
            Expanded(
              child: Obx(() {
                final categories =
                    liveCtrl != null && liveCtrl.categories.isNotEmpty
                    ? liveCtrl.categories
                    : (controller.categories.isNotEmpty
                          ? controller.categories
                          : ['All Channels']);

                final selectedCat =
                    liveCtrl?.selectedCategory.value ??
                    controller.selectedCategory.value;

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8.0),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected =
                        (selectedCat.isEmpty && index == 0) ||
                        selectedCat == cat;
                    return _buildFilterPill(
                      cat,
                      isSelected,
                      () {
                        liveCtrl?.setCategory(cat);
                        controller.setCategory(cat);
                      },
                      onKeyEvent: index == 0
                          ? _openSidebarOnLeft(context)
                          : null,
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, LiveTVController? liveCtrl) {
    List<MediaItem> activeChannels = <MediaItem>[];
    if (liveCtrl != null) {
      if (liveCtrl.filteredChannels.isNotEmpty) {
        activeChannels = liveCtrl.filteredChannels.toList();
      } else if (liveCtrl.channels.isNotEmpty &&
          (liveCtrl.selectedCategory.value == 'All Channels' ||
              liveCtrl.selectedCategory.value.isEmpty)) {
        activeChannels = liveCtrl.channels.toList();
      }
    }
    final isFilteringCategory =
        liveCtrl != null &&
        liveCtrl.selectedCategory.value.isNotEmpty &&
        liveCtrl.selectedCategory.value != 'All Channels';

    if (activeChannels.isEmpty &&
        !isFilteringCategory &&
        controller.channels.isNotEmpty) {
      activeChannels = controller.channels.toList();
    }

    if (activeChannels.isEmpty) {
      if (liveCtrl != null &&
          liveCtrl.channels.isNotEmpty &&
          liveCtrl.selectedCategory.value != 'All Channels') {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tv_off,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              AppSpacing.heightMD,
              Text(
                'No channels in "${liveCtrl.selectedCategory.value}"',
                style: AppTypography.getHeadline(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              AppSpacing.heightMD,
              ElevatedButton.icon(
                onPressed: () {
                  liveCtrl.setCategory('All Channels');
                  controller.setCategory('All');
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Show All Channels'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        );
      }
      return const EmptyView(
        title: 'No Guide Available',
        description:
            'No EPG guide data is available at the moment. Try refreshing or adding an XMLTV source.',
      );
    }

    final hasPrograms = controller.filteredPrograms.isNotEmpty;
    final headerCount = hasPrograms ? 1 : 0;

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: activeChannels.length + headerCount,
      itemBuilder: (context, index) {
        if (hasPrograms && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: MiniGuide(
              programs: controller.filteredPrograms.take(5).toList(),
              onViewAll: () {
                liveCtrl?.setCategory('All Channels');
                controller.setCategory('All');
              },
            ),
          );
        }
        final item = activeChannels[index - headerCount];
        final channel = item is EPGChannel
            ? item
            : EPGChannel(
                id: item.id,
                providerId: item.providerId,
                providerType: item.providerType,
                title: item.title,
                mediaType: item.mediaType,
                poster: item.poster,
                thumbnail: item.thumbnail,
                createdAt: item.createdAt,
                updatedAt: item.updatedAt,
                number:
                    item.metadata['number']?.toString() ??
                    (item is Channel ? item.number : null),
              );

        final channelPrograms = controller.filteredPrograms
            .where((p) => p.channelId == channel.id)
            .toList();
        return ChannelColumn(
          channel: channel,
          currentProgram: channelPrograms.firstWhereOrNull(
            (p) => p.isCurrentlyPlaying,
          ),
          nextProgram: channelPrograms.firstWhereOrNull(
            (p) => p.startTime.isAfter(DateTime.now()),
          ),
          onFavorite: liveCtrl == null
              ? null
              : () => liveCtrl.toggleFavorite(item),
          onTap: () {
            if (liveCtrl != null) {
              liveCtrl.openChannel(item);
              Get.back();
            } else {
              Get.toNamed(AppRoutes.fullscreenPlayer, arguments: item);
            }
          },
        );
      },
    );
  }
}
