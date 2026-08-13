import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/tv_focusable.dart';

class SeriesHeroSection extends StatelessWidget {
  final MediaItem series;
  final VoidCallback? onWatch;
  final VoidCallback? onFavorite;
  final bool isFavorite;

  const SeriesHeroSection({
    super.key,
    required this.series,
    this.onWatch,
    this.onFavorite,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backdrop = series.backdrop;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTv = constraints.maxWidth >= 900;
        final heroHeight = isTv
            ? (constraints.maxHeight * 0.55).clamp(320.0, 600.0)
            : (constraints.maxHeight * 0.38).clamp(240.0, 400.0);

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      series.title,
                      style: AppTypography.getHeadline(
                        color: Colors.white,
                        scale: isTv ? 1.4 : 1.0,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.heightXS,
                    _buildMetaRow(series, colorScheme),
                    if (series.description != null &&
                        series.description!.isNotEmpty) ...[
                      AppSpacing.heightSM,
                      Text(
                        series.description!,
                        style: AppTypography.getBody(
                          color: Colors.white70,
                          scale: isTv ? 1.0 : 0.9,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    AppSpacing.heightSM,
                    Row(
                      children: [
                        if (onWatch != null)
                          Expanded(
                            child: _HeroButton(
                              icon: AppIcons.play,
                              label: 'WATCH NOW',
                              onTap: onWatch,
                            ),
                          ),
                        if (onWatch != null && onFavorite != null)
                          AppSpacing.widthSM,
                        if (onFavorite != null)
                          Expanded(
                            child: _HeroButton(
                              icon: isFavorite ? Icons.favorite : AppIcons.add,
                              label: isFavorite ? 'MY LIST' : 'MY LIST',
                              onTap: onFavorite,
                              secondary: true,
                            ),
                          ),
                      ],
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

  Widget _buildMetaRow(MediaItem series, ColorScheme colorScheme) {
    final parts = <String>[];

    if (series.rating != null) {
      parts.add('⭐ ${series.rating!.toStringAsFixed(1)}');
    }

    final year = series.metadata['year']?.toString();
    if (year != null && year.isNotEmpty) {
      parts.add(year);
    }

    final seasonCount = series.metadata['seasonCount'];
    if (seasonCount != null) {
      final seasons = int.tryParse(seasonCount.toString()) ?? 0;
      if (seasons > 0) {
        parts.add('$seasons ${seasons == 1 ? 'Season' : 'Seasons'}');
      }
    }

    parts.addAll(series.genres.take(3));

    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join('  ·  '),
      style: AppTypography.getCaption(color: Colors.white70),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool secondary;

  const _HeroButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: onTap,
      borderRadius: AppRadius.pill,
      scale: 1.05,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          gradient: secondary ? null : const LinearGradient(colors: AppColors.primaryGradient),
          color: secondary ? Colors.white.withValues(alpha: 0.12) : null,
          borderRadius: AppRadius.pill,
          border: secondary
              ? Border.all(color: Colors.white.withValues(alpha: 0.25))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18.0),
            AppSpacing.widthXS,
            Expanded(
              child: Text(
                label,
                style: AppTypography.getButton(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
