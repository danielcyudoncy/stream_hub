import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/tv_focusable.dart';

class EpisodeCard extends StatefulWidget {
  final MediaItem episode;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final String? episodeNumber;
  final double? progressPercentage;
  final bool isCompleted;
  final bool isCurrentlyPlaying;
  final bool isNextUp;
  final bool isDownloaded;
  final bool isDownloading;

  const EpisodeCard({
    super.key,
    required this.episode,
    this.onTap,
    this.onDownload,
    this.episodeNumber,
    this.progressPercentage,
    this.isCompleted = false,
    this.isCurrentlyPlaying = false,
    this.isNextUp = false,
    this.isDownloaded = false,
    this.isDownloading = false,
  });

  @override
  State<EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<EpisodeCard> {
  late final FocusNode _cardFocusNode;
  late final FocusNode _downloadFocusNode;
  late final FocusNode _playFocusNode;

  bool _isCardFocused = false;
  bool _isDownloadFocused = false;
  bool _isPlayFocused = false;

  @override
  void initState() {
    super.initState();
    _cardFocusNode = FocusNode(debugLabel: 'EpisodeCard_${widget.episode.id}');
    _downloadFocusNode =
        FocusNode(debugLabel: 'EpisodeCard_download_${widget.episode.id}');
    _playFocusNode =
        FocusNode(debugLabel: 'EpisodeCard_play_${widget.episode.id}');
  }

  @override
  void dispose() {
    _cardFocusNode.dispose();
    _downloadFocusNode.dispose();
    _playFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rawThumbnail = widget.episode.thumbnail ??
        widget.episode.poster ??
        widget.episode.backdrop;
    final thumbnail =
        ImageUrlFormatter.format(rawThumbnail, item: widget.episode) ??
        ImageUrlFormatter.extractFromMediaItem(widget.episode);

    final duration = _resolveDuration();
    final effectiveProgress = widget.progressPercentage?.clamp(0.0, 1.0);
    final hasAnyFocus =
        _isCardFocused || _isDownloadFocused || _isPlayFocused;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: widget.isCurrentlyPlaying
            ? colorScheme.primary.withValues(alpha: 0.12)
            : (hasAnyFocus
                ? colorScheme.surfaceContainerHigh
                : colorScheme.surfaceContainerLow),
        borderRadius: AppRadius.medium,
        border: (_isCardFocused || widget.isCurrentlyPlaying)
            ? Border.all(color: colorScheme.primary, width: 2.0)
            : (widget.isNextUp
                ? Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.5),
                    width: 1.0,
                  )
                : Border.all(color: Colors.transparent, width: 2.0)),
        boxShadow: _isCardFocused ? [AppShadows.neonFocusGlow] : null,
      ),
      child: Row(
        children: [
          // 1 & 2: Primary Episode Play Area (Thumbnail + Episode Info)
          Expanded(
            child: TvFocusable(
              focusNode: _cardFocusNode,
              onTap: widget.onTap,
              showFocusDecoration: false,
              scale: 1.0,
              onFocusChange: (has) {
                if (mounted && _isCardFocused != has) {
                  setState(() => _isCardFocused = has);
                }
              },
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  if (widget.onDownload != null) {
                    _downloadFocusNode.requestFocus();
                    return KeyEventResult.handled;
                  } else {
                    _playFocusNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: Row(
                children: [
                  // 1. Thumbnail with overlay badges (Fixed 16:9)
                  ClipRRect(
                    borderRadius: AppRadius.small,
                    child: SizedBox(
                      width: 120,
                      height: 68,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (thumbnail != null && thumbnail.isNotEmpty)
                            Image.network(
                              thumbnail,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildThumbnailPlaceholder(colorScheme),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: SizedBox(
                                      width: 20.0,
                                      height: 20.0,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          else
                            _buildThumbnailPlaceholder(colorScheme),

                          // Progress bar overlay at bottom of thumbnail
                          if (effectiveProgress != null &&
                              effectiveProgress > 0 &&
                              !widget.isCompleted)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                height: 4.0,
                                color: Colors.black54,
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: effectiveProgress,
                                  child: Container(color: colorScheme.primary),
                                ),
                              ),
                            ),

                          // Completed Checkmark Badge
                          if (widget.isCompleted)
                            Positioned(
                              top: AppSpacing.xxs,
                              left: AppSpacing.xxs,
                              child: Container(
                                padding: const EdgeInsets.all(2.0),
                                decoration: const BoxDecoration(
                                  color: AppColors.darkSuccess,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 14.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                          // Next Up Badge
                          if (widget.isNextUp && !widget.isCurrentlyPlaying)
                            Positioned(
                              top: AppSpacing.xxs,
                              right: AppSpacing.xxs,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                  vertical: 2.0,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: AppRadius.small,
                                ),
                                child: Text(
                                  'NEXT',
                                  style: AppTypography.getCaption(
                                    color: colorScheme.onPrimary,
                                    scale: 0.75,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                          // Currently Playing Indicator
                          if (widget.isCurrentlyPlaying)
                            Positioned(
                              top: AppSpacing.xxs,
                              right: AppSpacing.xxs,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                  vertical: 2.0,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.darkPrimary,
                                  borderRadius: AppRadius.small,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.play_arrow,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                    Text(
                                      'PLAYING',
                                      style: AppTypography.getCaption(
                                        color: Colors.white,
                                        scale: 0.75,
                                      ).copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Episode Info: Takes all available width, prominent title
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Kicker: Episode badge + duration on their own line
                          if ((widget.episodeNumber != null &&
                                  widget.episodeNumber!.isNotEmpty) ||
                              duration != null)
                            Row(
                              children: [
                                if (widget.episodeNumber != null &&
                                    widget.episodeNumber!.isNotEmpty)
                                  Flexible(
                                    child: ClipRect(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6.0,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: widget.isCurrentlyPlaying
                                              ? colorScheme.primary
                                              : colorScheme.primary.withValues(
                                                  alpha: 0.14,
                                                ),
                                          borderRadius: AppRadius.small,
                                        ),
                                        child: Text(
                                          widget.episodeNumber!,
                                          style: AppTypography.getCaption(
                                            color: widget.isCurrentlyPlaying
                                                ? colorScheme.onPrimary
                                                : colorScheme.primary,
                                            scale: 0.75,
                                          ).copyWith(
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (duration != null) ...[
                                  if (widget.episodeNumber != null &&
                                      widget.episodeNumber!.isNotEmpty)
                                    const SizedBox(width: 6.0),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 11.0,
                                            color: colorScheme
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.8),
                                          ),
                                          const SizedBox(width: 3.0),
                                          Text(
                                            duration,
                                            style: AppTypography.getCaption(
                                              color: colorScheme
                                                  .onSurfaceVariant
                                                  .withValues(alpha: 0.8),
                                              scale: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),

                          const SizedBox(height: 3.0),

                          // Clear, prominent Episode Title (wraps to 2 lines without truncation)
                          Text(
                            widget.episode.title,
                            style: AppTypography.getTitle(
                              color: widget.isCurrentlyPlaying
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                              scale: 0.72,
                            ).copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          if (widget.episode.subtitle != null &&
                              widget.episode.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2.0),
                            Text(
                              widget.episode.subtitle!,
                              style: AppTypography.getCaption(
                                color: colorScheme.onSurfaceVariant,
                                scale: 0.8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          if (widget.episode.description != null &&
                              widget.episode.description!.isNotEmpty) ...[
                            const SizedBox(height: 2.0),
                            Text(
                              widget.episode.description!,
                              style: AppTypography.getCaption(
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                                scale: 0.75,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Actions (Download + Play Buttons)
          Padding(
            padding: const EdgeInsets.only(
              right: AppSpacing.xs,
              left: AppSpacing.xxs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onDownload != null) ...[
                  TvFocusable(
                    focusNode: _downloadFocusNode,
                    onTap: widget.onDownload,
                    onFocusChange: (has) {
                      if (mounted && _isDownloadFocused != has) {
                        setState(() => _isDownloadFocused = has);
                      }
                    },
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey ==
                            LogicalKeyboardKey.arrowLeft) {
                          _cardFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        } else if (event.logicalKey ==
                            LogicalKeyboardKey.arrowRight) {
                          _playFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    borderRadius: AppRadius.pill,
                    scale: 1.15,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xxs),
                      decoration: BoxDecoration(
                        color: widget.isDownloaded
                            ? AppColors.darkSuccess.withValues(alpha: 0.2)
                            : (widget.isDownloading
                                ? colorScheme.primary
                                    .withValues(alpha: 0.15)
                                : colorScheme.surfaceContainerHighest),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isDownloaded
                            ? Icons.download_done_rounded
                            : (widget.isDownloading
                                ? Icons.downloading_rounded
                                : Icons.download_rounded),
                        size: 18.0,
                        color: widget.isDownloaded
                            ? AppColors.darkSuccess
                            : (widget.isDownloading
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                  AppSpacing.widthXS,
                ],

                // Play Button
                TvFocusable(
                  focusNode: _playFocusNode,
                  onTap: widget.onTap,
                  onFocusChange: (has) {
                    if (mounted && _isPlayFocused != has) {
                      setState(() => _isPlayFocused = has);
                    }
                  },
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      if (widget.onDownload != null) {
                        _downloadFocusNode.requestFocus();
                        return KeyEventResult.handled;
                      } else {
                        _cardFocusNode.requestFocus();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  borderRadius: AppRadius.pill,
                  scale: 1.15,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xxs),
                    decoration: BoxDecoration(
                      color: widget.isCurrentlyPlaying
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isCompleted
                          ? Icons.replay
                          : (widget.isCurrentlyPlaying
                              ? Icons.pause
                              : AppIcons.play),
                      size: 18.0,
                      color: widget.isCurrentlyPlaying
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _resolveDuration() {
    final direct = widget.episode.metadata['duration'] ??
        widget.episode.metadata['durationSeconds'] ??
        widget.episode.metadata['runtime'] ??
        widget.episode.metadata['length'];
    if (direct != null) {
      final val = int.tryParse(direct.toString());
      if (val != null && val > 0) {
        if (val > 300) {
          final mins = (val / 60).round();
          return '$mins min';
        }
        return '$val min';
      }
    }
    return null;
  }

  Widget _buildThumbnailPlaceholder(ColorScheme colorScheme) {
    return Container(
      width: 120,
      height: 68,
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          AppIcons.series,
          size: 24.0,
          color: colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
