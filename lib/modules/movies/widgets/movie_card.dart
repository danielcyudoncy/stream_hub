import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/streaming/vod/xtream_vod_info_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/tv_focusable.dart';

class MovieCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  final double? progressPercentage;
  final bool isCompleted;
  final VoidCallback? onToggleFavorite;

  const MovieCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width,
    this.height,
    this.progressPercentage,
    this.isCompleted = false,
    this.onToggleFavorite,
  });

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  String? _resolvedPoster;

  @override
  void initState() {
    super.initState();
    _checkAndResolvePoster();
  }

  @override
  void didUpdateWidget(covariant MovieCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.poster != widget.item.poster ||
        oldWidget.item.thumbnail != widget.item.thumbnail) {
      _resolvedPoster = null;
      _checkAndResolvePoster();
    }
  }

  void _checkAndResolvePoster() {
    final direct = _computeDirectPoster(widget.item);
    if (direct != null && direct.isNotEmpty) {
      _resolvedPoster = direct;
      return;
    }

    if (widget.item.mediaType == MediaType.movie && Get.isRegistered<XtreamVodInfoService>()) {
      final vodService = Get.find<XtreamVodInfoService>();
      final cached = vodService.getCachedPoster(widget.item);
      if (cached != null && cached.isNotEmpty) {
        _resolvedPoster = cached;
        return;
      }

      vodService.fetchForMediaItem(widget.item).then((info) {
        if (!mounted) return;
        final poster = info?.poster ?? info?.backdrop;
        if (poster != null && poster.isNotEmpty) {
          setState(() {
            _resolvedPoster = ImageUrlFormatter.format(poster, item: widget.item) ?? poster;
          });
        }
      }).catchError((_) {});
    }
  }

  static String? _computeDirectPoster(MediaItem item) {
    final formattedPoster = ImageUrlFormatter.extractFromMediaItem(item);
    if (formattedPoster != null && formattedPoster.isNotEmpty) {
      return formattedPoster;
    }
    final rawPoster = (item.poster != null && item.poster!.trim().isNotEmpty)
        ? item.poster!.trim()
        : ((item.thumbnail != null && item.thumbnail!.trim().isNotEmpty)
            ? item.thumbnail!.trim()
            : item.backdrop?.trim());
    if (rawPoster != null && rawPoster.isNotEmpty) {
      final formatted = ImageUrlFormatter.format(rawPoster, item: item);
      if (formatted != null && formatted.isNotEmpty) {
        return formatted;
      }
      return rawPoster;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final poster = _resolvedPoster ?? _computeDirectPoster(widget.item);
    final rating = widget.item.formattedRating;
    final year = widget.item.releaseYear;
    final genre = widget.item.genres.isNotEmpty ? widget.item.genres.first : null;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: TvFocusable(
        onTap: widget.onTap,
        borderRadius: AppRadius.medium,
        scale: 1.1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: AppRadius.medium,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (poster != null && poster.isNotEmpty)
                      Image.network(
                        poster,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _placeholder(colorScheme),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return ColoredBox(
                            color: colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: SizedBox(
                                width: 20.0,
                                height: 20.0,
                                child: CircularProgressIndicator(strokeWidth: 2.0),
                              ),
                            ),
                          );
                        },
                      )
                    else
                      _placeholder(colorScheme),

                    if (rating != null && rating.isNotEmpty)
                      Positioned(
                        top: AppSpacing.xs,
                        left: AppSpacing.xs,
                        child: GlassPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.0,
                            vertical: 2.0,
                          ),
                          borderRadius: AppRadius.small,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.amber,
                                size: 12.0,
                              ),
                              const SizedBox(width: 2.0),
                              Text(
                                rating,
                                style: AppTypography.getCaption(
                                  color: Colors.white,
                                  scale: 0.85,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (widget.isCompleted)
                      Positioned(
                        top: AppSpacing.xs,
                        right: AppSpacing.xs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.darkSuccess.withValues(alpha: 0.85),
                            borderRadius: AppRadius.small,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 12.0,
                          ),
                        ),
                      )
                    else if (widget.onToggleFavorite != null || widget.item.favorite)
                      Positioned(
                        top: AppSpacing.xs,
                        right: AppSpacing.xs,
                        child: GestureDetector(
                          onTap: widget.onToggleFavorite,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.item.favorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: widget.item.favorite
                                  ? AppColors.darkError
                                  : Colors.white,
                              size: 14.0,
                            ),
                          ),
                        ),
                      ),

                    if (widget.progressPercentage != null &&
                        widget.progressPercentage! > 0.0 &&
                        widget.progressPercentage! < 0.95)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: widget.progressPercentage!.clamp(0.0, 1.0),
                          backgroundColor: Colors.black54,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                          minHeight: 4.0,
                        ),
                      ),

                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Color(0xCC000000),
                                Color(0x66000000),
                                Color(0x00000000),
                                Color(0x00000000),
                              ],
                              stops: [0.0, 0.35, 0.55, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      left: AppSpacing.xs,
                      right: AppSpacing.xs,
                      bottom: AppSpacing.xs,
                      child: IgnorePointer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.getBody(
                                color: Colors.white,
                                scale: 0.85,
                              ).copyWith(fontWeight: FontWeight.w600, height: 1.2),
                            ),
                            if (year != null || genre != null || rating != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  _buildMetadataText(year, genre, rating),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.getCaption(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    scale: 0.75,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildMetadataText(int? year, String? genre, String? rating) {
    final parts = <String>[];
    if (year != null) parts.add(year.toString());
    if (genre != null) parts.add(genre);
    if (rating != null) parts.add('$rating★');
    return parts.join(' • ');
  }

  Widget _placeholder(ColorScheme colorScheme) {
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          AppIcons.movies,
          size: 32.0,
          color: colorScheme.primary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
