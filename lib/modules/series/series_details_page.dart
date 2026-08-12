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
    return Obx(() {
      return AppScaffold(
        title: _controller.seriesTitle,
        showNavigation: false,
        actions: [
          IconButton(
            icon: Icon(
              _controller.isFavorite.value
                  ? Icons.favorite
                  : AppIcons.favorites,
              color: _controller.isFavorite.value
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
            tooltip: _controller.isFavorite.value
                ? 'Remove from Favorites'
                : 'Add to Favorites',
            onPressed: _controller.toggleFavorite,
          ),
        ],
        body: _buildBody(context),
      );
    });
  }

  Widget _buildBody(BuildContext context) {
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

    final selectedSeason = _controller.selectedSeason;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context)),
        SliverToBoxAdapter(child: _buildMeta(context)),
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
                return _EpisodeTile(
                  episode: episode,
                  onTap: () => _controller.playEpisode(episode),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final series = _controller.series;
    final poster = series.poster ?? series.thumbnail;
    final backdrop = series.backdrop;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 240.0,
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
              const DecoratedBox(
                decoration: BoxDecoration(
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
                bottom: AppSpacing.md,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ClipRRect(
                      borderRadius: AppRadius.medium,
                      child: SizedBox(
                        width: 112.0,
                        height: 162.0,
                        child: poster != null && poster.isNotEmpty
                            ? Image.network(
                                poster,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _posterPlaceholder(colorScheme),
                              )
                            : _posterPlaceholder(colorScheme),
                      ),
                    ),
                    AppSpacing.widthMD,
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
                                scale: 0.9,
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
        ),
      ],
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

  Widget _buildMeta(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final series = _controller.series;

    final metaParts = <String>[
      if (_year.isNotEmpty) _year,
      ...series.genres,
    ];

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
          Row(
            children: [
              if (metaParts.isNotEmpty)
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final part in metaParts)
                        _MetaChip(label: part, colorScheme: colorScheme),
                      if (series.rating != null)
                        _MetaChip(
                          label: '★ ${series.rating!.toStringAsFixed(1)}',
                          colorScheme: colorScheme,
                          emphasized: true,
                        ),
                    ],
                  ),
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

  String get _year {
    final raw = _controller.series.metadata['year']?.toString() ?? '';
    return raw.trim();
  }

  Widget _buildSeasonSelector(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            return ChoiceChip(
              label: Text(season.name),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => _controller.selectSeason(index),
              labelStyle: AppTypography.getLabel(
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
              backgroundColor: colorScheme.surfaceContainerHighest,
              selectedColor: colorScheme.primary,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.pill,
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
      child: InkWell(
        onTap: episodes.isEmpty ? null : _controller.playSeason,
        borderRadius: AppRadius.pill,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: AppColors.primaryGradient),
            borderRadius: AppRadius.pill,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(AppIcons.play, color: Colors.white, size: 20.0),
              AppSpacing.widthXS,
              Text(
                episodes.isEmpty
                    ? 'No Episodes Available'
                    : 'Play ${selectedSeason?.name ?? 'Season'}',
                style: AppTypography.getButton(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final MediaItem episode;
  final VoidCallback onTap;

  const _EpisodeTile({
    required this.episode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: AppRadius.medium,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.medium,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 36.0,
                height: 36.0,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$_episodeNumber',
                  style: AppTypography.getLabel(color: colorScheme.primary),
                ),
              ),
              AppSpacing.widthMD,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.title,
                      style: AppTypography.getLabel(color: colorScheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (episode.subtitle != null) ...[
                      AppSpacing.heightXXS,
                      Text(
                        episode.subtitle!,
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                AppIcons.play,
                size: 20.0,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  int get _episodeNumber {
    final raw = episode.metadata['episodeNumber']?.toString() ?? '';
    return int.tryParse(raw) ?? 0;
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
