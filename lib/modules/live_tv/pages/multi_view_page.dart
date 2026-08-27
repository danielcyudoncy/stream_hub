import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../controllers/multi_view_controller.dart';
import '../models/multi_view_layout_mode.dart';
import '../widgets/multi_view_slot_tile.dart';

class MultiViewPage extends GetView<MultiViewController> {
  const MultiViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: 'Multi-View',
      showNavigation: false,
      actions: [
        // Layout Mode Selector
        Obx(() {
          return PopupMenuButton<MultiViewLayoutMode>(
            icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
            tooltip: 'Change Layout',
            initialValue: controller.layoutMode.value,
            onSelected: controller.setLayoutMode,
            itemBuilder: (context) {
              return MultiViewLayoutMode.values.map((mode) {
                final isSelected = controller.layoutMode.value == mode;
                return PopupMenuItem(
                  value: mode,
                  child: Row(
                    children: [
                      Icon(
                        _iconForLayout(mode),
                        color: isSelected ? AppColors.primary : colorScheme.onSurface,
                        size: 20.0,
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        mode.label,
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          );
        }),
      ],
      body: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Obx(() {
          final mode = controller.layoutMode.value;
          return _buildGridForLayout(context, mode);
        }),
      ),
    );
  }

  IconData _iconForLayout(MultiViewLayoutMode mode) {
    switch (mode) {
      case MultiViewLayoutMode.dualHorizontal:
        return Icons.view_column_rounded;
      case MultiViewLayoutMode.dualVertical:
        return Icons.view_agenda_rounded;
      case MultiViewLayoutMode.triple:
        return Icons.view_quilt_rounded;
      case MultiViewLayoutMode.quad:
        return Icons.grid_view_rounded;
    }
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
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollController) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        const Icon(Icons.tv_rounded, color: AppColors.primary),
                        AppSpacing.widthSM,
                        Expanded(
                          child: Text(
                            'Select Channel for Slot ${slotIndex + 1}',
                            style: AppTypography.getTitle(color: Colors.white).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search channel name or number...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF21262D),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.medium,
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    onChanged: (val) => searchFilter.value = val.trim().toLowerCase(),
                  ),
                ),
                AppSpacing.heightSM,
                Expanded(
                  child: Obx(() {
                    if (controller.isLoadingChannels.value) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var list = controller.allChannels;
                    if (searchFilter.value.isNotEmpty) {
                      list = list
                          .where((c) => c.title.toLowerCase().contains(searchFilter.value))
                          .toList()
                          .obs;
                    }

                    if (list.isEmpty) {
                      return Center(
                        child: Text(
                          'No channels found',
                          style: AppTypography.getBody(color: Colors.white60),
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

                        return ListTile(
                          leading: logoUrl != null && logoUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4.0),
                                  child: Image.network(
                                    logoUrl,
                                    width: 36.0,
                                    height: 36.0,
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
                            ),
                          ),
                          subtitle: ch.subtitle != null
                              ? Text(
                                  ch.subtitle!,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12.0),
                                )
                              : null,
                          onTap: () {
                            controller.setChannelForSlot(slotIndex, ch);
                            Navigator.of(ctx).pop();
                          },
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
