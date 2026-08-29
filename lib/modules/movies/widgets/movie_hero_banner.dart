import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/streaming/vod/xtream_vod_info_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/tv_focusable.dart';

class MovieHeroBanner extends StatefulWidget {
  final MediaItem movie;
  final VoidCallback onWatch;
  final VoidCallback onDetails;
  final VoidCallback? onToggleFavorite;
  final bool isFavorite;
  final Duration? resumePosition;

  const MovieHeroBanner({
    super.key,
    required this.movie,
    required this.onWatch,
    required this.onDetails,
    this.onToggleFavorite,
    this.isFavorite = false,
    this.resumePosition,
  });

  @override
  State<MovieHeroBanner> createState() => _MovieHeroBannerState();
}

class _MovieHeroBannerState extends State<MovieHeroBanner> {
  String? _resolvedBackdrop;
  String? _resolvedPoster;

  @override
  void initState() {
    super.initState();
    _checkAndResolveArtwork();
  }

  @override
  void didUpdateWidget(covariant MovieHeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movie.id != widget.movie.id ||
        oldWidget.movie.backdrop != widget.movie.backdrop ||
        oldWidget.movie.poster != widget.movie.poster) {
      _resolvedBackdrop = null;
      _resolvedPoster = null;
      _checkAndResolveArtwork();
    }
  }

  void _checkAndResolveArtwork() {
    final directBg = _computeDirectBackdrop(widget.movie);
    final directPoster = _computeDirectPoster(widget.movie);
    if (directBg != null && directBg.isNotEmpty) {
      _resolvedBackdrop = directBg;
    }
    if (directPoster != null && directPoster.isNotEmpty) {
      _resolvedPoster = directPoster;
    }

    if (widget.movie.mediaType == MediaType.movie && Get.isRegistered<XtreamVodInfoService>()) {
      final vodService = Get.find<XtreamVodInfoService>();
      final cachedBg = vodService.getCachedBackdrop(widget.movie);
      final cachedPoster = vodService.getCachedPoster(widget.movie);

      if (_resolvedBackdrop == null && cachedBg != null && cachedBg.isNotEmpty) {
        _resolvedBackdrop = cachedBg;
      }
      if (_resolvedPoster == null && cachedPoster != null && cachedPoster.isNotEmpty) {
        _resolvedPoster = cachedPoster;
      }

      if (_resolvedBackdrop == null || _resolvedPoster == null) {
        vodService.fetchForMediaItem(widget.movie).then((info) {
          if (!mounted) return;
          final bg = (info?.backdrop != null && info!.backdrop!.trim().isNotEmpty)
              ? info.backdrop!.trim()
              : info?.poster?.trim();
          final p = (info?.poster != null && info!.poster!.trim().isNotEmpty)
              ? info.poster!.trim()
              : info?.backdrop?.trim();

          if (bg != null && bg.isNotEmpty && _resolvedBackdrop == null) {
            setState(() {
              _resolvedBackdrop = ImageUrlFormatter.format(bg, item: widget.movie) ?? bg;
            });
          }
          if (p != null && p.isNotEmpty && _resolvedPoster == null) {
            setState(() {
              _resolvedPoster = ImageUrlFormatter.format(p, item: widget.movie) ?? p;
            });
          }
        }).catchError((_) {});
      }
    }
  }

  static String? _computeDirectBackdrop(MediaItem movie) {
    final formattedBackdrop = ImageUrlFormatter.format(movie.backdrop, item: movie);
    if (formattedBackdrop != null && formattedBackdrop.isNotEmpty) {
      return formattedBackdrop;
    }
    return ImageUrlFormatter.extractFromMediaItem(movie);
  }

  static String? _computeDirectPoster(MediaItem movie) {
    final formattedPoster = ImageUrlFormatter.format(movie.poster, item: movie);
    if (formattedPoster != null && formattedPoster.isNotEmpty) {
      return formattedPoster;
    }
    return ImageUrlFormatter.extractFromMediaItem(movie);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTv = PlatformHelper.isTV;
    final backdrop = _resolvedBackdrop ?? _computeDirectBackdrop(widget.movie);
    final poster = _resolvedPoster ?? _computeDirectPoster(widget.movie);
    final rating = widget.movie.formattedRating;
    final year = widget.movie.releaseYear;
    final duration = widget.movie.formattedDuration;
    final hasResume = widget.resumePosition != null && widget.resumePosition! > Duration.zero;

    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = width >= 750;
        final bannerHeight = isTv
            ? 560.0
            : (width >= 1024
                ? (screenHeight * 0.65).clamp(500.0, 900.0)
                : (width >= 600 ? 380.0 : 330.0));

        return SizedBox(
          width: double.infinity,
          height: bannerHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
                // Background image
                if (backdrop != null && backdrop.isNotEmpty)
                  Image.network(
                    backdrop,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _placeholder(colorScheme),
                  )
                else
                  _placeholder(colorScheme),

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
                            // Metadata chips row
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xxs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (rating != null && rating.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6.0,
                                      vertical: 2.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: AppRadius.small,
                                      border: Border.all(
                                        color: Colors.amber.withValues(alpha: 0.5),
                                        width: 1.0,
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
                                        const SizedBox(width: 3.0),
                                        Text(
                                          rating,
                                          style: AppTypography.getCaption(
                                            color: Colors.amber,
                                            scale: 0.85,
                                          ).copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (year != null)
                                  _infoChip('$year', colorScheme),
                                if (duration != null)
                                  _infoChip(duration, colorScheme),
                                for (final genre in widget.movie.genres.take(2))
                                  _infoChip(genre, colorScheme),
                              ],
                            ),
                            AppSpacing.heightXS,

                            // Title
                            Text(
                              widget.movie.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.getHeadline(
                                color: Colors.white,
                                scale: isTv ? 1.2 : isWide ? 1.05 : 0.9,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),

                            // Description
                            if (widget.movie.description != null &&
                                widget.movie.description!.isNotEmpty &&
                                isWide) ...[
                              AppSpacing.heightXXS,
                              Text(
                                widget.movie.description!,
                                maxLines: isTv ? 3 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.getBody(
                                  color: Colors.white70,
                                  scale: 0.85,
                                ),
                              ),
                            ],
                            AppSpacing.heightMD,

                            // Action buttons row
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xs,
                              children: [
                                // Watch / Resume Button
                                TvFocusable(
                                  onTap: widget.onWatch,
                                  borderRadius: AppRadius.pill,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg,
                                      vertical: AppSpacing.sm,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: AppColors.primaryGradient,
                                      ),
                                      borderRadius: AppRadius.pill,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          AppIcons.play,
                                          color: Colors.white,
                                          size: 18.0,
                                        ),
                                        AppSpacing.widthXXS,
                                        Text(
                                          hasResume ? 'Resume' : 'Watch Now',
                                          style: AppTypography.getButton(
                                            color: Colors.white,
                                            scale: 0.9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Details Button
                                TvFocusable(
                                  onTap: widget.onDetails,
                                  borderRadius: AppRadius.pill,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg,
                                      vertical: AppSpacing.sm,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: AppRadius.pill,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.info_outline_rounded,
                                          color: Colors.white,
                                          size: 18.0,
                                        ),
                                        AppSpacing.widthXXS,
                                        Text(
                                          'Details',
                                          style: AppTypography.getButton(
                                            color: Colors.white,
                                            scale: 0.9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // My List Button
                                if (widget.onToggleFavorite != null)
                                  TvFocusable(
                                    onTap: widget.onToggleFavorite,
                                    borderRadius: AppRadius.pill,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.lg,
                                        vertical: AppSpacing.sm,
                                      ),
                                      decoration: BoxDecoration(
                                        color: widget.isFavorite
                                            ? AppColors.darkError.withValues(alpha: 0.25)
                                            : Colors.white.withValues(alpha: 0.15),
                                        borderRadius: AppRadius.pill,
                                        border: Border.all(
                                          color: widget.isFavorite
                                              ? AppColors.darkError.withValues(alpha: 0.6)
                                              : Colors.transparent,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            widget.isFavorite
                                                ? Icons.check_rounded
                                                : Icons.add_rounded,
                                            color: Colors.white,
                                            size: 18.0,
                                          ),
                                          AppSpacing.widthXXS,
                                          Text(
                                            'My List',
                                            style: AppTypography.getButton(
                                              color: Colors.white,
                                              scale: 0.9,
                                            ),
                                          ),
                                        ],
                                      ),
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
              ],
            ),
          );
        },
      );
    }

  Widget _infoChip(String label, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: AppRadius.small,
      ),
      child: Text(
        label,
        style: AppTypography.getCaption(
          color: Colors.white70,
          scale: 0.8,
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
          size: 48.0,
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
