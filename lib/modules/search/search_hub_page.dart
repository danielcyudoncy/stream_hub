import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_library.dart';
import '../../shared/widgets/premium_media_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/tv_focusable.dart';
import 'search_hub_controller.dart';

class SearchHubPage extends GetView<SearchHubController> {
  const SearchHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTv = PlatformHelper.isTV;

    return AppScaffold(
      title: 'Search',
      showNavigation: false,
      showAppBar: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.heightSM,
            _buildSearchBar(context, colorScheme),
            AppSpacing.heightSM,
            _buildFilterChips(context, colorScheme),
            AppSpacing.heightSM,
            Expanded(
              child: Obx(() {
                final query = controller.searchQuery.value;
                final isLoading = controller.isLoading.value;
                final results = controller.displayedResults;

                if (query.isEmpty) {
                  return _buildEmptyState(context, colorScheme);
                }

                if (isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (results.isEmpty) {
                  return EmptyLibrary(
                    icon: AppIcons.search,
                    title: 'No Results Found',
                    description: 'No matches found for "$query".',
                    actionLabel: 'Clear Search',
                    onAction: controller.clearSearch,
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: isTv ? 200.0 : 170.0,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                  ),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return PremiumMediaCard(
                      item: item,
                      onTap: () => controller.openItem(item),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          TvFocusable(
            key: const ValueKey('search_back_button'),
            onTap: () {
              if (Navigator.canPop(context)) {
                Get.back();
              } else {
                Get.offAllNamed(AppRoutes.home);
              }
            },
            borderRadius: AppRadius.pill,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: Icon(
                AppIcons.back,
                color: colorScheme.onSurface,
                size: 20.0,
              ),
            ),
          ),
          AppSpacing.widthSM,
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.medium,
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    AppIcons.search,
                    color: colorScheme.primary,
                    size: 22.0,
                  ),
                  AppSpacing.widthSM,
                  Expanded(
                    child: TextField(
                      controller: controller.textController,
                      focusNode: controller.searchFocusNode,
                      style: AppTypography.getBody(color: colorScheme.onSurface),
                      textInputAction: TextInputAction.search,
                      onChanged: controller.onSearchChanged,
                      onSubmitted: controller.performSearch,
                      decoration: InputDecoration(
                        hintText: 'Search movies, series, channels...',
                        hintStyle: AppTypography.getBody(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: controller.textController,
                    builder: (context, _) {
                      if (controller.textController.text.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return GestureDetector(
                        key: const ValueKey('search_clear_button'),
                        behavior: HitTestBehavior.opaque,
                        onTap: controller.clearSearch,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          child: Icon(
                            Icons.close,
                            size: 20.0,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, ColorScheme colorScheme) {
    final filters = ['All', 'Movies', 'Series', 'Live TV'];

    return SizedBox(
      height: 36.0,
      child: Obx(() {
        final selected = controller.selectedFilter.value;
        final query = controller.searchQuery.value;
        final selectedProviderId = controller.selectedProviderId.value;
        final selectedProviderName = controller.selectedProviderName.value;
        final isProviderFiltered = selectedProviderId != 'all';

        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          children: [
            // Provider Filter Button
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showProviderPicker(context, colorScheme),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isProviderFiltered
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadius.large,
                  border: Border.all(
                    color: isProviderFiltered
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.dns_rounded,
                      size: 15.0,
                      color: isProviderFiltered
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(
                        selectedProviderName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: AppTypography.getCaption(
                          color: isProviderFiltered
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                        ).copyWith(
                          fontWeight: isProviderFiltered
                              ? FontWeight.bold
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16.0,
                      color: isProviderFiltered
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.widthSM,
            // Media Type Filters
            ...filters.map((filter) {
              final isSelected = selected == filter;
              final count = _getFilterCount(filter);

              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => controller.setFilter(filter),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: AppRadius.large,
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          filter,
                          style: AppTypography.getCaption(
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                          ).copyWith(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (query.isNotEmpty && count > 0) ...[
                          AppSpacing.widthXS,
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.onPrimary.withValues(alpha: 0.2)
                                  : colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Text(
                              '$count',
                              style: AppTypography.getCaption(
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.primary,
                                scale: 0.8,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      }),
    );
  }

  void _showProviderPicker(BuildContext context, ColorScheme colorScheme) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.extraLargeValue)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter by Provider',
                        style: AppTypography.getTitle(color: colorScheme.onSurface)
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    child: Obx(() {
                      final selectedId = controller.selectedProviderId.value;
                      final providers = controller.availableProviders;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.layers_rounded,
                              color: selectedId == 'all'
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            title: Text(
                              'All Providers',
                              style: TextStyle(
                                fontWeight: selectedId == 'all'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              'Search across all connected playlists',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            trailing: selectedId == 'all'
                                ? Icon(Icons.check_circle,
                                    color: colorScheme.primary)
                                : null,
                            onTap: () {
                              controller.setProvider('all', 'All Providers');
                              Navigator.pop(context);
                            },
                          ),
                          ...providers.map((p) {
                            final isSelected = selectedId == p.id;
                            return ListTile(
                              leading: Icon(
                                Icons.dns_rounded,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                              title: Text(
                                p.name,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                p.providerType.displayName,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle,
                                      color: colorScheme.primary)
                                  : null,
                              onTap: () {
                                controller.setProvider(p.id, p.name);
                                Navigator.pop(context);
                              },
                            );
                          }),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.recentSearches.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: SectionHeader(
                title: 'Recent Searches',
                trailing: GestureDetector(
                  onTap: controller.clearRecentSearches,
                  child: Text(
                    'Clear All',
                    style: AppTypography.getCaption(
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            AppSpacing.heightXS,
            _buildRecentSearches(context, colorScheme),
            AppSpacing.heightMD,
          ],
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            child: SectionHeader(title: 'Trending Categories'),
          ),
          AppSpacing.heightXS,
          _buildTrendingSearches(context, colorScheme),
          AppSpacing.heightMD,
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            child: SectionHeader(title: 'Suggestions'),
          ),
          AppSpacing.heightXS,
          _buildSuggestions(context, colorScheme),
        ],
      ),
    );
  }

  int _getFilterCount(String filter) {
    switch (filter) {
      case 'Movies':
        return controller.movieResults.length;
      case 'Series':
        return controller.seriesResults.length;
      case 'Live TV':
        return controller.channelResults.length;
      case 'All':
      default:
        return controller.allResults.length;
    }
  }

  Widget _buildRecentSearches(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final search in controller.recentSearches.take(10))
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.large,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => controller.selectQuery(search),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.history,
                          size: 14.0,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        AppSpacing.widthXS,
                        Text(
                          search,
                          style: AppTypography.getCaption(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.widthXS,
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => controller.removeRecentSearch(search),
                    child: Icon(
                      Icons.close,
                      size: 14.0,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendingSearches(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final search in controller.trendingSearches.take(10))
            _buildSearchChip(context, search, colorScheme),
        ],
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
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
      behavior: HitTestBehavior.opaque,
      onTap: () => controller.selectQuery(query),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
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
