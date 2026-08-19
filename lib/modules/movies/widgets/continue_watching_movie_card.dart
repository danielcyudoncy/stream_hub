import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/streaming/vod/xtream_vod_info_service.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/tv_focusable.dart';

class ContinueWatchingMovieCard extends StatefulWidget {
  final MediaItem item;
  final Duration position;
  final Duration duration;
  final VoidCallback onResume;
  final VoidCallback? onDetails;
  final double width;

  const ContinueWatchingMovieCard({
    super.key,
    required this.item,
    required this.position,
    required this.duration,
    required this.onResume,
    this.onDetails,
    this.width = 220,
  });

  @override
  State<ContinueWatchingMovieCard> createState() => _ContinueWatchingMovieCardState();
}

class _ContinueWatchingMovieCardState extends State<ContinueWatchingMovieCard> {
  String? _resolvedImage;

  @override
  void initState() {
    super.initState();
    _checkAndResolveImage();
  }

  @override
  void didUpdateWidget(covariant ContinueWatchingMovieCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.backdrop != widget.item.backdrop ||
        oldWidget.item.poster != widget.item.poster) {
      _resolvedImage = null;
      _checkAndResolveImage();
    }
  }

  void _checkAndResolveImage() {
    final direct = _computeDirectImage(widget.item);
    if (direct != null && direct.isNotEmpty) {
      _resolvedImage = direct;
      return;
    }

    if (widget.item.mediaType == MediaType.movie && Get.isRegistered<XtreamVodInfoService>()) {
      final vodService = Get.find<XtreamVodInfoService>();
      final cached = vodService.getCachedBackdrop(widget.item) ??
          vodService.getCachedPoster(widget.item);
      if (cached != null && cached.isNotEmpty) {
        _resolvedImage = cached;
        return;
      }

      vodService.fetchForMediaItem(widget.item).then((info) {
        if (!mounted) return;
        final backdrop = (info?.backdrop != null && info!.backdrop!.trim().isNotEmpty)
            ? info.backdrop!.trim()
            : null;
        final poster = (info?.poster != null && info!.poster!.trim().isNotEmpty)
            ? info.poster!.trim()
            : null;
        final img = backdrop ?? poster;
        if (img != null && img.isNotEmpty) {
          setState(() {
            _resolvedImage = ImageUrlFormatter.format(img, item: widget.item) ?? img;
          });
        }
      }).catchError((_) {});
    }
  }

  static String? _computeDirectImage(MediaItem item) {
    final formattedBackdrop = ImageUrlFormatter.format(item.backdrop, item: item);
    if (formattedBackdrop != null && formattedBackdrop.isNotEmpty) {
      return formattedBackdrop;
    }
    final formattedPoster = ImageUrlFormatter.extractFromMediaItem(item);
    if (formattedPoster != null && formattedPoster.isNotEmpty) {
      return formattedPoster;
    }
    final raw = (item.backdrop != null && item.backdrop!.trim().isNotEmpty)
        ? item.backdrop!.trim()
        : ((item.poster != null && item.poster!.trim().isNotEmpty)
            ? item.poster!.trim()
            : item.thumbnail?.trim());
    if (raw != null && raw.isNotEmpty) {
      final formatted = ImageUrlFormatter.format(raw, item: item);
      if (formatted != null && formatted.isNotEmpty) {
        return formatted;
      }
      return raw;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final image = _resolvedImage ?? _computeDirectImage(widget.item);
    final progress = widget.duration > Duration.zero
        ? (widget.position.inMilliseconds / widget.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final remaining = widget.duration > widget.position
        ? widget.duration - widget.position
        : Duration.zero;
    final remainingFormatted = _formatRemaining(remaining);

    return SizedBox(
      width: widget.width,
      child: TvFocusable(
        onTap: widget.onResume,
        borderRadius: AppRadius.medium,
        scale: 1.04,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: AppRadius.medium,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image != null && image.isNotEmpty)
                      Image.network(
                        image,
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

                    // Gradient overlay
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black87,
                          ],
                        ),
                      ),
                    ),

                    // Center play/resume icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24.0,
                        ),
                      ),
                    ),

                    // Remaining time overlay
                    if (remainingFormatted.isNotEmpty)
                      Positioned(
                        bottom: AppSpacing.xs,
                        left: AppSpacing.xs,
                        right: AppSpacing.xs,
                        child: Text(
                          '$remainingFormatted remaining',
                          style: AppTypography.getCaption(
                            color: Colors.white70,
                            scale: 0.8,
                          ).copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    // Progress bar
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                        minHeight: 3.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.heightXS,
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.getBody(
                      color: colorScheme.onSurface,
                      scale: 0.88,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (widget.onDetails != null) ...[
                  AppSpacing.widthXXS,
                  GestureDetector(
                    onTap: widget.onDetails,
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 16.0,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatRemaining(Duration remaining) {
    if (remaining <= Duration.zero) return '';
    final mins = remaining.inMinutes;
    if (mins < 60) return '$mins min';
    final hours = mins ~/ 60;
    final rem = mins % 60;
    return rem > 0 ? '${hours}h ${rem}m' : '${hours}h';
  }

  Widget _placeholder(ColorScheme colorScheme) {
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          AppIcons.movies,
          size: 32.0,
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
