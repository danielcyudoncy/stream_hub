import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/provider_selector_button.dart';
import '../../../shared/widgets/search_bar.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../controllers/multi_view_controller.dart';
import '../models/multi_view_layout_mode.dart';
import '../widgets/multi_view_layout_dialog.dart';
import '../widgets/multi_view_slot_tile.dart';

class MultiViewPage extends StatefulWidget {
  const MultiViewPage({super.key});

  @override
  State<MultiViewPage> createState() => _MultiViewPageState();
}

class _MultiViewPageState extends State<MultiViewPage> {
  MultiViewController get controller => Get.find<MultiViewController>();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Get.offAllNamed(AppRoutes.home);
        }
      },
      child: AppScaffold(
        title: 'Multi-View',
        showAppBar: false,
        body: Container(
          color: Colors.black,
          child: Focus(
            canRequestFocus: false,
            descendantsAreFocusable: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.contextMenu ||
                      event.logicalKey == LogicalKeyboardKey.info ||
                      event.logicalKey == LogicalKeyboardKey.gameButtonSelect)) {
                showMultiViewLayoutDialog(
                  context,
                  currentMode: controller.layoutMode.value,
                  onSelect: controller.setLayoutMode,
                );
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Obx(() {
                      final mode = controller.layoutMode.value;
                      return _buildGridForLayout(context, mode);
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF11141C),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Multi-View Title & Icon
          const Icon(
            Icons.dashboard_customize_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Multi-View',
            style: AppTypography.getTitle(
              color: Colors.white,
            ).copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Change Layout Button (TV Focusable, directly above left slot)
          Obx(() {
            final mode = controller.layoutMode.value;
            return TvFocusable(
              onTap: () {
                showMultiViewLayoutDialog(
                  context,
                  currentMode: mode,
                  onSelect: controller.setLayoutMode,
                );
              },
              scale: 1.05,
              borderRadius: AppRadius.small,
              focusColor: AppColors.primary,
              focusedBackgroundColor: AppColors.primary,
              unfocusedBackgroundColor: const Color(0xFF1E2430),
              builder: (context, hasFocus) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.small,
                  border: Border.all(
                    color: hasFocus
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.18),
                    width: hasFocus ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.view_quilt_rounded,
                      size: 16,
                      color: hasFocus ? Colors.black : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Change Layout',
                      style: AppTypography.getBody(
                        color: hasFocus ? Colors.black : Colors.white,
                      ).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(width: AppSpacing.sm),
          // Current Layout Badge
          Obx(() {
            final mode = controller.layoutMode.value;
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: AppRadius.pill,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.grid_view_rounded,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    mode.label,
                    style: AppTypography.getCaption(
                      color: AppColors.textSecondary,
                    ).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Spacer(),
          // Exit Multi-View Button (TV Focusable, directly above right slot)
          TvFocusable(
            onTap: () => Get.offAllNamed(AppRoutes.home),
            scale: 1.05,
            borderRadius: AppRadius.small,
            focusColor: Colors.redAccent,
            focusedBackgroundColor: Colors.redAccent,
            unfocusedBackgroundColor: Colors.white.withValues(alpha: 0.08),
            builder: (context, hasFocus) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadius.small,
                border: Border.all(
                  color: hasFocus
                      ? Colors.redAccent
                      : Colors.white.withValues(alpha: 0.18),
                  width: hasFocus ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.exit_to_app_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Exit',
                    style: AppTypography.getBody(
                      color: Colors.white,
                    ).copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridForLayout(BuildContext context, MultiViewLayoutMode mode) {
    switch (mode) {
      case MultiViewLayoutMode.dualHorizontal:
        return Row(
          children: [
            Expanded(
              child: MultiViewSlotTile(
                slotIndex: 0,
                controller: controller,
                onSelectChannel: () => _openChannelPicker(context, 0),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: MultiViewSlotTile(
                slotIndex: 1,
                controller: controller,
                onSelectChannel: () => _openChannelPicker(context, 1),
              ),
            ),
          ],
        );

      case MultiViewLayoutMode.dualVertical:
        return Column(
          children: [
            Expanded(
              child: MultiViewSlotTile(
                slotIndex: 0,
                controller: controller,
                onSelectChannel: () => _openChannelPicker(context, 0),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: MultiViewSlotTile(
                slotIndex: 1,
                controller: controller,
                onSelectChannel: () => _openChannelPicker(context, 1),
              ),
            ),
          ],
        );

      case MultiViewLayoutMode.triple:
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: MultiViewSlotTile(
                slotIndex: 0,
                controller: controller,
                onSelectChannel: () => _openChannelPicker(context, 0),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Expanded(
                    child: MultiViewSlotTile(
                      slotIndex: 1,
                      controller: controller,
                      onSelectChannel: () => _openChannelPicker(context, 1),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Expanded(
                    child: MultiViewSlotTile(
                      slotIndex: 2,
                      controller: controller,
                      onSelectChannel: () => _openChannelPicker(context, 2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case MultiViewLayoutMode.quad:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: MultiViewSlotTile(
                      slotIndex: 0,
                      controller: controller,
                      onSelectChannel: () => _openChannelPicker(context, 0),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: MultiViewSlotTile(
                      slotIndex: 1,
                      controller: controller,
                      onSelectChannel: () => _openChannelPicker(context, 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: MultiViewSlotTile(
                      slotIndex: 2,
                      controller: controller,
                      onSelectChannel: () => _openChannelPicker(context, 2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: MultiViewSlotTile(
                      slotIndex: 3,
                      controller: controller,
                      onSelectChannel: () => _openChannelPicker(context, 3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }

  void _openChannelPicker(BuildContext context, int slotIndex) {
    final searchFilter = ''.obs;
    final selectedCategory = 'All Channels'.obs;
    final selectedProviderId = ''.obs;
    final isTv = PlatformHelper.isTV || ResponsiveHelper.isTV(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollController) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  // Header with Title, Compact Provider Selector Button, and Close Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tv_rounded, color: AppColors.primary),
                        AppSpacing.widthSM,
                        Expanded(
                          child: Text(
                            'Select Channel (Slot ${slotIndex + 1})',
                            style: AppTypography.getTitle(color: Colors.white).copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Compact Provider Filter Button (identical to Live TV Screen)
                        Obx(() => ProviderSelectorButton(
                              selectedProviderId: selectedProviderId.value,
                              onSelectProvider: (pId) {
                                selectedProviderId.value = pId;
                                selectedCategory.value = 'All Channels';
                              },
                              sheetTitle: 'Filter by Provider',
                              isCompact: true,
                            )),
                        const SizedBox(width: 4.0),
                        TvFocusable(
                          onTap: () => Navigator.of(ctx).pop(),
                          borderRadius: BorderRadius.circular(20),
                          scale: 1.15,
                          focusColor: Colors.redAccent,
                          focusedBackgroundColor: Colors.redAccent.withValues(alpha: 0.35),
                          builder: (context, hasFocus) => Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(
                              Icons.close,
                              color: hasFocus ? Colors.white : Colors.white70,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // TV-aware Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: AppSearchBar(
                      hintText: 'Search channel name or number...',
                      backgroundColor: const Color(0xFF21262D),
                      onChanged: (val) => searchFilter.value = val.trim().toLowerCase(),
                      onClear: () => searchFilter.value = '',
                    ),
                  ),

                  // Horizontal Category Pills
                  Obx(() {
                    final categories = controller.getCategoriesForProvider(
                      selectedProviderId.value,
                    );
                    if (categories.isEmpty) return const SizedBox.shrink();

                    return Container(
                      height: 42.0,
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        itemCount: categories.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8.0),
                        itemBuilder: (context, idx) {
                          final cat = categories[idx];
                          final isSelected = selectedCategory.value == cat;
                          return TvFocusable(
                            onTap: () => selectedCategory.value = cat,
                            borderRadius: AppRadius.pill,
                            scale: 1.08,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14.0,
                                vertical: 8.0,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : const Color(0xFF21262D),
                                borderRadius: AppRadius.pill,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.white12,
                                  width: 1.0,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (cat == 'All Channels') ...[
                                    Icon(
                                      Icons.grid_view_rounded,
                                      size: 14.0,
                                      color: isSelected ? Colors.white : AppColors.primary,
                                    ),
                                    const SizedBox(width: 5.0),
                                  ],
                                  Text(
                                    cat,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontSize: 12.5,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),

                  AppSpacing.heightXS,

                  // Channel List
                  Expanded(
                    child: Obx(() {
                      if (controller.isLoadingChannels.value) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final query = searchFilter.value;
                      final catFilter = selectedCategory.value;
                      final pFilter = selectedProviderId.value;

                      final list = controller.allChannels.where((c) {
                        // Provider filter
                        if (pFilter.isNotEmpty &&
                            c.providerId != pFilter &&
                            c.providerType.displayName.toLowerCase() !=
                                pFilter.toLowerCase() &&
                            c.providerType.name.toLowerCase() !=
                                pFilter.toLowerCase()) {
                          return false;
                        }

                        // Category filter
                        if (!controller.channelMatchesCategory(c, catFilter)) {
                          return false;
                        }

                        // Search query filter
                        if (query.isNotEmpty) {
                          final title = c.title.toLowerCase();
                          final numStr = c.metadata['tvg-chno']?.toString() ?? '';
                          if (!title.contains(query) && !numStr.contains(query)) {
                            return false;
                          }
                        }

                        return true;
                      }).toList();

                      if (list.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.tv_off_rounded, size: 40.0, color: Colors.white24),
                              const SizedBox(height: 8.0),
                              Text(
                                'No channels found',
                                style: AppTypography.getBody(color: Colors.white60),
                              ),
                              if (catFilter != 'All Channels' || pFilter.isNotEmpty || query.isNotEmpty) ...[
                                const SizedBox(height: 8.0),
                                TextButton(
                                  onPressed: () {
                                    selectedCategory.value = 'All Channels';
                                    selectedProviderId.value = '';
                                    searchFilter.value = '';
                                  },
                                  child: const Text('Reset Filters'),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        controller: scrollController,
                        itemCount: list.length,
                        separatorBuilder: (context, index) => const Divider(
                          color: Colors.white10,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final ch = list[index];
                          final rawLogo = ch.thumbnail ?? ch.poster ?? ch.backdrop;
                          final logoUrl = ImageUrlFormatter.format(rawLogo, item: ch);
                          final chCat = controller.getChannelCategoryName(ch);

                          return TvFocusable(
                            autofocus: isTv && index == 0,
                            onTap: () {
                              controller.setChannelForSlot(slotIndex, ch);
                              Navigator.of(ctx).pop();
                            },
                            borderRadius: AppRadius.small,
                            scale: 1.02,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 2.0,
                              ),
                              leading: logoUrl != null && logoUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4.0),
                                      child: Image.network(
                                        logoUrl,
                                        width: 38.0,
                                        height: 38.0,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.live_tv, size: 24.0, color: Colors.white54),
                                      ),
                                    )
                                  : const Icon(Icons.live_tv, size: 24.0, color: Colors.white54),
                              title: Text(
                                ch.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: chCat != null && chCat.isNotEmpty
                                  ? Text(
                                      chCat,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : (ch.subtitle != null
                                      ? Text(
                                          ch.subtitle!,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11.5,
                                          ),
                                        )
                                      : null),
                              trailing: const Icon(
                                Icons.play_circle_outline_rounded,
                                color: AppColors.primary,
                                size: 24.0,
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
