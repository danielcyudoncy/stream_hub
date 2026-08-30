import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/empty_view.dart';
import 'package:stream_hub/shared/widgets/filter_sheet.dart';
import 'package:stream_hub/shared/widgets/provider_card.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_enums.dart';
import 'provider_manager_controller.dart';
import 'provider_details_page.dart';
import 'provider_form_page.dart';

class ProviderManagerPage extends GetView<ProviderManagerController> {
  const ProviderManagerPage({super.key});

  static final GlobalKey<PopupMenuButtonState<String>> _sortPopupKey =
      GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Provider Manager',
      actions: [
        TvFocusable(
          onTap: () => Get.to(() => ProviderFormPage()),
          borderRadius: BorderRadius.circular(8.0),
          scale: 1.05,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.primaryGradient),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(AppIcons.add, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'Add Provider',
                  style: AppTypography.getButton(color: Colors.white)
                      .copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
      ],
      floatingActionButton: TvFocusable(
        onTap: () => Get.to(() => ProviderFormPage()),
        borderRadius: BorderRadius.circular(28.0),
        scale: 1.05,
        child: FloatingActionButton.extended(
          onPressed: () => Get.to(() => ProviderFormPage()),
          backgroundColor: colorScheme.primary,
          icon: const Icon(AppIcons.add, color: Colors.white),
          label: Text(
            'Add Provider',
            style: AppTypography.getButton(color: Colors.white),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(context, colorScheme),
          _buildFilterChips(context, colorScheme),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final filtered = controller.getFilteredProviders();

              if (filtered.isEmpty && controller.providers.isEmpty) {
                return EmptyView(
                  title: 'No Providers Yet',
                  description: 'Add your first IPTV provider to get started.',
                  icon: AppIcons.providers,
                  actionLabel: 'Add Provider',
                  onAction: () => Get.to(() => ProviderFormPage()),
                );
              }

              if (filtered.isEmpty) {
                return EmptyView(
                  title: 'No Matching Providers',
                  description: 'Try adjusting your search or filters.',
                  icon: AppIcons.search,
                  actionLabel: 'Clear Filters',
                  onAction: () {
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
                      onTap: () => Get.to(
                        () => ProviderDetailsPage(providerId: provider.id),
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

  Widget _buildSearchBar(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TvFocusable(
            onTap: () => _showFilterSheet(context),
            scale: 1.15,
            borderRadius: BorderRadius.circular(24),
            child: IconButton(
              onPressed: () => _showFilterSheet(context),
              icon: Icon(
                Icons.tune_outlined,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              tooltip: 'Filters',
            ),
          ),
          TvFocusable(
            onTap: () => _sortPopupKey.currentState?.showButtonMenu(),
            scale: 1.15,
            borderRadius: BorderRadius.circular(24),
            child: PopupMenuButton<String>(
              key: _sortPopupKey,
              icon: Icon(
                Icons.sort_outlined,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
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
                      Obx(
                        () => Icon(
                          Icons.check,
                          size: 18,
                          color: controller.sortField.value == field
                              ? colorScheme.primary
                              : Colors.transparent,
                        ),
                      ),
                      AppSpacing.widthXS,
                      Text(_sortLabel(field)),
                    ],
                  ),
                );
              }).toList(),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FilterSheet(
        sortField: controller.sortField.value.name,
        filterType: controller.filterType.value.name,
        filterProviderType: controller.filterProviderType.value?.name,
        availableTypes: availableTypes.map((e) => e.displayName).toList(),
        onSortChanged: (value) {
          final field = ProviderSortField.values.firstWhereOrNull(
            (f) => f.name == value,
          );
          if (field != null) controller.updateSortField(field);
        },
        onFilterChanged: (value) {
          final type = ProviderFilterType.values.firstWhereOrNull(
            (f) => f.name == value,
          );
          if (type != null) controller.updateFilterType(type);
        },
        onProviderTypeChanged: (value) {
          final type = ProviderType.values.firstWhereOrNull(
            (f) => f.displayName == value,
          );
          controller.updateFilterProviderType(type);
        },
        onApply: () => Get.back(),
        onReset: () {
          controller.updateFilterType(ProviderFilterType.all);
          controller.updateFilterProviderType(null);
          controller.updateSearchQuery('');
          controller.updateSortField(ProviderSortField.dateAdded);
        },
      ),
    );
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
