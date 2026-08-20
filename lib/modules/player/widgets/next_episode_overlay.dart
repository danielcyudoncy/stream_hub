import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/tv_focusable.dart';

/// An overlay displayed at the end of an episode offering automatic countdown to play the next episode.
class NextEpisodeOverlay extends StatefulWidget {
  final MediaItem nextEpisode;
  final VoidCallback onPlayNow;
  final VoidCallback onCancel;
  final int countdownSeconds;

  const NextEpisodeOverlay({
    super.key,
    required this.nextEpisode,
    required this.onPlayNow,
    required this.onCancel,
    this.countdownSeconds = 10,
  });

  @override
  State<NextEpisodeOverlay> createState() => _NextEpisodeOverlayState();
}

class _NextEpisodeOverlayState extends State<NextEpisodeOverlay> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.countdownSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remaining <= 1) {
        timer.cancel();
        widget.onPlayNow();
      } else {
        setState(() {
          _remaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final thumbnail = ImageUrlFormatter.format(
      widget.nextEpisode.thumbnail ?? widget.nextEpisode.poster ?? widget.nextEpisode.backdrop,
      item: widget.nextEpisode,
    );
    final episodeCode = _resolveEpisodeCode();

    return Positioned(
      bottom: AppSpacing.xxl,
      right: AppSpacing.xxl,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            borderRadius: AppRadius.large,
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 16.0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    AppIcons.next,
                    size: 16.0,
                    color: colorScheme.primary,
                  ),
                  AppSpacing.widthXS,
                  Expanded(
                    child: Text(
                      'Next Episode in ${_remaining}s',
                      style: AppTypography.getLabel(
                        color: colorScheme.primary,
                      ).copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TvFocusable(
                    onTap: widget.onCancel,
                    borderRadius: AppRadius.pill,
                    child: const Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(
                        Icons.close,
                        size: 18.0,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),

              AppSpacing.heightSM,
              Row(
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.medium,
                    child: SizedBox(
                      width: 80,
                      height: 50,
                      child: thumbnail != null && thumbnail.isNotEmpty
                          ? Image.network(
                              thumbnail,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _buildPlaceholder(colorScheme),
                            )
                          : _buildPlaceholder(colorScheme),
                    ),
                  ),
                  AppSpacing.widthSM,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (episodeCode != null)
                          Text(
                            episodeCode,
                            style: AppTypography.getCaption(
                              color: colorScheme.primary,
                              scale: 0.85,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        Text(
                          widget.nextEpisode.title,
                          style: AppTypography.getLabel(
                            color: Colors.white,
                          ).copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AppSpacing.heightMD,
              Row(
                children: [
                  Expanded(
                    child: TvFocusable(
                      onTap: widget.onPlayNow,
                      borderRadius: AppRadius.pill,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.primaryGradient,
                          ),
                          borderRadius: AppRadius.pill,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              AppIcons.play,
                              size: 16.0,
                              color: Colors.white,
                            ),
                            AppSpacing.widthXXS,
                            Text(
                              'Play Now',
                              style: AppTypography.getButton(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.widthSM,
                  TvFocusable(
                    onTap: widget.onCancel,
                    borderRadius: AppRadius.pill,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: AppRadius.pill,
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTypography.getButton(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _resolveEpisodeCode() {
    final ep = widget.nextEpisode;
    final sNum = ep.metadata['seasonNumber'] ?? ep.metadata['seasonId'];
    final eNum = ep.metadata['episodeNumber'] ?? ep.metadata['streamId'];
    if (sNum != null && eNum != null) {
      final sStr = sNum.toString().padLeft(2, '0');
      final eStr = eNum.toString().padLeft(2, '0');
      return 'S${sStr}E$eStr';
    }
    return ep.subtitle;
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(
          AppIcons.series,
          size: 20.0,
          color: Colors.white38,
        ),
      ),
    );
  }
}
