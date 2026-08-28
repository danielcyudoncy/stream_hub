import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_library.dart';
import '../../../shared/widgets/tv_focusable.dart';
import 'movie_details_controller.dart';
import 'widgets/movie_carousel.dart';
import 'widgets/movie_inline_player.dart';

class MovieDetailsPage extends GetView<MovieDetailsController> {
  const MovieDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isTV = PlatformHelper.isTV;

    // Auto-exit fullscreen if device is rotated back to portrait
    if (!isLandscape && controller.isFullscreenMode.value && !isTV) {
      if (DateTime.now().difference(controller.lastFullscreenEntered).inMilliseconds > 500) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.isFullscreenMode.value) {
            controller.exitFullscreen();
          }
        });
      }
    }

    return Obx(() {
      if (controller.isFullscreenMode.value && controller.movie != null) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            controller.exitFullscreen();
          },
          child: AppScaffold(
            title: controller.movie!.title,
            showAppBar: false,
            showNavigation: false,
            body: Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: MovieInlinePlayer(
                key: controller.embeddedPlayerKey,
                controller: controller,
                isFullscreen: true,
              ),
            ),
          ),
        );
      }

      return AppScaffold(
        title: 'Movie Details',
        showNavigation: false,
        actions: [
          Obx(
            () => TvFocusable(
              onTap: controller.toggleFavorite,
              borderRadius: AppRadius.medium,
              scale: 1.05,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  controller.isFavorite.value
                      ? Icons.favorite
                      : AppIcons.favorites,
                  color: controller.isFavorite.value
                      ? AppColors.darkError
                      : colorScheme.onSurface,
                  size: 22.0,
                ),
              ),
            ),
          ),
        ],
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage.value.isNotEmpty || controller.movie == null) {
            return EmptyLibrary(
              icon: AppIcons.error,
              title: 'Movie Unavailable',
              description: controller.errorMessage.value.isNotEmpty
                  ? controller.errorMessage.value
                  : 'Could not load movie information.',
              actionLabel: 'Try Again',
              onAction: controller.reload,
            );
          }

          final movie = controller.movie!;
          return _buildContent(context, movie);
        }),
      );
    });
  }

  Widget _buildContent(BuildContext context, MediaItem movie) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        final isTv = PlatformHelper.isTV;

        if (isLandscape && !isTv) {
          return _buildLandscapeLayout(context, movie, constraints);
        }

        final isWide = constraints.maxWidth >= 800;
        final playerWidth = constraints.maxWidth.clamp(0.0, 1000.0);
        final playerHeight = (playerWidth - (AppSpacing.md * 2)) * (9 / 16) + AppSpacing.xs + AppSpacing.sm;

        return Obx(() {
          final isPlaying = controller.isInlinePlayerActive.value;

          return CustomScrollView(
            slivers: [
              if (isPlaying)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyMoviePlayerHeaderDelegate(
                    height: playerHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: MovieInlinePlayer(
                        key: controller.embeddedPlayerKey,
                        controller: controller,
                      ),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: isWide || isTv
                      ? _buildWideHero(context, movie, isTv)
                      : _buildMobileHero(context, movie),
                ),
              SliverToBoxAdapter(
                child: _buildDetailsSection(context, movie, isWide || isTv),
              ),
              Obx(() {
                if (controller.cast.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCastSection(context),
                      AppSpacing.heightMD,
                    ],
                  ),
                );
              }),
              Obx(() {
                if (controller.relatedMovies.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MovieCarousel(
                        title: 'Related Movies',
                        subtitle: 'More like this',
                        movies: controller.relatedMovies,
                        onMovieTap: controller.openRelatedMovie,
                      ),
                      AppSpacing.heightXXL,
                    ],
                  ),
                );
              }),
            ],
          );
        });
      },
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    MediaItem movie,
    BoxConstraints constraints,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Pane (48% width): Inline Player / Hero Poster + Title + Meta + CTA Buttons
        SizedBox(
          width: constraints.maxWidth * 0.48,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Obx(() {
              final isPlaying = controller.isInlinePlayerActive.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.medium,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: isPlaying
                          ? MovieInlinePlayer(
                              key: controller.embeddedPlayerKey,
                              controller: controller,
                            )
                          : _buildLandscapeHeroPoster(context, movie),
                    ),
                  ),
                  AppSpacing.heightMD,
                  Text(
                    movie.title,
                    style: AppTypography.getTitle(
                      color: colorScheme.onSurface,
                      scale: 1.15,
                    ).copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppSpacing.heightSM,
                  _buildMetaChipsRow(context, movie),
                  AppSpacing.heightMD,
                  _buildActionButtons(context),
                ],
              );
            }),
          ),
        ),
        // Subtle Vertical Divider
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
        // Right Pane: Scrollable Overview + Details + Cast + Related
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildDetailsSection(context, movie, true),
              ),
              Obx(() {
                if (controller.cast.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCastSection(context),
                      AppSpacing.heightMD,
                    ],
                  ),
                );
              }),
              Obx(() {
                if (controller.relatedMovies.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MovieCarousel(
                        title: 'Related Movies',
                        subtitle: 'More like this',
                        movies: controller.relatedMovies,
                        onMovieTap: controller.openRelatedMovie,
                      ),
                      AppSpacing.heightXXL,
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeHeroPoster(BuildContext context, MediaItem movie) {
    final colorScheme = Theme.of(context).colorScheme;
    final backdrop = movie.resolvedBackdropUrl ??
        movie.backdrop ??
        movie.poster ??
        movie.thumbnail;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (backdrop != null && backdrop.isNotEmpty)
          Image.network(
            backdrop,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _placeholder(colorScheme),
          )
        else
          _placeholder(colorScheme),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.6),
              ],
            ),
          ),
        ),
        Center(
          child: TvFocusable(
            onTap: controller.play,
            borderRadius: AppRadius.pill,
            child: Container(
              width: 52.0,
              height: 52.0,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.darkPrimary.withValues(alpha: 0.5),
                    blurRadius: 14.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32.0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHero(BuildContext context, MediaItem movie) {
    final colorScheme = Theme.of(context).colorScheme;
    final backdrop = movie.resolvedBackdropUrl ?? movie.backdrop ?? movie.poster ?? movie.thumbnail;
    final poster = movie.resolvedPosterUrl ?? movie.poster ?? movie.thumbnail;

    return SizedBox(
      height: 280.0,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backdrop != null && backdrop.isNotEmpty)
            Image.network(
              backdrop,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _placeholder(colorScheme),
            )
          else
            _placeholder(colorScheme),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.95),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // Central Play Tap Button
          Center(
            child: TvFocusable(
              onTap: controller.play,
              borderRadius: AppRadius.pill,
              child: Container(
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.85),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 16.0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 36.0,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.md,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (poster != null && poster.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: AppRadius.medium,
                    child: SizedBox(
                      width: 90.0,
                      height: 135.0,
                      child: Image.network(
                        poster,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _placeholder(colorScheme),
                      ),
                    ),
                  ),
                  AppSpacing.widthMD,
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.getHeadline(
                          color: Colors.white,
                          scale: 0.95,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (movie.originalTitle != null) ...[
                        AppSpacing.heightXXS,
                        Text(
                          movie.originalTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.getCaption(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideHero(BuildContext context, MediaItem movie, bool isTv) {
    final colorScheme = Theme.of(context).colorScheme;
    final backdrop = movie.resolvedBackdropUrl ?? movie.backdrop ?? movie.poster ?? movie.thumbnail;
    final poster = movie.resolvedPosterUrl ?? movie.poster ?? movie.thumbnail;

    return SizedBox(
      height: isTv ? 450.0 : 380.0,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backdrop != null && backdrop.isNotEmpty)
            Image.network(
              backdrop,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _placeholder(colorScheme),
            )
          else
            _placeholder(colorScheme),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.95),
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),

          Positioned(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: AppSpacing.xl,
            top: AppSpacing.xl,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (poster != null && poster.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: AppRadius.large,
                    child: SizedBox(
                      width: isTv ? 160.0 : 140.0,
                      height: isTv ? 240.0 : 210.0,
                      child: Image.network(
                        poster,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _placeholder(colorScheme),
                      ),
                    ),
                  ),
                  AppSpacing.widthXL,
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.getDisplay(
                          color: Colors.white,
                          scale: isTv ? 0.9 : 0.8,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (movie.originalTitle != null) ...[
                        AppSpacing.heightXXS,
                        Text(
                          movie.originalTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.getBody(color: Colors.white70),
                        ),
                      ],
                      AppSpacing.heightSM,
                      _buildMetaChipsRow(context, movie),
                      AppSpacing.heightMD,
                      _buildActionButtons(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(
    BuildContext context,
    MediaItem movie,
    bool isWide,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final description = movie.description;
    final director = movie.director;
    final country = movie.resolvedCountry;
    final language = movie.resolvedLanguage;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isWide) ...[
            _buildMetaChipsRow(context, movie),
            AppSpacing.heightMD,
            _buildActionButtons(context),
            AppSpacing.heightLG,
          ],

          // Description / Overview
          if (description != null && description.isNotEmpty) ...[
            Text(
              'Overview',
              style: AppTypography.getTitle(
                color: colorScheme.onSurface,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
            AppSpacing.heightXS,
            Text(
              description,
              style: AppTypography.getBody(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.heightMD,
          ],

          // Metadata Grid (Director, Country, Language)
          if (director != null || country != null || language != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: AppRadius.medium,
              ),
              child: Column(
                children: [
                  if (director != null)
                    _metaRow('Director', director, colorScheme),
                  if (country != null)
                    _metaRow('Country', country, colorScheme),
                  if (language != null)
                    _metaRow('Language', language, colorScheme),
                  _metaRow(
                    'Provider',
                    movie.providerType.displayName,
                    colorScheme,
                  ),
                ],
              ),
            ),
            AppSpacing.heightLG,
          ],
        ],
      ),
    );
  }

  Widget _buildMetaChipsRow(BuildContext context, MediaItem movie) {
    final colorScheme = Theme.of(context).colorScheme;
    final rating = movie.formattedRating;
    final year = movie.releaseYear;
    final duration = movie.formattedDuration;
    final is4k = movie.is4k;
    final qualityLabel = is4k ? '4K UHD' : 'HD';

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (rating != null && rating.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: AppRadius.small,
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.6),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 14.0),
                const SizedBox(width: 3.0),
                Text(
                  rating,
                  style: AppTypography.getCaption(
                    color: Colors.amber,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        if (year != null) _chip('$year', colorScheme),
        if (duration != null) _chip(duration, colorScheme),
        _chip(qualityLabel, colorScheme),
        for (final genre in movie.genres.take(3)) _chip(genre, colorScheme),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Obx(() {
      final isPlaying = controller.isInlinePlayerActive.value;
      final action = controller.playAction.value;
      final isFav = controller.isFavorite.value;

      String playLabel;
      IconData playIcon;

      if (isPlaying) {
        playLabel = 'Stop';
        playIcon = Icons.stop_rounded;
      } else {
        switch (action) {
          case MoviePlayAction.resume:
            playLabel = 'Resume';
            playIcon = AppIcons.play;
            break;
          case MoviePlayAction.watchAgain:
            playLabel = 'Watch Again';
            playIcon = Icons.replay_rounded;
            break;
          case MoviePlayAction.play:
            playLabel = 'Play';
            playIcon = AppIcons.play;
            break;
        }
      }

      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Primary Play / Stop Button
          TvFocusable(
            onTap: isPlaying ? controller.stopInlinePlayback : controller.play,
            borderRadius: AppRadius.pill,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                gradient: isPlaying
                    ? null
                    : const LinearGradient(
                        colors: AppColors.primaryGradient,
                      ),
                color: isPlaying ? AppColors.darkError : null,
                borderRadius: AppRadius.pill,
                boxShadow: isPlaying
                    ? [
                        BoxShadow(
                          color: AppColors.darkError.withValues(alpha: 0.4),
                          blurRadius: 8.0,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(playIcon, color: Colors.white, size: 20.0),
                  AppSpacing.widthXS,
                  Text(
                    playLabel,
                    style: AppTypography.getButton(
                      color: Colors.white,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // Favorite Toggle Button
          TvFocusable(
            onTap: controller.toggleFavorite,
            borderRadius: AppRadius.pill,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: isFav
                    ? AppColors.darkError.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: AppRadius.pill,
                border: Border.all(
                  color: isFav
                      ? AppColors.darkError.withValues(alpha: 0.6)
                      : Colors.white24,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFav ? AppColors.darkError : Colors.white,
                    size: 18.0,
                  ),
                  AppSpacing.widthXXS,
                  Text(
                    isFav ? 'In Favorites' : 'My List',
                    style: AppTypography.getButton(
                      color: isFav ? AppColors.darkError : Colors.white,
                      scale: 0.9,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Share Button
          TvFocusable(
            onTap: () {
              Get.snackbar(
                'Share',
                'Sharing "${controller.movie?.title}"',
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
              );
            },
            borderRadius: AppRadius.pill,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(
                Icons.share_rounded,
                color: Colors.white,
                size: 18.0,
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildCastSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            'Cast',
            style: AppTypography.getTitle(
              color: colorScheme.onSurface,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        AppSpacing.heightSM,
        SizedBox(
          height: 110.0,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            scrollDirection: Axis.horizontal,
            itemCount: controller.cast.length,
            separatorBuilder: (context, index) => AppSpacing.widthMD,
            itemBuilder: (context, index) {
              final member = controller.cast[index];
              return SizedBox(
                width: 80.0,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28.0,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      backgroundImage: member.profileUrl != null &&
                              member.profileUrl!.isNotEmpty
                          ? NetworkImage(member.profileUrl!)
                          : null,
                      child: member.profileUrl == null ||
                              member.profileUrl!.isEmpty
                          ? Icon(
                              Icons.person_rounded,
                              size: 28.0,
                              color: colorScheme.primary.withValues(alpha: 0.6),
                            )
                          : null,
                    ),
                    AppSpacing.heightXXS,
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.getCaption(
                        color: colorScheme.onSurface,
                        scale: 0.85,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (member.character != null && member.character!.isNotEmpty)
                      Text(
                        member.character!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurfaceVariant,
                          scale: 0.75,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _metaRow(String label, String value, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.0,
            child: Text(
              label,
              style: AppTypography.getCaption(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.getBody(
                color: colorScheme.onSurface,
                scale: 0.9,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        label,
        style: AppTypography.getCaption(
          color: colorScheme.onSurfaceVariant,
          scale: 0.85,
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme colorScheme) {
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          AppIcons.movies,
          size: 64.0,
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _StickyMoviePlayerHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _StickyMoviePlayerHeaderDelegate({
    required this.height,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      height: height,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyMoviePlayerHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
