import 'package:flutter/material.dart';
import '../../../core/helpers/platform_helper.dart';
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

  static String? _resolvePoster(MediaItem series) {
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
    final isTv = PlatformHelper.isTV;
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final backdrop = _resolveBackdrop(series);
    final poster = _resolvePoster(series);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = width >= 750;
        final heroHeight = isTv
            ? 560.0
            : (width >= 1024
                ? (screenHeight * 0.65).clamp(500.0, 900.0)
                : (width >= 600 ? 380.0 : 330.0));

        return GestureDetector(
          onTap: onDetails,
          child: SizedBox(
            width: double.infinity,
            height: heroHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Backdrop image
                if (backdrop != null)
                  Image.network(
                    backdrop,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        ColoredBox(color: colorScheme.surfaceContainerHighest),
                  )
                else
                  ColoredBox(color: colorScheme.surfaceContainerHighest),

                // Radial / linear gradient overlay for cinematic readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.5),
                        Colors.black.withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),

                // Side gradient for wide screens
                if (isWide)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.92),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.65],
                      ),
                    ),
                  ),

                // Content layer
                Positioned(
                  left: isTv ? 48.0 : AppSpacing.lg,
                  right: isTv ? 48.0 : AppSpacing.lg,
                  bottom: isTv ? 36.0 : AppSpacing.lg,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (poster != null && poster.isNotEmpty) ...[
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.large,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: AppRadius.large,
                            child: SizedBox(
                              width: isTv ? 190.0 : isWide ? 150.0 : 100.0,
                              height: isTv ? 280.0 : isWide ? 220.0 : 150.0,
                              child: Image.network(
                                poster,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                        AppSpacing.widthLG,
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              series.title,
                              style: AppTypography.getHeadline(
                                color: Colors.white,
                                scale: isTv ? 1.25 : (isWide ? 1.1 : 0.95),
                              ).copyWith(fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            AppSpacing.heightXS,
                            _buildMetaRow(series, colorScheme),
                            if (series.description != null &&
                                series.description!.isNotEmpty &&
                                isWide) ...[
                              AppSpacing.heightSM,
                              Text(
                                series.description!,
                                style: AppTypography.getBody(
                                  color: Colors.white70,
                                  scale: isTv ? 0.95 : 0.85,
                                ),
                                maxLines: isTv ? 3 : 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            AppSpacing.heightMD,
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xs,
                              children: [
                                if (onWatch != null)
                                  _HeroButton(
                                    icon: AppIcons.play,
                                    label: 'WATCH NOW',
                                    onTap: onWatch,
                                  ),
                                if (onDetails != null)
                                  _HeroButton(
                                    icon: Icons.info_outline,
                                    label: 'DETAILS',
                                    onTap: onDetails,
                                    secondary: true,
                                  ),
                                if (onFavorite != null)
                                  _HeroButton(
                                    icon: isFavorite
                                        ? Icons.favorite
                                        : AppIcons.add,
                                    label: isFavorite ? 'FAVORITE' : 'MY LIST',
                                    onTap: onFavorite,
                                    secondary: true,
                                  ),
                              ],
                            ),
                          ],
                        ),
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
