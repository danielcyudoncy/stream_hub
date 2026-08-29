import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/cast_member.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/series_progress.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_library.dart';
import '../../../shared/widgets/tv_focusable.dart';
import 'series_details_controller.dart';
import 'widgets/episode_card.dart';
import 'widgets/series_carousel.dart';
import 'widgets/series_inline_player.dart';

class SeriesDetailsPage extends StatefulWidget {
  const SeriesDetailsPage({super.key});

  @override
  State<SeriesDetailsPage> createState() => _SeriesDetailsPageState();
}

class _SeriesDetailsPageState extends State<SeriesDetailsPage> {
  late final SeriesDetailsController _controller =
      Get.find<SeriesDetailsController>();
  final ScrollController _scrollController = ScrollController();
  Worker? _seriesWorker;

  @override
  void initState() {
    super.initState();
    _seriesWorker = ever(_controller.seriesRx, (_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _seriesWorker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isTv = PlatformHelper.isTV;

    // Auto-exit fullscreen if device is rotated back to portrait
    if (!isLandscape && _controller.isFullscreenMode.value && !isTv) {
      if (DateTime.now().difference(_controller.lastFullscreenEntered).inMilliseconds > 500) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_controller.isFullscreenMode.value) {
            _controller.exitFullscreen();
          }
        });
      }
    }

    return Obx(() {
      if (_controller.isFullscreenMode.value) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _controller.exitFullscreen();
          },
          child: AppScaffold(
            title: _controller.seriesTitle,
            showAppBar: false,
            showNavigation: false,
            body: Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: SeriesInlinePlayer(
                key: _controller.embeddedPlayerKey,
                controller: _controller,
                isFullscreen: true,
              ),
            ),
          ),
        );
      }

      return AppScaffold(
        title: _controller.seriesTitle,
        showNavigation: false,
        actions: [
          Obx(
            () => TvFocusable(
              onTap: _controller.toggleFavorite,
              borderRadius: AppRadius.medium,
              scale: 1.05,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  _controller.isFavorite.value ? Icons.favorite : AppIcons.favorites,
                  color: _controller.isFavorite.value
                      ? AppColors.darkError
                      : colorScheme.onSurface,
                  size: 22.0,
                ),
              ),
            ),
          ),
        ],
        body: Obx(() {
          if (_controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.errorMessage.value.isNotEmpty) {
            return EmptyLibrary(
              icon: AppIcons.error,
              title: 'Episodes Unavailable',
              description: _controller.errorMessage.value,
              actionLabel: 'Try Again',
              onAction: _controller.retry,
            );
          }

          if (_controller.seasons.isEmpty) {
            final hasInfo = _controller.infoMessage.value.isNotEmpty;
            return EmptyLibrary(
              icon: AppIcons.series,
              title: hasInfo ? 'Episodes Unavailable' : 'No Episodes Yet',
              description: hasInfo
                  ? _controller.infoMessage.value
                  : 'This series has no episodes available right now.',
              actionLabel: hasInfo ? 'Try Again' : null,
              onAction: hasInfo ? _controller.retry : null,
            );
          }

          return _buildContent(context);
        }),
      );
    });
  }

  Widget _buildContent(BuildContext context) {
    final series = _controller.series;
    if (series == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        final isTv = PlatformHelper.isTV;

        if (isLandscape && !isTv) {
          return _buildLandscapeLayout(context, series, constraints);
        }

        final playerWidth = constraints.maxWidth.clamp(0.0, 1000.0);
        final playerHeight = (playerWidth - (AppSpacing.md * 2)) * (9 / 16) + AppSpacing.xs + AppSpacing.sm;

        return Obx(() {
          final isPlaying = _controller.isInlinePlayerActive.value;
          final selectedSeason = _controller.selectedSeason;
          final prog = _controller.seriesProgress.value;
          final activeEp = _controller.activeEpisode.value;

          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              if (isPlaying)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickySeriesPlayerHeaderDelegate(
                    minHeight: playerHeight,
                    maxHeight: playerHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: ClipRRect(
                        borderRadius: AppRadius.medium,
                        child: SeriesInlinePlayer(
                          key: _controller.embeddedPlayerKey,
                          controller: _controller,
                          isFullscreen: false,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(child: _buildHero(context, series)),

              SliverToBoxAdapter(child: _buildMeta(context, series, prog)),
              SliverToBoxAdapter(child: _buildActionButtons(context, prog)),
              if (_controller.castMembers.isNotEmpty)
                SliverToBoxAdapter(child: _buildCastSection(context)),
              if (_controller.seasonCount > 1)
                SliverToBoxAdapter(child: _buildSeasonSelector(context)),
              if (selectedSeason != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  sliver: SliverList.separated(
                    itemCount: selectedSeason.episodes.length,
                    separatorBuilder: (context, index) => AppSpacing.heightXS,
                    itemBuilder: (context, index) {
                      final episode = selectedSeason.episodes[index];
                      final episodeNumber = _resolveEpisodeCode(episode);
                      final epProgress = _controller.episodeProgressMap[episode.id];
                      final isCompleted = _controller.completedEpisodeIds.contains(episode.id);
                      final isNextUp = prog?.nextEpisodeToWatch?.id == episode.id;
                      final isCurrentlyPlaying = isPlaying && activeEp?.id == episode.id;

                      return EpisodeCard(
                        key: ValueKey('ep-${episode.id}'),
                        episode: episode,
                        episodeNumber: episodeNumber,
                        progressPercentage: epProgress,
                        isCompleted: isCompleted,
                        isNextUp: isNextUp,
                        isCurrentlyPlaying: isCurrentlyPlaying,
                        onTap: () => _controller.playEpisode(episode),
                      );
                    },
                  ),
                ),
              if (_controller.relatedSeries.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: SeriesCarousel(
                      title: 'More Like This',
                      series: _controller.relatedSeries,
                      onSeriesTap: _controller.openRelatedSeries,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
          );
        });
      },
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    MediaItem series,
    BoxConstraints constraints,
  ) {
    final prog = _controller.seriesProgress.value;
    final selectedSeason = _controller.selectedSeason;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Pane (48% width): Inline Player / Hero Poster + Series/Episode Title + Meta + Primary Action Button
        SizedBox(
          width: constraints.maxWidth * 0.48,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 16:9 Video Player or Hero Backdrop Poster
                Obx(() {
                  final isPlaying = _controller.isInlinePlayerActive.value;
                  if (isPlaying) {
                    return ClipRRect(
                      borderRadius: AppRadius.medium,
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: SeriesInlinePlayer(
                          key: _controller.embeddedPlayerKey,
                          controller: _controller,
                          isFullscreen: false,
                        ),
                      ),
                    );
                  }
                  return _buildLandscapeHeroPoster(context, series);
                }),
                AppSpacing.heightSM,

                // Series Title & Subtitle / Episode Title
                Obx(() {
                  final activeEp = _controller.activeEpisode.value;
                  final isPlaying = _controller.isInlinePlayerActive.value;
                  final epCode = activeEp != null ? _resolveEpisodeCode(activeEp) : '';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        series.title,
                        style: AppTypography.getTitle(color: Colors.white).copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isPlaying && activeEp != null) ...[
                        AppSpacing.heightXXS,
                        Text(
                          epCode.isNotEmpty ? '$epCode: ${activeEp.title}' : activeEp.title,
                          style: AppTypography.getCaption(
                            color: Theme.of(context).colorScheme.primary,
                            scale: 0.9,
                          ).copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else if (series.subtitle != null) ...[
                        AppSpacing.heightXXS,
                        Text(
                          series.subtitle!,
                          style: AppTypography.getCaption(color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  );
                }),
                AppSpacing.heightXS,

                // Metadata Chips & Overview
                _buildMeta(context, series, prog),
                AppSpacing.heightXS,

                // Primary Play / Resume / Stop Action Button + Favorite
                _buildActionButtons(context, prog),
              ],
            ),
          ),
        ),

        // Vertical Divider
        Container(
          width: 1.0,
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),

        // Right Pane (52% width): Scrollable Season Tabs + Episode Cards + Cast Carousel + Related Series
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              if (_controller.seasonCount > 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: _buildSeasonSelector(context),
                  ),
                ),
              if (selectedSeason != null)
                Obx(() {
                  final isPlaying = _controller.isInlinePlayerActive.value;
                  final activeEp = _controller.activeEpisode.value;

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    sliver: SliverList.separated(
                      itemCount: selectedSeason.episodes.length,
                      separatorBuilder: (context, index) => AppSpacing.heightXS,
                      itemBuilder: (context, index) {
                        final episode = selectedSeason.episodes[index];
                        final episodeNumber = _resolveEpisodeCode(episode);
                        final epProgress = _controller.episodeProgressMap[episode.id];
                        final isCompleted = _controller.completedEpisodeIds.contains(episode.id);
                        final isNextUp = prog?.nextEpisodeToWatch?.id == episode.id;
                        final isCurrentlyPlaying = isPlaying && activeEp?.id == episode.id;

                        return EpisodeCard(
                          key: ValueKey('ep-land-${episode.id}'),
                          episode: episode,
                          episodeNumber: episodeNumber,
                          progressPercentage: epProgress,
                          isCompleted: isCompleted,
                          isNextUp: isNextUp,
                          isCurrentlyPlaying: isCurrentlyPlaying,
                          onTap: () => _controller.playEpisode(episode),
                        );
                      },
                    ),
                  );
                }),
              if (_controller.castMembers.isNotEmpty)
                SliverToBoxAdapter(child: _buildCastSection(context)),
              if (_controller.relatedSeries.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: SeriesCarousel(
                      title: 'More Like This',
                      series: _controller.relatedSeries,
                      onSeriesTap: _controller.openRelatedSeries,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeHeroPoster(BuildContext context, MediaItem series) {
    final colorScheme = Theme.of(context).colorScheme;
    final rawBackdrop = series.backdrop ?? series.poster ?? series.thumbnail;
    final backdrop = ImageUrlFormatter.format(rawBackdrop, item: series) ??
        ImageUrlFormatter.extractFromMediaItem(series);

    return ClipRRect(
      borderRadius: AppRadius.medium,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (backdrop != null && backdrop.isNotEmpty)
              Image.network(
                backdrop,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    ColoredBox(color: colorScheme.surfaceContainerHighest),
              )
            else
              ColoredBox(color: colorScheme.surfaceContainerHighest),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
            Center(
              child: GestureDetector(
                onTap: _controller.playPrimaryAction,
                child: Container(
                  width: 52.0,
                  height: 52.0,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: AppColors.primaryGradient),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.darkPrimary.withValues(alpha: 0.5),
                        blurRadius: 16.0,
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
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, MediaItem series) {
    final colorScheme = Theme.of(context).colorScheme;
    final rawPoster = series.poster ?? series.thumbnail;
    final poster = ImageUrlFormatter.format(rawPoster, item: series) ??
        ImageUrlFormatter.extractFromMediaItem(series);
    final rawBackdrop = series.backdrop;
    final backdrop = ImageUrlFormatter.format(rawBackdrop, item: series) ??
        poster;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTv = constraints.maxWidth >= 900;
        final heroHeight = isTv
            ? (constraints.maxHeight * 0.52).clamp(320.0, 560.0)
            : (constraints.maxHeight * 0.38).clamp(240.0, 380.0);

        return SizedBox(
          width: double.infinity,
          height: heroHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (backdrop != null && backdrop.isNotEmpty)
                Image.network(
                  backdrop,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      ColoredBox(color: colorScheme.surfaceContainerHighest),
                )
              else if (poster != null && poster.isNotEmpty)
                Image.network(
                  poster,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      ColoredBox(color: colorScheme.surfaceContainerHighest),
                )
              else
                ColoredBox(color: colorScheme.surfaceContainerHighest),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (poster != null && poster.isNotEmpty)
                      ClipRRect(
                        borderRadius: AppRadius.medium,
                        child: SizedBox(
                          width: isTv ? 140.0 : 100.0,
                          height: isTv ? 200.0 : 150.0,
                          child: Image.network(
                            poster,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _posterPlaceholder(colorScheme),
                          ),
                        ),
                      ),
                    if (poster != null && poster.isNotEmpty) AppSpacing.widthMD,
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              series.title,
                              style: AppTypography.getHeadline(
                                color: Colors.white,
                                scale: isTv ? 1.1 : 0.9,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (series.subtitle != null) ...[
                              AppSpacing.heightXXS,
                              Text(
                                series.subtitle!,
                                style: AppTypography.getCaption(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _posterPlaceholder(ColorScheme colorScheme) {
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          AppIcons.series,
          size: 32.0,
          color: colorScheme.primary.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildMetaChipsRow(BuildContext context, MediaItem series) {
    final colorScheme = Theme.of(context).colorScheme;
    final rating = series.formattedRating;
    final year = series.releaseYear?.toString() ?? series.metadata['year']?.toString();
    final is4k = series.is4k || (series.metadata['resolution']?.toString().contains('4k') ?? false);
    final isFhd = (series.metadata['resolution']?.toString().contains('1080') ?? false) ||
        (series.title.toUpperCase().contains('FHD')) ||
        (series.title.toUpperCase().contains('1080P'));
    final qualityLabel = is4k ? '4K UHD' : (isFhd ? 'FHD' : 'HD');

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
        if (year != null && year.isNotEmpty)
          _MetaChip(label: year, colorScheme: colorScheme),
        _MetaChip(label: qualityLabel, colorScheme: colorScheme, emphasized: true),
        if (_controller.seasonCount > 0)
          _MetaChip(
            label: '${_controller.seasonCount} ${_controller.seasonCount == 1 ? 'Season' : 'Seasons'}',
            colorScheme: colorScheme,
          ),
        for (final genre in series.genres.take(3))
          _MetaChip(label: genre, colorScheme: colorScheme),
      ],
    );
  }

  Widget _buildMeta(BuildContext context, MediaItem series, SeriesProgress? prog) {
    final colorScheme = Theme.of(context).colorScheme;
    final overview = series.description ??
        series.metadata['plot']?.toString() ??
        series.metadata['description']?.toString() ??
        series.metadata['overview']?.toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetaChipsRow(context, series),

          if (prog != null) ...[
            AppSpacing.heightSM,
            Row(
              children: [
                Icon(
                  AppIcons.series,
                  size: 14.0,
                  color: colorScheme.primary,
                ),
                AppSpacing.widthXXS,
                Text(
                  '${_controller.seasonCount} ${_controller.seasonCount == 1 ? 'Season' : 'Seasons'} • ${_controller.totalEpisodes} Episodes',
                  style: AppTypography.getCaption(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],

          // Overall Series Progress Bar
          if (prog != null && prog.overallPercentage > 0) ...[
            AppSpacing.heightXS,
            ClipRRect(
              borderRadius: AppRadius.pill,
              child: Container(
                height: 4.0,
                color: colorScheme.surfaceContainerHighest,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: prog.overallPercentage,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          AppColors.darkPrimary,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Overview / Synopsis
          if (overview != null && overview.trim().isNotEmpty) ...[
            AppSpacing.heightMD,
            Text(
              'Overview',
              style: AppTypography.getTitle(
                color: colorScheme.onSurface,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
            AppSpacing.heightXS,
            Text(
              overview.trim(),
              style: AppTypography.getBody(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, SeriesProgress? prog) {
    return Obx(() {
      final isPlaying = _controller.isInlinePlayerActive.value;
      final isFav = _controller.isFavorite.value;
      final actionLabel = isPlaying
          ? 'Stop Video'
          : (prog?.actionLabel ?? 'Play Series');
      final summaryText = isPlaying ? null : prog?.summaryText;

      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: TvFocusable(
                autofocus: PlatformHelper.supportsDPadNavigation,
                onTap: isPlaying
                    ? _controller.stopInlinePlayback
                    : _controller.playPrimaryAction,
                borderRadius: AppRadius.pill,
                scale: 1.02,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isPlaying
                          ? [AppColors.darkError, AppColors.darkError.withValues(alpha: 0.8)]
                          : AppColors.primaryGradient,
                    ),
                    borderRadius: AppRadius.pill,
                    boxShadow: [
                      BoxShadow(
                        color: isPlaying
                            ? AppColors.darkError.withValues(alpha: 0.3)
                            : AppColors.darkPrimary.withValues(alpha: 0.3),
                        blurRadius: 12.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPlaying
                            ? Icons.stop_rounded
                            : (prog?.isCompleted == true ? Icons.replay : AppIcons.play),
                        color: Colors.white,
                        size: 20.0,
                      ),
                      AppSpacing.widthXS,
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              actionLabel,
                              style: AppTypography.getButton(color: Colors.white)
                                  .copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (summaryText != null)
                              Text(
                                summaryText,
                                style: AppTypography.getCaption(
                                  color: Colors.white70,
                                  scale: 0.85,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AppSpacing.widthSM,
            TvFocusable(
              onTap: _controller.toggleFavorite,
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
          ],
        ),
      );
    });
  }

  Widget _buildCastSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Text(
            'Cast',
            style: AppTypography.getTitle(color: colorScheme.onSurface)
                .copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 100.0,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: _controller.castMembers.length,
            separatorBuilder: (context, index) => AppSpacing.widthMD,
            itemBuilder: (context, index) {
              final member = _controller.castMembers[index];
              return _CastCard(member: member);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: SizedBox(
        height: 40.0,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _controller.seasons.length,
          separatorBuilder: (context, index) => AppSpacing.widthXS,
          itemBuilder: (context, index) {
            final season = _controller.seasons[index];
            final isSelected =
                index == _controller.selectedSeasonIndex.value;
            return TvFocusable(
              onTap: () => _controller.selectSeason(index),
              borderRadius: AppRadius.pill,
              scale: 1.05,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadius.pill,
                ),
                child: Text(
                  season.name,
                  style: AppTypography.getLabel(
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                  ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _resolveEpisodeCode(MediaItem ep) {
    final sNum = ep.metadata['seasonNumber'] ?? ep.metadata['seasonId'];
    final eNum = ep.metadata['episodeNumber'] ?? ep.metadata['streamId'];
    if (sNum != null && eNum != null) {
      final sStr = sNum.toString().padLeft(2, '0');
      final eStr = eNum.toString().padLeft(2, '0');
      return 'S${sStr}E$eStr';
    }
    return ep.subtitle ?? 'Episode';
  }
}

class _StickySeriesPlayerHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  _StickySeriesPlayerHeaderDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(covariant _StickySeriesPlayerHeaderDelegate oldDelegate) {
    return oldDelegate.minHeight != minHeight ||
        oldDelegate.maxHeight != maxHeight ||
        oldDelegate.child != child;
  }
}

class _CastCard extends StatelessWidget {
  final CastMember member;

  const _CastCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: colorScheme.surfaceContainerHighest,
            backgroundImage: (member.profileUrl != null && member.profileUrl!.isNotEmpty)
                ? NetworkImage(member.profileUrl!)
                : null,
            child: (member.profileUrl == null || member.profileUrl!.isEmpty)
                ? Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                    style: AppTypography.getLabel(color: colorScheme.primary),
                  )
                : null,
          ),
          AppSpacing.heightXXS,
          Text(
            member.name,
            style: AppTypography.getCaption(
              color: colorScheme.onSurface,
              scale: 0.8,
            ).copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (member.character != null && member.character!.isNotEmpty)
            Text(
              member.character!,
              style: AppTypography.getCaption(
                color: colorScheme.onSurfaceVariant,
                scale: 0.75,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;
  final bool emphasized;

  const _MetaChip({
    required this.label,
    required this.colorScheme,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: emphasized
            ? colorScheme.primary.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        label,
        style: AppTypography.getCaption(
          color: emphasized ? colorScheme.primary : colorScheme.onSurfaceVariant,
          scale: 0.9,
        ),
      ),
    );
  }
}
