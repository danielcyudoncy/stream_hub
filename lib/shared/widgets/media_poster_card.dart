import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/media/enums/media_type.dart';
import '../../core/streaming/vod/xtream_vod_info_service.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_url_formatter.dart';
import '../../data/models/media_item.dart';
import 'tv_focusable.dart';

class MediaPosterCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback? onTap;

  const MediaPosterCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  State<MediaPosterCard> createState() => _MediaPosterCardState();
}

class _MediaPosterCardState extends State<MediaPosterCard> {
  String? _resolvedPoster;

  @override
  void initState() {
    super.initState();
    _checkAndResolvePoster();
  }

  @override
  void didUpdateWidget(covariant MediaPosterCard oldWidget) {
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
            _resolvedPoster = poster;
          });
        }
      }).catchError((_) {});
    }
  }

  static String? _computeDirectPoster(MediaItem item) {
    final formattedPoster = ImageUrlFormatter.extractFromMediaItem(item);
    final rawPoster = (item.poster != null && item.poster!.trim().isNotEmpty)
        ? item.poster!.trim()
        : ((item.thumbnail != null && item.thumbnail!.trim().isNotEmpty)
            ? item.thumbnail!.trim()
            : item.backdrop?.trim());
    return (formattedPoster != null && formattedPoster.isNotEmpty)
        ? formattedPoster
        : rawPoster;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final poster = _resolvedPoster ?? _computeDirectPoster(widget.item);
    final isChannel = widget.item.mediaType == MediaType.channel;

    return TvFocusable(
      onTap: widget.onTap,
      borderRadius: AppRadius.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.medium,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                ),
                child: poster != null && poster.isNotEmpty
                    ? _buildImage(context, poster, isChannel, colorScheme)
                    : _buildPlaceholder(context, colorScheme),
              ),
            ),
          ),
          AppSpacing.heightXS,
          Text(
            widget.item.title,
            style: AppTypography.getCaption(
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.item.rating != null && widget.item.rating! > 0) ...[
            AppSpacing.heightXXS,
            Text(
              '⭐ ${widget.item.rating!.toStringAsFixed(1)}',
              style: AppTypography.getCaption(
                color: colorScheme.onSurfaceVariant,
                scale: 0.8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ] else if (widget.item.subtitle != null && widget.item.subtitle!.isNotEmpty) ...[
            AppSpacing.heightXXS,
            Text(
              widget.item.subtitle!,
              style: AppTypography.getCaption(
                color: colorScheme.onSurfaceVariant,
                scale: 0.8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context, String imageUrl, bool isChannel, ColorScheme colorScheme) {
    if (isChannel) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholder(context, colorScheme),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: 24.0,
                height: 24.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (context, error, stackTrace) =>
          _buildPlaceholder(context, colorScheme),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: SizedBox(
            width: 24.0,
            height: 24.0,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Icon(
        widget.item.mediaType == MediaType.movie
            ? AppIcons.movies
            : widget.item.mediaType == MediaType.series
                ? AppIcons.series
                : AppIcons.liveTv,
        size: 32.0,
        color: colorScheme.primary.withValues(alpha: 0.3),
      ),
    );
  }
}
