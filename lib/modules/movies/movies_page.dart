import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_library.dart';
import '../../../shared/widgets/provider_selector_button.dart';
import '../../../shared/widgets/tv_focusable.dart';
import 'movies_controller.dart';
import 'widgets/continue_watching_movie_card.dart';
import 'widgets/movie_card.dart';
import 'widgets/movie_carousel.dart';
import 'widgets/movie_hero_carousel.dart';

class MoviesPage extends GetView<MoviesController> {
  const MoviesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTv = PlatformHelper.isTV;

    return AppScaffold(
      title: 'Movies',
      actions: [
        Obx(
          () => ProviderSelectorButton(
            selectedProviderId: controller.selectedProvider.value,
            onSelectProvider: (providerId) =>
                controller.setProvider(providerId),
            sheetTitle: 'Movies Provider',
          ),
        ),
        IconButton(
          icon: const Icon(AppIcons.search),
          onPressed: () => Get.toNamed(AppRoutes.search),
          tooltip: 'Search',
          visualDensity: VisualDensity.compact,
        ),
      ],
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.movies.isEmpty) {
          return EmptyLibrary(
            icon: AppIcons.movies,
            title: 'No Movies Yet',
            description:
                'Add a provider with movie content to start watching.',
            actionLabel: 'Add Media Source',
            onAction: () => Get.toNamed(AppRoutes.providerManager),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: CustomScrollView(
            slivers: [
              // 1. Featured Hero Carousel
              if (controller.featuredMovies.isNotEmpty ||
                  controller.heroMovie.value != null) ...[
                SliverToBoxAdapter(
                  child: MovieHeroCarousel(
                    movies: controller.featuredMovies.isNotEmpty
                        ? controller.featuredMovies
                        : [controller.heroMovie.value!],
                    getResumePosition: (id) =>
                        controller.sessionsMap[id]?.resumePosition,
                    isFavorite: (id) =>
                        controller.movies
                            .firstWhereOrNull((m) => m.id == id)
                            ?.favorite ??
                        false,
                    onWatch: controller.resumeMovie,
                    onDetails: controller.openMovie,
                    onToggleFavorite: controller.toggleFavorite,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
              ],

              // 2. Movie Categories & Genres Filter Chips Bar
              Obx(() {
                if (controller.availableGenres.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                          itemCount: controller.availableGenres.length,
                          separatorBuilder: (context, index) =>
                              AppSpacing.widthXS,
                          itemBuilder: (context, index) {
                            final genre = controller.availableGenres[index];
                            return TvFocusable(
                              onTap: () => controller.openGenreByName(genre),
                              borderRadius: AppRadius.pill,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xxs,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerLow,
                                  borderRadius: AppRadius.pill,
                                  border: Border.all(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    genre,
                                    style: AppTypography.getLabel(
                                      color: colorScheme.onSurface,
                                    ).copyWith(fontSize: 12),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      AppSpacing.heightMD,
                    ],
                  ),
                );
              }),

              // 3. Continue Watching Row
              if (controller.continueWatchingMovies.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildContinueWatchingSection(context),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
              ],

              // 3. Trending Movies Carousel
              if (controller.trendingMovies.isNotEmpty)
                SliverToBoxAdapter(
                  child: MovieCarousel(
                    title: 'Trending Movies',
                    subtitle: 'Most popular right now',
                    movies: controller.trendingMovies,
                    progressMap: controller.progressMap,
                    completedIds: controller.completedIds,
                    onMovieTap: controller.openMovie,
                    onSeeAll: () => controller.openGenre(
                      'Trending',
                      controller.trendingMovies,
                    ),
                    onToggleFavorite: controller.toggleFavorite,
                  ),
                ),

              // 4. New This Week Carousel
              if (controller.newThisWeekMovies.isNotEmpty)
                SliverToBoxAdapter(
                  child: MovieCarousel(
                    title: 'New Releases',
                    subtitle: 'Recently added titles',
                    movies: controller.newThisWeekMovies,
                    progressMap: controller.progressMap,
                    completedIds: controller.completedIds,
                    onMovieTap: controller.openMovie,
                    onSeeAll: () => controller.openGenre(
                      'New Releases',
                      controller.newThisWeekMovies,
                    ),
                    onToggleFavorite: controller.toggleFavorite,
                  ),
                ),

              // 5. Top Rated Carousel
              if (controller.topRatedMovies.isNotEmpty)
                SliverToBoxAdapter(
                  child: MovieCarousel(
                    title: 'Top Rated',
                    subtitle: 'Critically acclaimed movies',
                    movies: controller.topRatedMovies,
                    progressMap: controller.progressMap,
                    completedIds: controller.completedIds,
                    onMovieTap: controller.openMovie,
                    onSeeAll: () => controller.openGenre(
                      'Top Rated',
                      controller.topRatedMovies,
                    ),
                    onToggleFavorite: controller.toggleFavorite,
                  ),
                ),

              // 6. Dynamic Genres Carousels
              for (final entry in controller.genreSections.entries)
                SliverToBoxAdapter(
                  child: MovieCarousel(
                    title: entry.key,
                    movies: entry.value,
                    progressMap: controller.progressMap,
                    completedIds: controller.completedIds,
                    onMovieTap: controller.openMovie,
                    onSeeAll: () => controller.openGenre(
                      entry.key,
                      entry.value,
                    ),
                    onToggleFavorite: controller.toggleFavorite,
                  ),
                ),

              // 7. Curated Fallback Sections (if dynamic genres didn't cover them)
              if (controller.mysteryThrillerMovies.isNotEmpty &&
                  !controller.genreSections.containsKey('Mystery') &&
                  !controller.genreSections.containsKey('Thriller'))
                SliverToBoxAdapter(
                  child: MovieCarousel(
                    title: 'Mystery & Thriller',
                    movies: controller.mysteryThrillerMovies,
                    progressMap: controller.progressMap,
                    completedIds: controller.completedIds,
                    onMovieTap: controller.openMovie,
                    onSeeAll: () => controller.openGenre(
                      'Mystery & Thriller',
                      controller.mysteryThrillerMovies,
                    ),
                    onToggleFavorite: controller.toggleFavorite,
                  ),
                ),

              if (controller.romanticComedyMovies.isNotEmpty &&
                  !controller.genreSections.containsKey('Romance') &&
                  !controller.genreSections.containsKey('Comedy'))
                SliverToBoxAdapter(
                  child: MovieCarousel(
                    title: 'Romantic Comedies',
                    movies: controller.romanticComedyMovies,
                    progressMap: controller.progressMap,
                    completedIds: controller.completedIds,
                    onMovieTap: controller.openMovie,
                    onSeeAll: () => controller.openGenre(
                      'Romantic Comedies',
                      controller.romanticComedyMovies,
                    ),
                    onToggleFavorite: controller.toggleFavorite,
                  ),
                ),

              // 8. All Movies Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'All Movies',
                        style: AppTypography.getTitle(
                          color: colorScheme.onSurface,
                          scale: isTv ? 1.05 : 0.95,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${controller.movies.length} titles',
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 9. All Movies Grid
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: isTv ? 200.0 : 170.0,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.65,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = controller.movies[index];
                      final progress = controller.progressMap[item.id];
                      final isDone = controller.completedIds.contains(item.id);

                      return MovieCard(
                        item: item,
                        progressPercentage: progress,
                        isCompleted: isDone,
                        onTap: () => controller.openMovie(item),
                        onToggleFavorite: () =>
                            controller.toggleFavorite(item),
                      );
                    },
                    childCount: controller.movies.length,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildContinueWatchingSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTv = PlatformHelper.isTV;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            'Continue Watching',
            style: AppTypography.getTitle(
              color: colorScheme.onSurface,
              scale: isTv ? 1.05 : 0.95,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 165.0,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            scrollDirection: Axis.horizontal,
            itemCount: controller.continueWatchingMovies.length,
            separatorBuilder: (context, index) => AppSpacing.widthMD,
            itemBuilder: (context, index) {
              final movie = controller.continueWatchingMovies[index];
              final session = controller.sessionsMap[movie.id];
              final position = session?.resumePosition ?? Duration.zero;
              final duration = movie.durationMinutes != null
                  ? Duration(minutes: movie.durationMinutes!)
                  : (position > Duration.zero
                      ? Duration(
                          milliseconds: (position.inMilliseconds /
                                  (session?.completionPercentage ?? 0.5))
                              .round(),
                        )
                      : Duration.zero);

              return ContinueWatchingMovieCard(
                item: movie,
                position: position,
                duration: duration,
                onResume: () => controller.resumeMovie(movie),
                onDetails: () => controller.openMovie(movie),
              );
            },
          ),
        ),
      ],
    );
  }
}
