import 'package:flutter/material.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

class FreeTvCategoryBar extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final List<String> countries;
  final String selectedCountry;
  final bool showFavoritesOnly;
  final int favoritesCount;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onCountrySelected;
  final ValueChanged<bool> onFavoritesToggle;

  const FreeTvCategoryBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.countries,
    required this.selectedCountry,
    required this.showFavoritesOnly,
    required this.favoritesCount,
    required this.onCategorySelected,
    required this.onCountrySelected,
    required this.onFavoritesToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48.0,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          // "All Categories" chip
          _CategoryChip(
            label: 'All Channels',
            icon: Icons.grid_view_rounded,
            isSelected: !showFavoritesOnly &&
                selectedCategory == 'All Categories' &&
                selectedCountry == 'All Countries',
            onTap: () {
              if (showFavoritesOnly) onFavoritesToggle(false);
              onCategorySelected('All Categories');
              onCountrySelected('All Countries');
            },
          ),
          const SizedBox(width: AppSpacing.xs),

          // "Favorites" chip
          if (favoritesCount > 0) ...[
            _CategoryChip(
              label: 'Favorites ($favoritesCount)',
              icon: Icons.star_rounded,
              iconColor: Colors.amber,
              isSelected: showFavoritesOnly,
              onTap: () => onFavoritesToggle(!showFavoritesOnly),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],

          // Quick Nigerian Discovery Chip
          _CategoryChip(
            label: '🇳🇬 Nigeria',
            isSelected: !showFavoritesOnly && selectedCountry == 'Nigeria',
            onTap: () {
              if (showFavoritesOnly) onFavoritesToggle(false);
              onCountrySelected(selectedCountry == 'Nigeria' ? 'All Countries' : 'Nigeria');
            },
          ),
          const SizedBox(width: AppSpacing.xs),

          // Dynamic Category chips from loaded channels
          ...categories.where((c) => c != 'All Categories').map(
            (category) {
              final isSelected =
                  !showFavoritesOnly && selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: _CategoryChip(
                  label: category,
                  isSelected: isSelected,
                  onTap: () {
                    if (showFavoritesOnly) onFavoritesToggle(false);
                    onCategorySelected(isSelected ? 'All Categories' : category);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    this.icon,
    this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TvFocusable(
      onTap: onTap,
      scale: 1.05,
      borderRadius: AppRadius.pill,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: AppRadius.pill,
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : colorScheme.outline.withValues(alpha: 0.15),
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8.0,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16.0,
                color: isSelected
                    ? Colors.black
                    : (iconColor ?? colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.black : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
