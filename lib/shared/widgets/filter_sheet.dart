import 'package:flutter/material.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'tv_focusable.dart';

class FilterSheet extends StatelessWidget {
  final String sortField;
  final String filterType;
  final String? filterProviderType;
  final List<String> availableTypes;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String?> onProviderTypeChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;

  const FilterSheet({
    super.key,
    required this.sortField,
    required this.filterType,
    required this.filterProviderType,
    required this.availableTypes,
    required this.onSortChanged,
    required this.onFilterChanged,
    required this.onProviderTypeChanged,
    required this.onApply,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Sort By', style: AppTypography.getTitle(color: colorScheme.onSurface)),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: sortField,
            onChanged: (value) {
              if (value != null) onSortChanged(value);
            },
            child: Column(
              children: ['Name', 'Date Added', 'Last Updated', 'Provider Type'].map((field) => TvFocusable(
                onTap: () => onSortChanged(field),
                borderRadius: AppRadius.medium,
                scale: 1.02,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  child: Row(
                    children: [
                      Radio<String>(value: field),
                      const SizedBox(width: 8),
                      Text(field, style: AppTypography.getBody(color: colorScheme.onSurface)),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Filter By', style: AppTypography.getTitle(color: colorScheme.onSurface)),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: filterType,
            onChanged: (value) {
              if (value != null) onFilterChanged(value);
            },
            child: Column(
              children: ['All', 'Enabled', 'Disabled', 'Favorites'].map((type) => TvFocusable(
                onTap: () => onFilterChanged(type),
                borderRadius: AppRadius.medium,
                scale: 1.02,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  child: Row(
                    children: [
                      Radio<String>(value: type),
                      const SizedBox(width: 8),
                      Text(type, style: AppTypography.getBody(color: colorScheme.onSurface)),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ),
          if (availableTypes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Provider Type', style: AppTypography.getTitle(color: colorScheme.onSurface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TvFocusable(
                  onTap: () => onProviderTypeChanged(null),
                  borderRadius: AppRadius.pill,
                  scale: 1.05,
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: filterProviderType == null,
                    onSelected: (_) => onProviderTypeChanged(null),
                  ),
                ),
                ...availableTypes.map((type) => TvFocusable(
                  onTap: () => onProviderTypeChanged(type),
                  borderRadius: AppRadius.pill,
                  scale: 1.05,
                  child: ChoiceChip(
                    label: Text(type),
                    selected: filterProviderType == type,
                    onSelected: (_) => onProviderTypeChanged(type),
                  ),
                )),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TvFocusable(
                  onTap: onReset,
                  borderRadius: AppRadius.medium,
                  scale: 1.04,
                  child: OutlinedButton(onPressed: onReset, child: const Text('Reset')),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TvFocusable(
                  onTap: onApply,
                  borderRadius: AppRadius.medium,
                  scale: 1.04,
                  child: FilledButton(onPressed: onApply, child: const Text('Apply')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
