import 'package:flutter/material.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/movie_category.dart';
import '../../../shared/widgets/search_bar.dart';
import '../../../shared/widgets/tv_focusable.dart';

/// A modal bottom sheet (on mobile) or dialog (on TV/Desktop) allowing users
/// to browse, search, and navigate across all VOD movie categories and genres.
class MovieCategorySheet extends StatefulWidget {
  final List<MovieCategory> categories;
  final ValueChanged<MovieCategory> onSelectCategory;
  final String? selectedCategoryId;
  final String title;

  const MovieCategorySheet({
    super.key,
    required this.categories,
    required this.onSelectCategory,
    this.selectedCategoryId,
    this.title = 'Movie Categories',
  });

  /// Displays the category sheet responsively: as a centered dialog on TV and Desktop,
  /// or as a scrollable bottom sheet on Mobile.
  static Future<void> show(
    BuildContext context, {
    required List<MovieCategory> categories,
    required ValueChanged<MovieCategory> onSelectCategory,
    String? selectedCategoryId,
    String title = 'Movie Categories',
  }) async {
    final isTV = ResponsiveHelper.isTV(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    if (isTV || isDesktop) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xl,
          ),
          child: Container(
            width: 520,
            constraints: const BoxConstraints(maxHeight: 640),
            decoration: BoxDecoration(
              color: Theme.of(dialogContext).colorScheme.surface,
              borderRadius: AppRadius.large,
              border: Border.all(
                color: Theme.of(dialogContext)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: MovieCategorySheet(
              categories: categories,
              onSelectCategory: onSelectCategory,
              selectedCategoryId: selectedCategoryId,
              title: title,
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
          ),
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.extraLargeValue),
            ),
            border: Border.all(
              color: Theme.of(sheetContext)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.1),
            ),
          ),
          child: MovieCategorySheet(
            categories: categories,
            onSelectCategory: onSelectCategory,
            selectedCategoryId: selectedCategoryId,
            title: title,
          ),
        ),
      );
    }
  }

  @override
  State<MovieCategorySheet> createState() => _MovieCategorySheetState();
}

class _MovieCategorySheetState extends State<MovieCategorySheet> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MovieCategory> get _filteredCategories {
    if (_searchQuery.trim().isEmpty) {
      return widget.categories;
    }
    final query = _searchQuery.toLowerCase().trim();
    return widget.categories
        .where((cat) => cat.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTV = ResponsiveHelper.isTV(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isModal = !isTV && !isDesktop;

    final categories = _filteredCategories;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle on mobile bottom sheets
          if (isModal) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: AppRadius.pill,
                ),
              ),
            ),
          ],

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  AppIcons.category,
                  color: colorScheme.primary,
                  size: 22,
                ),
                AppSpacing.widthSM,
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        widget.title,
                        style: AppTypography.getTitle(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      AppSpacing.widthSM,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: AppRadius.pill,
                        ),
                        child: Text(
                          '${widget.categories.length}',
                          style: AppTypography.getLabel(
                            color: colorScheme.primary,
                          ).copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                TvFocusable(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: AppRadius.medium,
                  child: IconButton(
                    icon: const Icon(AppIcons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: AppSearchBar(
              controller: _searchController,
              hintText: 'Search categories...',
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              onClear: () {
                setState(() {
                  _searchQuery = '';
                });
              },
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          // Category List
          Flexible(
            child: categories.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxl,
                      horizontal: AppSpacing.lg,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.empty,
                            size: 40,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          AppSpacing.heightMD,
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No categories matching "$_searchQuery"'
                                : 'No categories available',
                            style: AppTypography.getBody(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    itemCount: categories.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = widget.selectedCategoryId == cat.id ||
                          widget.selectedCategoryId == cat.name;
                      final icon = cat.icon ?? MovieCategory.defaultIconForName(cat.name);

                      return TvFocusable(
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onSelectCategory(cat);
                        },
                        borderRadius: AppRadius.medium,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary.withValues(alpha: 0.15)
                                : colorScheme.surfaceContainerLow,
                            borderRadius: AppRadius.medium,
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: AppRadius.small,
                                ),
                                child: Icon(
                                  icon,
                                  size: 20,
                                  color: isSelected
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                              AppSpacing.widthMD,
                              Expanded(
                                child: Text(
                                  cat.name,
                                  style: AppTypography.getBody(
                                    color: colorScheme.onSurface,
                                  ).copyWith(
                                    fontWeight:
                                        isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (cat.count > 0) ...[
                                AppSpacing.widthSM,
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: AppRadius.pill,
                                  ),
                                  child: Text(
                                    '${cat.count}',
                                    style: AppTypography.getLabel(
                                      color: colorScheme.onSurfaceVariant,
                                    ).copyWith(fontSize: 11),
                                  ),
                                ),
                              ],
                              AppSpacing.widthSM,
                              Icon(
                                AppIcons.forward,
                                size: 14,
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
