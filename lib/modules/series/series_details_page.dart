import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_library.dart';
import '../../../shared/widgets/tv_focusable.dart';
import './widgets/episode_card.dart';
import 'series_details_controller.dart';

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
        TvFocusable(
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

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHero(context, series)),
        SliverToBoxAdapter(child: _buildMeta(context, series)),
        if (_controller.seasonCount > 1)
          SliverToBoxAdapter(child: _buildSeasonSelector(context)),
        SliverToBoxAdapter(child: _buildPlaySeasonButton(selectedSeason)),
        if (selectedSeason != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            sliver: SliverList.separated(
              itemCount: selectedSeason.episodes.length,
              separatorBuilder: (context, index) => AppSpacing.heightXS,
              itemBuilder: (context, index) {
                final episode = selectedSeason.episodes[index];
                final episodeNumber = episode.metadata['episodeNumber']?.toString();
                return EpisodeCard(
                  episode: episode,
                  episodeNumber: episodeNumber,
                  onTap: () => _controller.playEpisode(episode),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildHero(BuildContext context, MediaItem series) {
    final colorScheme = Theme.of(context).colorScheme;
    final poster = series.poster ?? series.thumbnail;
    final backdrop = series.backdrop;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTv = constraints.maxWidth >= 900;
        final heroHeight = isTv
            ? (constraints.maxHeight * 0.5).clamp(300.0, 550.0)
            : (constraints.maxHeight * 0.35).clamp(220.0, 350.0);

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

  Widget _buildMeta(BuildContext context, MediaItem series) {
    final colorScheme = Theme.of(context).colorScheme;

    final metaParts = <String>[];
    final year = series.metadata['year']?.toString();
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
          Text(
            '${_controller.seasonCount} '
            '${_controller.seasonCount == 1 ? 'Season' : 'Seasons'}'
            ' · ${_controller.totalEpisodes} '
            '${_controller.totalEpisodes == 1 ? 'Episode' : 'Episodes'}',
            style: AppTypography.getLabel(color: colorScheme.primary),
          ),
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

  Widget _buildSeasonSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
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
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaySeasonButton(SeasonGroup? selectedSeason) {
    final episodes = selectedSeason?.episodes ?? const <MediaItem>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: TvFocusable(
        onTap: episodes.isEmpty ? null : _controller.playSeason,
        borderRadius: AppRadius.pill,
        scale: 1.05,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.primaryGradient),
            borderRadius: AppRadius.pill,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(AppIcons.play, color: Colors.white, size: 20.0),
              AppSpacing.widthXS,
              Expanded(
                child: Text(
                  episodes.isEmpty
                      ? 'No Episodes Available'
                      : 'Play ${selectedSeason?.name ?? 'Season'}',
                  style: AppTypography.getButton(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
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
