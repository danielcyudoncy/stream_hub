import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/tv_focusable.dart';

class SeriesHeroSection extends StatelessWidget {
  final MediaItem series;
  final VoidCallback? onWatch;
  final VoidCallback? onDetails;
  final VoidCallback? onFavorite;
  final bool isFavorite;

  const SeriesHeroSection({
    super.key,
    required this.series,
    this.onWatch,
    this.onDetails,
    this.onFavorite,
    this.isFavorite = false,
  });

  static String? _resolveBackdrop(MediaItem series) {
    final formattedBackdrop =
        ImageUrlFormatter.format(series.backdrop, item: series);
    if (formattedBackdrop != null && formattedBackdrop.isNotEmpty) {
      return formattedBackdrop;
    }
    final formattedPoster =
        ImageUrlFormatter.format(series.poster, item: series);
    if (formattedPoster != null && formattedPoster.isNotEmpty) {
      return formattedPoster;
    }
    return ImageUrlFormatter.extractFromMediaItem(series);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backdrop = _resolveBackdrop(series);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTv = constraints.maxWidth >= 900;
        final heroHeight = isTv
            ? (constraints.maxHeight * 0.55).clamp(320.0, 600.0)
            : (constraints.maxHeight * 0.38).clamp(260.0, 420.0);

        return GestureDetector(
          onTap: onDetails,
          child: SizedBox(
            width: double.infinity,
            height: heroHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (backdrop != null)
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
                          if (onWatch != null && (onDetails != null || onFavorite != null))
                            AppSpacing.widthSM,
                          if (onDetails != null)
                            Expanded(
                              child: _HeroButton(
                                icon: Icons.info_outline,
                                label: 'DETAILS',
                                onTap: onDetails,
                                secondary: true,
                              ),
                            ),
                          if (onDetails != null && onFavorite != null)
                            AppSpacing.widthSM,
                          if (onFavorite != null && onDetails == null)
                            Expanded(
                              child: _HeroButton(
                                icon: isFavorite ? Icons.favorite : AppIcons.add,
                                label: isFavorite ? 'FAVORITE' : 'ADD LIST',
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

    final year = series.metadata['year']?.toString() ?? series.releaseYear?.toString();
    if (year != null && year.isNotEmpty) {
      parts.add(year);
    }

    final seasonCount = series.metadata['seasonCount'] ?? series.metadata['seasonsCount'];
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
          color: secondary ? Colors.white.withValues(alpha: 0.15) : null,
          borderRadius: AppRadius.pill,
          border: secondary
              ? Border.all(color: Colors.white.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18.0),
            AppSpacing.widthXS,
            Flexible(
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
