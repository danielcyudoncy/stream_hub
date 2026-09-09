import 'package:flutter/material.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../core/utils/title_formatter.dart';
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
                  bottom: isTv ? 36.0 : 28.0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isWide && poster != null && poster.isNotEmpty) ...[
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.medium,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1.2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: AppRadius.medium,
                            child: SizedBox(
                              width: isTv ? 160.0 : 130.0,
                              height: isTv ? 240.0 : 195.0,
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
                            // Title (Sanitized and Prominent)
                            Text(
                              TitleFormatter.cleanMediaTitle(series.title),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.getHeadline(
                                color: Colors.white,
                                scale: isTv ? 1.35 : (isWide ? 1.15 : 0.95),
                              ).copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.85),
                                    blurRadius: 10.0,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6.0),

                            // Metadata chips row
                            _buildMetaRow(series, colorScheme),

                            // Description (wide only)
                            if (series.description != null &&
                                series.description!.isNotEmpty &&
                                isWide) ...[
                              const SizedBox(height: 6.0),
                              Text(
                                series.description!,
                                maxLines: isTv ? 3 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.getBody(
                                  color: Colors.white70,
                                  scale: 0.85,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12.0),

                            // Action buttons row (guaranteed single horizontal row)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (onWatch != null)
                                  TvFocusable(
                                    onTap: onWatch,
                                    borderRadius: AppRadius.pill,
                                    scale: 1.04,
                                    child: Container(
                                      height: 34.0,
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: AppColors.primaryGradient,
                                        ),
                                        borderRadius: AppRadius.pill,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.darkPrimary.withValues(alpha: 0.35),
                                            blurRadius: 8.0,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            AppIcons.play,
                                            color: Colors.white,
                                            size: 14.0,
                                          ),
                                          const SizedBox(width: 4.0),
                                          Text(
                                            'Watch Now',
                                            style: AppTypography.getButton(
                                              color: Colors.white,
                                              scale: 0.82,
                                            ).copyWith(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (onDetails != null) ...[
                                  const SizedBox(width: 8.0),
                                  TvFocusable(
                                    onTap: onDetails,
                                    borderRadius: AppRadius.pill,
                                    scale: 1.04,
                                    child: Container(
                                      height: 34.0,
                                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.16),
                                        borderRadius: AppRadius.pill,
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.24),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.info_outline_rounded,
                                            color: Colors.white,
                                            size: 14.0,
                                          ),
                                          const SizedBox(width: 4.0),
                                          Text(
                                            'Details',
                                            style: AppTypography.getButton(
                                              color: Colors.white,
                                              scale: 0.82,
                                            ).copyWith(fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                if (onFavorite != null) ...[
                                  const SizedBox(width: 8.0),
                                  TvFocusable(
                                    onTap: onFavorite,
                                    borderRadius: AppRadius.pill,
                                    scale: 1.04,
                                    child: Container(
                                      height: 34.0,
                                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                      decoration: BoxDecoration(
                                        color: isFavorite
                                            ? AppColors.darkError.withValues(alpha: 0.25)
                                            : Colors.white.withValues(alpha: 0.16),
                                        borderRadius: AppRadius.pill,
                                        border: Border.all(
                                          color: isFavorite
                                              ? AppColors.darkError.withValues(alpha: 0.6)
                                              : Colors.white.withValues(alpha: 0.24),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isFavorite
                                                ? Icons.check_rounded
                                                : Icons.add_rounded,
                                            color: isFavorite ? AppColors.darkError : Colors.white,
                                            size: 14.0,
                                          ),
                                          const SizedBox(width: 4.0),
                                          Text(
                                            isFavorite ? 'In List' : 'My List',
                                            style: AppTypography.getButton(
                                              color: isFavorite ? AppColors.darkError : Colors.white,
                                              scale: 0.82,
                                            ).copyWith(fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
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
    final rating = series.rating;
    final year = series.metadata['year']?.toString() ?? series.releaseYear?.toString();
    final seasonCount = series.metadata['seasonCount'] ?? series.metadata['seasonsCount'];
    int seasons = 0;
    if (seasonCount != null) {
      seasons = int.tryParse(seasonCount.toString()) ?? 0;
    }

    return Wrap(
      spacing: 6.0,
      runSpacing: 4.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (rating != null && rating > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.25),
              borderRadius: AppRadius.small,
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.6),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                  size: 13.0,
                ),
                const SizedBox(width: 2.5),
                Text(
                  rating.toStringAsFixed(1),
                  style: AppTypography.getCaption(
                    color: Colors.amber,
                    scale: 0.82,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        if (year != null && year.isNotEmpty)
          _infoChip(year, colorScheme),
        if (seasons > 0)
          _infoChip('$seasons ${seasons == 1 ? 'Season' : 'Seasons'}', colorScheme),
        if (series.genres.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 2.0),
            child: Text(
              series.genres.take(2).join('  ·  '),
              style: AppTypography.getCaption(
                color: Colors.white70,
                scale: 0.82,
              ),
            ),
          ),
      ],
    );
  }

  static Widget _infoChip(String text, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: AppRadius.small,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: AppTypography.getCaption(
          color: Colors.white.withValues(alpha: 0.85),
          scale: 0.82,
        ).copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}
