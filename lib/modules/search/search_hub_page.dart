import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';
import 'search_hub_controller.dart';

class SearchHubPage extends GetView<SearchHubController> {
  const SearchHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Search',
      body: Obx(() {
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(context, colorScheme),
                  AppSpacing.heightMD,
                  if (controller.recentSearches.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: SectionHeader(title: 'Recent Searches'),
                    ),
                    AppSpacing.heightXS,
                    _buildRecentSearches(context, colorScheme),
                    AppSpacing.heightMD,
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: SectionHeader(title: 'Trending'),
                  ),
                  AppSpacing.heightXS,
                  _buildTrendingSearches(context, colorScheme),
                  AppSpacing.heightMD,
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: SectionHeader(title: 'Suggestions'),
                  ),
                  AppSpacing.heightXS,
                  _buildSuggestions(context, colorScheme),
                  AppSpacing.heightXXL,
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSearchBar(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        child: Row(
          children: [
            Icon(
              AppIcons.search,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              size: 20.0,
            ),
            AppSpacing.widthSM,
            Expanded(
              child: Text(
                'Search across all media...',
                style: AppTypography.getBody(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            Icon(
              AppIcons.filter,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              size: 20.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSearches(BuildContext context, ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          for (final search in controller.recentSearches.take(10))
            _buildSearchChip(context, search, colorScheme),
        ],
      ),
    );
  }

  Widget _buildTrendingSearches(BuildContext context, ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          for (final search in controller.trendingSearches.take(10))
            _buildSearchChip(context, search, colorScheme),
        ],
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context, ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          for (final suggestion in controller.suggestions.take(10))
            _buildSearchChip(context, suggestion, colorScheme),
        ],
      ),
    );
  }

  Widget _buildSearchChip(
    BuildContext context,
    String query,
    ColorScheme colorScheme,
  ) {
    return GestureDetector(
      onTap: () {
        controller.searchQuery.value = query;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.large,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.search,
              size: 14.0,
              color: colorScheme.onSurfaceVariant,
            ),
            AppSpacing.widthXS,
            Text(
              query,
              style: AppTypography.getCaption(color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
