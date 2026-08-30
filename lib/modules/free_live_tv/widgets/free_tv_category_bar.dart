import 'package:flutter/material.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

/// Curated quick-access groupings surfaced at the start of the Free TV browse
/// bar so users can jump straight into curated category/country/region views.
class FreeTvCuratedChips {
  final List<String> categories;
  final List<String> countries;
  final List<String> regions;

  const FreeTvCuratedChips({
    this.categories = const [],
    this.countries = const [],
    this.regions = const [],
  });
}

class FreeTvCategoryBar extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final List<String> countries;
  final String selectedCountry;
  final List<String> regions;
  final String selectedRegion;
  final bool showFavoritesOnly;
  final int favoritesCount;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onCountrySelected;
  final ValueChanged<String> onRegionSelected;
  final ValueChanged<bool> onFavoritesToggle;

  const FreeTvCategoryBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.countries,
    required this.selectedCountry,
    this.regions = const [],
    this.selectedRegion = 'All Regions',
    required this.showFavoritesOnly,
    required this.favoritesCount,
    required this.onCategorySelected,
    required this.onCountrySelected,
    required this.onRegionSelected,
    required this.onFavoritesToggle,
  });

  @override
  Widget build(BuildContext context) {
    final curated = FreeTvCuratedChips(
      categories: const ['News', 'Sports', 'Entertainment', 'Kids', 'Documentary'],
      countries: const ['Nigeria', 'South Africa', 'United Kingdom', 'United States', 'France', 'Germany'],
      regions: const ['Africa', 'Americas', 'Asia'],
    );

    return Container(
      height: 96.0,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          // Ground state: curated Recommended home + All Channels
          _CategoryChip(
            label: 'Recommended',
            icon: Icons.auto_awesome_rounded,
            isSelected: !showFavoritesOnly &&
                selectedCategory == 'All Categories' &&
                selectedCountry == 'All Countries' &&
                selectedRegion == 'All Regions',
            onTap: () {
              if (showFavoritesOnly) onFavoritesToggle(false);
              onCategorySelected('All Categories');
              onCountrySelected('All Countries');
              onRegionSelected('All Regions');
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

          // Curated Country chips (prominent, right after ground state)
          ...curated.countries.map(
            (country) {
              final isSelected =
                  !showFavoritesOnly && selectedCountry == country;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: _CategoryChip(
                  label: _countryFlag(country) + country,
                  isSelected: isSelected,
                  onTap: () {
                    if (showFavoritesOnly) onFavoritesToggle(false);
                    onCountrySelected(isSelected
                        ? 'All Countries'
                        : country);
                  },
                ),
              );
            },
          ),

          const SizedBox(width: AppSpacing.xs),
          _chipDivider(),
          const SizedBox(width: AppSpacing.xs),

          // Curated Region chips
          ...curated.regions.map(
            (region) {
              final isSelected =
                  !showFavoritesOnly && selectedRegion == region;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: _CategoryChip(
                  label: region,
                  icon: Icons.public_rounded,
                  isSelected: isSelected,
                  onTap: () {
                    if (showFavoritesOnly) onFavoritesToggle(false);
                    onRegionSelected(isSelected ? 'All Regions' : region);
                  },
                ),
              );
            },
          ),

          const SizedBox(width: AppSpacing.xs),
          _chipDivider(),
          const SizedBox(width: AppSpacing.xs),

          // Curated Category chips
          ...curated.categories.map(
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
                    onCategorySelected(isSelected
                        ? 'All Categories'
                        : category);
                  },
                ),
              );
            },
          ),

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
                    onCategorySelected(
                        isSelected ? 'All Categories' : category);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _countryFlag(String country) {
    switch (country) {
      case 'Nigeria':
        return '🇳🇬 ';
      case 'South Africa':
        return '🇿🇦 ';
      case 'United Kingdom':
        return '🇬🇧 ';
      case 'United States':
        return '🇺🇸 ';
      case 'France':
        return '🇫🇷 ';
      case 'Germany':
        return '🇩🇪 ';
      default:
        return '';
    }
  }

  Widget _chipDivider() {
    return Container(
      width: 1.0,
      height: 24.0,
      margin: const EdgeInsets.symmetric(horizontal: 2.0),
      color: Colors.white.withValues(alpha: 0.12),
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
