import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/core/utils/responsive_helper.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/empty_view.dart';
import 'package:stream_hub/shared/widgets/filter_sheet.dart';
import 'package:stream_hub/shared/widgets/provider_card.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_enums.dart';
import 'provider_manager_controller.dart';

class ProviderManagerPage extends StatefulWidget {
  const ProviderManagerPage({super.key});

  @override
  State<ProviderManagerPage> createState() => _ProviderManagerPageState();
}

class _ProviderManagerPageState extends State<ProviderManagerPage> {
  final GlobalKey<PopupMenuButtonState<String>> _sortPopupKey =
      GlobalKey<PopupMenuButtonState<String>>();
  late final TextEditingController _searchController;

  ProviderManagerController get controller =>
      Get.find<ProviderManagerController>();

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: controller.searchQuery.value);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTvMode =
        ResponsiveHelper.isTV(context) || ResponsiveHelper.isDesktop(context);

    return AppScaffold(
      title: 'Media Sources',
      showNavigation: false,
      actions: [
        if (!isTvMode)
          TvFocusable(
            onTap: () => Get.toNamed(AppRoutes.providerForm),
            borderRadius: BorderRadius.circular(8.0),
            scale: 1.05,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.add, size: 16, color: colorScheme.onPrimary),
                  const SizedBox(width: 4),
                  Text(
                    'Add Source',
                    style: AppTypography.getButton(color: colorScheme.onPrimary)
                        .copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(width: AppSpacing.md),
      ],
      floatingActionButton: !isTvMode
          ? TvFocusable(
              onTap: () => Get.toNamed(AppRoutes.providerForm),
              borderRadius: BorderRadius.circular(28.0),
              scale: 1.05,
              child: FloatingActionButton.extended(
                onPressed: () => Get.toNamed(AppRoutes.providerForm),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                icon: Icon(AppIcons.add, color: colorScheme.onPrimary),
                label: Text(
                  'Add Source',
                  style: AppTypography.getButton(color: colorScheme.onPrimary),
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          if (isTvMode) _buildTvAddProviderBar(context, isTvMode: isTvMode),
          _buildSearchBar(context, colorScheme),
          _buildFilterChips(context, colorScheme),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final filtered = controller.getFilteredProviders();

              if (filtered.isEmpty && !controller.hasAnyProviders) {
                return EmptyView(
                  title: 'No Media Sources',
                  description:
                      'Add your first IPTV playlist or streaming source to start watching.',
                  icon: AppIcons.providers,
                  actionLabel: 'Add Media Source',
                  onAction: () => Get.toNamed(AppRoutes.providerForm),
                );
              }

              if (filtered.isEmpty) {
                return EmptyView(
                  title: 'No Matching Sources',
                  description: 'Try adjusting your search or filters.',
                  icon: AppIcons.search,
                  actionLabel: 'Clear Filters',
                  onAction: () {
                    _searchController.clear();
                    controller.updateSearchQuery('');
                    controller.updateFilterType(ProviderFilterType.all);
                    controller.updateFilterProviderType(null);
                    controller.updateSortField(ProviderSortField.dateAdded);
                  },
                );
              }

              return RefreshIndicator(
                onRefresh: () async => controller.loadProviders(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final provider = filtered[index];
                    return ProviderCard(
                      provider: provider,
                      onTap: () => Get.toNamed(
                        AppRoutes.providerDetails,
                        arguments: provider,
                      ),
                      onFavoriteToggle: () =>
                          controller.toggleFavorite(provider.id),
                      onEnabledToggle: () =>
                          controller.toggleEnabled(provider.id),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// TV-only header bar providing a reachable "Add Provider" action, since
  /// AppScaffold discards AppBar actions and FABs when rendering TvScaffold.
  Widget _buildTvAddProviderBar(BuildContext context, {bool isTvMode = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Obx(() {
        final hasProviders = controller.hasAnyProviders;
        final count = controller.totalProviderCount;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Media Sources',
                    style: AppTypography.getHeadline(
                      color: colorScheme.onSurface,
                    ).copyWith(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasProviders
                        ? '$count source${count == 1 ? '' : 's'} configured'
                        : 'Connect your IPTV playlists and streaming sources.',
                    style: AppTypography.getBody(
                      color: colorScheme.onSurfaceVariant,
                    ).copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasProviders) ...[
              AppSpacing.widthMD,
              TvFocusable(
                autofocus: isTvMode,
                onTap: () => Get.toNamed(AppRoutes.providerForm),
                borderRadius: BorderRadius.circular(10.0),
                scale: 1.05,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.add, size: 16, color: colorScheme.onPrimary),
                      const SizedBox(width: 6),
                      Text(
                        'Add Source',
                        style: AppTypography.getButton(color: colorScheme.onPrimary)
                            .copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _buildSearchBar(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: TvFocusable(
              borderRadius: AppRadius.medium,
              scale: 1.01,
              child: TextField(
                controller: _searchController,
                style: AppTypography.getBody(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search media sources...',
                  hintStyle: AppTypography.getBody(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(
                    AppIcons.search,
                    size: 20,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  suffixIcon: Obx(() {
                    if (controller.searchQuery.value.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      icon: Icon(
                        AppIcons.close,
                        size: 18,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        controller.updateSearchQuery('');
                      },
                    );
                  }),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.medium,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                onChanged: controller.updateSearchQuery,
              ),
            ),
          ),
          AppSpacing.widthSM,
          TvFocusable(
            onTap: () => _showFilterSheet(context),
            scale: 1.1,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.tune_outlined,
                size: 20,
                color: colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
          AppSpacing.widthXS,
          TvFocusable(
            onTap: () => _sortPopupKey.currentState?.showButtonMenu(),
            scale: 1.1,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: PopupMenuButton<String>(
                key: _sortPopupKey,
                icon: Icon(
                  Icons.sort_outlined,
                  size: 20,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                tooltip: 'Sort',
                onSelected: (value) {
                  final field = ProviderSortField.values.firstWhereOrNull(
                    (f) => f.name == value,
                  );
                  if (field != null) controller.updateSortField(field);
                },
                itemBuilder: (context) => ProviderSortField.values.map((field) {
                  return PopupMenuItem(
                    value: field.name,
                    child: Row(
                      children: [
                        Icon(
                          Icons.check,
                          size: 18,
                          color: controller.sortField.value == field
                              ? colorScheme.primary
                              : Colors.transparent,
                        ),
                        AppSpacing.widthXS,
                        Text(_sortLabel(field)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, ColorScheme colorScheme) {
    return Obx(() {
      final hasActiveFilters =
          controller.filterType.value != ProviderFilterType.all ||
          controller.filterProviderType.value != null ||
          controller.searchQuery.value.isNotEmpty;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        height: hasActiveFilters ? 48 : 0,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            if (controller.filterType.value != ProviderFilterType.all)
              _buildChip(
                context,
                _filterLabel(controller.filterType.value),
                () {
                  controller.updateFilterType(ProviderFilterType.all);
                },
              ),
            if (controller.filterProviderType.value != null)
              _buildChip(
                context,
                controller.filterProviderType.value!.displayName,
                () {
                  controller.updateFilterProviderType(null);
                },
              ),
            if (controller.searchQuery.value.isNotEmpty)
              _buildChip(
                context,
                'Search: ${controller.searchQuery.value}',
                () {
                  _searchController.clear();
                  controller.updateSearchQuery('');
                },
              ),
          ],
        ),
      );
    });
  }

  Widget _buildChip(BuildContext context, String label, VoidCallback onRemove) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.xs),
      child: Chip(
        label: Text(
          label,
          style: AppTypography.getCaption(
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        onDeleted: onRemove,
        deleteIcon: Icon(
          Icons.close,
          size: 16,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final availableTypes = ProviderType.values.toList();
    final isTv =
        ResponsiveHelper.isTV(context) || ResponsiveHelper.isDesktop(context);

    if (isTv) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xl,
          ),
          child: Container(
            width: 480,
            constraints: const BoxConstraints(maxHeight: 620),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: AppRadius.large,
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: AppRadius.large,
              child: FilterSheet(
                sortField: _sortLabel(controller.sortField.value),
                filterType: _filterLabel(controller.filterType.value),
                filterProviderType:
                    controller.filterProviderType.value?.displayName,
                availableTypes:
                    availableTypes.map((e) => e.displayName).toList(),
                onSortChanged: (value) {
                  final field = ProviderSortField.values.firstWhereOrNull(
                    (f) => _sortLabel(f) == value,
                  );
                  if (field != null) controller.updateSortField(field);
                },
                onFilterChanged: (value) {
                  final type = ProviderFilterType.values.firstWhereOrNull(
                    (f) => _filterLabel(f) == value,
                  );
                  if (type != null) controller.updateFilterType(type);
                },
                onProviderTypeChanged: (value) {
                  final type = ProviderType.values.firstWhereOrNull(
                    (f) => f.displayName == value,
                  );
                  controller.updateFilterProviderType(type);
                },
                onApply: () => Navigator.of(dialogContext).pop(),
                onReset: () {
                  _searchController.clear();
                  controller.updateFilterType(ProviderFilterType.all);
                  controller.updateFilterProviderType(null);
                  controller.updateSearchQuery('');
                  controller.updateSortField(ProviderSortField.dateAdded);
                  Navigator.of(dialogContext).pop();
                },
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => FilterSheet(
          sortField: _sortLabel(controller.sortField.value),
          filterType: _filterLabel(controller.filterType.value),
          filterProviderType:
              controller.filterProviderType.value?.displayName,
          availableTypes: availableTypes.map((e) => e.displayName).toList(),
          onSortChanged: (value) {
            final field = ProviderSortField.values.firstWhereOrNull(
              (f) => _sortLabel(f) == value,
            );
            if (field != null) controller.updateSortField(field);
          },
          onFilterChanged: (value) {
            final type = ProviderFilterType.values.firstWhereOrNull(
              (f) => _filterLabel(f) == value,
            );
            if (type != null) controller.updateFilterType(type);
          },
          onProviderTypeChanged: (value) {
            final type = ProviderType.values.firstWhereOrNull(
              (f) => f.displayName == value,
            );
            controller.updateFilterProviderType(type);
          },
          onApply: () => Navigator.of(sheetContext).pop(),
          onReset: () {
            _searchController.clear();
            controller.updateFilterType(ProviderFilterType.all);
            controller.updateFilterProviderType(null);
            controller.updateSearchQuery('');
            controller.updateSortField(ProviderSortField.dateAdded);
            Navigator.of(sheetContext).pop();
          },
        ),
      );
    }
  }

  String _sortLabel(ProviderSortField field) {
    switch (field) {
      case ProviderSortField.name:
        return 'Name';
      case ProviderSortField.dateAdded:
        return 'Date Added';
      case ProviderSortField.lastUpdated:
        return 'Last Updated';
      case ProviderSortField.providerType:
        return 'Provider Type';
    }
  }

  String _filterLabel(ProviderFilterType type) {
    switch (type) {
      case ProviderFilterType.all:
        return 'All';
      case ProviderFilterType.enabled:
        return 'Enabled';
      case ProviderFilterType.disabled:
        return 'Disabled';
      case ProviderFilterType.favorites:
        return 'Favorites';
    }
  }
}
