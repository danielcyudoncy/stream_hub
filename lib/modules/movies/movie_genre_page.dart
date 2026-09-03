import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_library.dart';
import '../../../shared/widgets/search_bar.dart';
import '../../../shared/widgets/tv_focusable.dart';
import 'movie_genre_controller.dart';
import 'widgets/movie_grid.dart';

class MovieGenrePage extends GetView<MovieGenreController> {
  const MovieGenrePage({super.key});

  static final GlobalKey<PopupMenuButtonState<MovieGenreSortOption>> _sortPopupKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Obx(
      () => AppScaffold(
        title: '${controller.genreTitle.value} Movies',
        showNavigation: false,
         actions: [
          TvFocusable(
            onTap: controller.toggleFavoritesOnly,
            borderRadius: AppRadius.medium,
            child: IconButton(
              icon: Icon(
                controller.favoritesOnly.value
                    ? Icons.favorite
                    : AppIcons.favorites,
                color: controller.favoritesOnly.value
                    ? AppColors.darkError
                    : colorScheme.onSurface,
              ),
              tooltip: 'Favorites Only',
              onPressed: null,
            ),
          ),
          _buildSortMenu(context),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: AppSearchBar(
                hintText: 'Search in ${controller.genreTitle.value}...',
                onChanged: controller.setSearchQuery,
                onClear: () => controller.setSearchQuery(''),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.displayedMovies.isEmpty) {
                  final isSearching = controller.searchQuery.value.isNotEmpty;
                  final isFav = controller.favoritesOnly.value;
                  return EmptyLibrary(
                    icon: AppIcons.movies,
                    title: isSearching
                        ? 'No Results Found'
                        : isFav
                            ? 'No Favorite ${controller.genreTitle.value} Movies'
                            : 'No ${controller.genreTitle.value} Movies',
                    description: isSearching
                        ? 'No movies match "${controller.searchQuery.value}".'
                        : isFav
                            ? 'Add ${controller.genreTitle.value} movies to your favorites to find them here.'
                            : 'There are currently no movies in this genre.',
                    actionLabel: isSearching || isFav ? 'Reset Filters' : null,
                    onAction: isSearching || isFav
                        ? () {
                            controller.setSearchQuery('');
                            if (controller.favoritesOnly.value) {
                              controller.toggleFavoritesOnly();
                            }
                          }
                        : null,
                  );
                }

                return MovieGrid(
                  movies: controller.displayedMovies,
                  onMovieTap: controller.openMovie,
                  onToggleFavorite: controller.toggleFavorite,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortMenu(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TvFocusable(
      onTap: () => _sortPopupKey.currentState?.showButtonMenu(),
      borderRadius: AppRadius.medium,
      child: PopupMenuButton<MovieGenreSortOption>(
        key: _sortPopupKey,
        icon: const Icon(AppIcons.sort),
        tooltip: 'Sort Movies',
        onSelected: controller.setSort,
      itemBuilder: (context) => [
        for (final option in MovieGenreSortOption.values)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                if (controller.selectedSort.value == option) ...[
                  Icon(Icons.check_rounded, color: colorScheme.primary, size: 18.0),
                  AppSpacing.widthXS,
                ] else
                  const SizedBox(width: 26.0),
                Text(
                  option.label,
                  style: AppTypography.getBody(
                    color: controller.selectedSort.value == option
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
}

