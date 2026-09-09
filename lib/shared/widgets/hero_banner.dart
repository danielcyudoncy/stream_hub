import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/title_formatter.dart';
import 'cached_home_image.dart';
import 'channel_placeholder.dart';
import 'tv_focusable.dart';

class HeroBanner extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String imageUrl;
  final double? rating;
  final String? year;
  final String? genre;
  final String? quality;
  final String? mediaType;
  final bool isFavorite;
  final VoidCallback? onPlayPressed;
  final VoidCallback? onDetailsPressed;
  final VoidCallback? onFavoritePressed;

  const HeroBanner({
    super.key,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.rating,
    this.year,
    this.genre,
    this.quality,
    this.mediaType,
    this.isFavorite = false,
    this.onPlayPressed,
    this.onDetailsPressed,
    this.onFavoritePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TvFocusable(
      onTap: onPlayPressed ?? onDetailsPressed,
      scale: 1.01,
      borderRadius: AppRadius.large,
      child: ClipRRect(
        borderRadius: AppRadius.large,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: AppRadius.large,
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background Image / Fallback
              if (imageUrl.isNotEmpty)
                CachedHomeImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, url) => _buildFallback(colorScheme),
                )
              else
                _buildFallback(colorScheme),

              // 2. Cinematic Dual-Layer Gradient
              // Layer A: Bottom fade into surface background
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.65),
                        colorScheme.surface.withValues(alpha: 0.98),
                      ],
                      stops: const [0.0, 0.4, 0.7, 1.0],
                    ),
                  ),
                ),
              ),

              // Layer B: Subtle horizontal vignette on the left for text contrast
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.black.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // 3. Hero Content Overlay
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: 24.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A. Hero Title
                    Text(
                      TitleFormatter.cleanMediaTitle(title),
                      style: AppTypography.getHeadline(
                        color: Colors.white,
                        scale: 0.95,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6.0),

                    // B. Metadata Chips Row (Type, Rating, Year, Quality)
                    _buildMetadataRow(colorScheme),

                    // C. Subtitle / Plot Description
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6.0),
                      Text(
                        subtitle!.trim(),
                        style: AppTypography.getBody(
                          color: Colors.white.withValues(alpha: 0.85),
                          scale: 0.85,
                        ).copyWith(
                          height: 1.3,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              blurRadius: 8.0,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 12.0),

                    // D. Action Buttons (Single Horizontal Row)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Play / Watch Now Button
                        if (onPlayPressed != null)
                          TvFocusable(
                            onTap: onPlayPressed,
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
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 16.0,
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

                        // 2. Details Button
                        if (onDetailsPressed != null) ...[
                          const SizedBox(width: 8.0),
                          TvFocusable(
                            onTap: onDetailsPressed,
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
                                    size: 14.0,
                                    color: Colors.white,
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

                        // 3. Favorite / Bookmark Button
                        if (onFavoritePressed != null) ...[
                          const SizedBox(width: 8.0),
                          TvFocusable(
                            onTap: onFavoritePressed,
                            borderRadius: AppRadius.pill,
                            scale: 1.04,
                            child: Container(
                              width: 34.0,
                              height: 34.0,
                              decoration: BoxDecoration(
                                color: isFavorite
                                    ? AppColors.darkError.withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isFavorite
                                      ? AppColors.darkError.withValues(alpha: 0.6)
                                      : Colors.white.withValues(alpha: 0.24),
                                  width: 0.8,
                                ),
                              ),
                              child: Icon(
                                isFavorite
                                    ? Icons.bookmark_added_rounded
                                    : Icons.bookmark_add_outlined,
                                size: 16.0,
                                color: isFavorite
                                    ? AppColors.darkError
                                    : Colors.white,
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
      ),
    );
  }

  Widget _buildMetadataRow(ColorScheme colorScheme) {
    final chips = <Widget>[];

    // Media Type Badge (Show MOVIE/SERIES, exclude LIVE TV)
    if (mediaType != null &&
        mediaType!.isNotEmpty &&
        !mediaType!.toLowerCase().contains('live')) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.85),
            borderRadius: AppRadius.small,
          ),
          child: Text(
            mediaType!.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.0,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
        ),
      );
    }

    // Rating Chip
    if (rating != null && rating! > 0) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: AppRadius.small,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star_rounded,
                size: 13.0,
                color: Color(0xFFFBBF24),
              ),
              const SizedBox(width: 3.0),
              Text(
                rating!.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Year Chip
    if (year != null && year!.isNotEmpty) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: AppRadius.small,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Text(
            year!,
            style: TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      );
    }

    // Quality Badge (e.g. 4K, FHD)
    if (quality != null && quality!.isNotEmpty) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: AppRadius.small,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Text(
            quality!,
            style: const TextStyle(
              fontSize: 10.0,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // Genre Tag
    if (genre != null && genre!.isNotEmpty) {
      chips.add(
        Text(
          genre!,
          style: TextStyle(
            fontSize: 11.0,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }

  Widget _buildFallback(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: const Center(
        child: ChannelPlaceholder(
          iconSize: 44.0,
          fontSize: 13.0,
        ),
      ),
    );
  }
}
