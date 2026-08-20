import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

class SeriesDetailsPage extends StatefulWidget {
  const SeriesDetailsPage({super.key});

  @override
  State<SeriesDetailsPage> createState() => _SeriesDetailsPageState();
}

class _SeriesDetailsPageState extends State<SeriesDetailsPage> {
  late final SeriesDetailsController _controller =
      Get.find<SeriesDetailsController>();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
  }

  Widget _buildContent(BuildContext context) {
    final series = _controller.series;
    final selectedSeason = _controller.selectedSeason;
    final prog = _controller.seriesProgress.value;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHero(context, series)),
        SliverToBoxAdapter(child: _buildMeta(context, series, prog)),
        SliverToBoxAdapter(child: _buildPrimaryActionButton(prog)),
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

                return EpisodeCard(
                  key: ValueKey('ep-${episode.id}'),
                  episode: episode,
                  episodeNumber: episodeNumber,
                  progressPercentage: epProgress,
                  isCompleted: isCompleted,
                  isNextUp: isNextUp,
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

  Widget _buildMeta(BuildContext context, MediaItem series, SeriesProgress? prog) {
    final colorScheme = Theme.of(context).colorScheme;

    final metaParts = <String>[];
    final year = series.releaseYear?.toString() ?? series.metadata['year']?.toString();
    if (year != null && year.isNotEmpty) metaParts.add(year);
    metaParts.addAll(series.genres);


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
          if (metaParts.isNotEmpty || series.rating != null)
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final part in metaParts.take(5))
                  _MetaChip(label: part, colorScheme: colorScheme),
                if (series.rating != null)
                  _MetaChip(
                    label: '★ ${series.rating!.toStringAsFixed(1)}',
                    colorScheme: colorScheme,
                    emphasized: true,
                  ),
              ],
            ),
          AppSpacing.heightSM,
          Row(
            children: [
              Text(
                '${_controller.seasonCount} '
                '${_controller.seasonCount == 1 ? 'Season' : 'Seasons'}'
                ' · ${_controller.totalEpisodes} '
                '${_controller.totalEpisodes == 1 ? 'Episode' : 'Episodes'}',
                style: AppTypography.getLabel(color: colorScheme.primary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              if (prog != null && prog.completedEpisodes > 0) ...[
                const SizedBox(width: 8.0),
                Text(
                  '• ${prog.completedEpisodes}/${prog.totalAvailableEpisodes} Watched',
                  style: AppTypography.getCaption(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),

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

          if (series.description != null &&
              series.description!.isNotEmpty) ...[
            AppSpacing.heightSM,
            Text(
              series.description!,
              style: AppTypography.getBody(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton(SeriesProgress? prog) {
    final actionLabel = prog?.actionLabel ?? 'Play Series';
    final summaryText = prog?.summaryText;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: TvFocusable(
        onTap: _controller.playPrimaryAction,
        borderRadius: AppRadius.pill,
        scale: 1.03,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.primaryGradient),
            borderRadius: AppRadius.pill,
            boxShadow: [
              BoxShadow(
                color: AppColors.darkPrimary.withValues(alpha: 0.3),
                blurRadius: 12.0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                prog?.isCompleted == true ? Icons.replay : AppIcons.play,
                color: Colors.white,
                size: 22.0,
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
    );
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
