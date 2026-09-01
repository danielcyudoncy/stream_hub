import 'package:flutter/material.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

class LiveTvCategoryBar extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final bool showFavoritesOnly;
  final int favoritesCount;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<bool> onFavoritesToggle;

  const LiveTvCategoryBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.showFavoritesOnly,
    required this.favoritesCount,
    required this.onCategorySelected,
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
          // "All Channels" chip
          _CategoryChip(
            label: 'All Channels',
            icon: Icons.grid_view_rounded,
            isSelected: !showFavoritesOnly && selectedCategory == 'All Channels',
            onTap: () {
              if (showFavoritesOnly) onFavoritesToggle(false);
              onCategorySelected('All Channels');
            },
          ),
          const SizedBox(width: AppSpacing.xs),

          // "Favorites" chip (if any favorites exist)
          if (favoritesCount > 0) ...[
            _CategoryChip(
              label: 'Favorites ($favoritesCount)',
              icon: Icons.star_rounded,
              iconColor: Colors.amber,
              isSelected: showFavoritesOnly,
              onTap: () {
                onFavoritesToggle(!showFavoritesOnly);
              },
            ),
            const SizedBox(width: AppSpacing.xs),
          ],

          // Dynamic Category chips from loaded channels
          for (final category in categories.where((c) => c != 'All Channels')) ...[
            _CategoryChip(
              label: category,
              isSelected: !showFavoritesOnly && selectedCategory == category,
              onTap: () {
                if (showFavoritesOnly) onFavoritesToggle(false);
                onCategorySelected(category);
              },
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatefulWidget {
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
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTV = PlatformHelper.isTV;

    return FocusableActionDetector(
      onFocusChange: (hasKeyboardFocus) {
        if (mounted && _isFocused != hasKeyboardFocus) {
          setState(() => _isFocused = hasKeyboardFocus);
          if (hasKeyboardFocus) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Scrollable.ensureVisible(
                  context,
                  alignment: 0.5,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          }
        }
      },
      onShowFocusHighlight: (show) {
        if (mounted && _isFocused != show) {
          setState(() => _isFocused = show);
          if (show) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Scrollable.ensureVisible(
                  context,
                  alignment: 0.5,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          }
        }
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onTap(),
        ),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
          onInvoke: (_) => widget.onTap(),
        ),
      },
      mouseCursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isFocused ? (isTV ? 1.08 : 1.03) : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? colorScheme.primary
                  : (_isFocused
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.surface),
              borderRadius: AppRadius.pill,
              border: Border.all(
                color: _isFocused
                    ? Colors.white
                    : (widget.isSelected
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.12)),
                width: _isFocused ? 2.0 : 1.0,
              ),
              boxShadow: widget.isSelected || _isFocused
                  ? [
                      BoxShadow(
                        color: (widget.isSelected ? colorScheme.primary : Colors.white)
                            .withValues(alpha: widget.isSelected ? 0.3 : 0.2),
                        blurRadius: 8.0,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 16.0,
                    color: widget.isSelected
                        ? Colors.white
                        : (widget.iconColor ?? colorScheme.primary),
                  ),
                  const SizedBox(width: 6.0),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: widget.isSelected
                        ? Colors.white
                        : (_isFocused ? Colors.white : AppColors.darkTextSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
