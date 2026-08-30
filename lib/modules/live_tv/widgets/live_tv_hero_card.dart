import 'package:flutter/material.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/title_formatter.dart';
import '../../../data/models/channel.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/channel_placeholder.dart';
import '../../../shared/widgets/tv_focusable.dart';

class LiveTvHeroCard extends StatefulWidget {
  final MediaItem? channel;
  final VoidCallback? onWatch;
  final VoidCallback? onFavorite;

  const LiveTvHeroCard({
    super.key,
    required this.channel,
    this.onWatch,
    this.onFavorite,
  });

  @override
  State<LiveTvHeroCard> createState() => _LiveTvHeroCardState();
}

class _LiveTvHeroCardState extends State<LiveTvHeroCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    if (channel == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isChannel = channel is Channel;
    final channelNumber = isChannel ? channel.number : null;
    final resolution = channel.metadata['resolution'] as String?;
    final posterUrl = channel.poster ?? channel.thumbnail;
    final hasPoster = posterUrl != null && posterUrl.isNotEmpty;
    final isTV = PlatformHelper.isTV;

    return FocusableActionDetector(
      onShowFocusHighlight: (show) {
        if (mounted && _isFocused != show) {
          setState(() => _isFocused = show);
        }
      },
      mouseCursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onWatch,
        child: AnimatedScale(
          scale: _isFocused ? (isTV ? 1.03 : 1.01) : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: isTV ? 220.0 : 180.0,
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: AppRadius.large,
              border: Border.all(
                color: _isFocused
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.12),
                width: _isFocused ? 2.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isFocused
                      ? colorScheme.primary.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.3),
                  blurRadius: _isFocused ? 20.0 : 12.0,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: AppRadius.large,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background blurred image / backdrop
                  if (hasPoster)
                    Positioned.fill(
                      child: Image.network(
                        posterUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),

                  // Dark gradient overlay for rich contrast and readable typography
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            AppColors.darkBackground.withValues(alpha: 0.95),
                            AppColors.darkBackground.withValues(alpha: 0.88),
                            AppColors.darkBackground.withValues(alpha: 0.50),
                            AppColors.darkBackground.withValues(alpha: 0.30),
                          ],
                          stops: const [0.0, 0.45, 0.75, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Content layer
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        // Channel Logo container
                        Container(
                          width: isTV ? 88.0 : 72.0,
                          height: isTV ? 88.0 : 72.0,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: AppRadius.medium,
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.15),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: AppRadius.medium,
                            child: hasPoster
                                ? Image.network(
                                    posterUrl,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.center,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildLogoFallback(colorScheme),
                                  )
                                : _buildLogoFallback(colorScheme),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),

                        // Channel info & details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Top badges row (Channel number + Resolution)
                              if ((channelNumber != null && channelNumber.isNotEmpty) ||
                                  (resolution != null && resolution.isNotEmpty))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                                  child: Row(
                                    children: [
                                      if (channelNumber != null && channelNumber.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6.0,
                                            vertical: 2.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary.withValues(alpha: 0.18),
                                            borderRadius: AppRadius.small,
                                            border: Border.all(
                                              color: colorScheme.primary.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            'CH $channelNumber',
                                            style: TextStyle(
                                              color: colorScheme.primary,
                                              fontSize: 10.0,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      if (resolution != null && resolution.isNotEmpty) ...[
                                        const SizedBox(width: AppSpacing.xs),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5.0,
                                            vertical: 2.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.12),
                                            borderRadius: AppRadius.small,
                                          ),
                                          child: Text(
                                            resolution.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 9.0,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                              // Channel Title
                              Text(
                                TitleFormatter.formatChannelTitle(channel.title),
                                style: AppTypography.getHeadline(
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // Channel Subtitle / Genre
                              if (channel.genres.isNotEmpty ||
                                  (channel.subtitle != null && channel.subtitle!.isNotEmpty)) ...[
                                const SizedBox(height: 2.0),
                                Text(
                                  channel.genres.isNotEmpty
                                      ? channel.genres.take(2).join(' • ')
                                      : (channel.subtitle ?? ''),
                                  style: AppTypography.getCaption(
                                    color: AppColors.darkTextSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              const SizedBox(height: AppSpacing.xs),

                              // Watch Now button & Favorite button
                              Row(
                                children: [
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: FilledButton.icon(
                                        onPressed: widget.onWatch,
                                        icon: const Icon(Icons.play_arrow_rounded, size: 18.0),
                                        label: const Text('Watch Live'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: colorScheme.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm + 4.0,
                                            vertical: 6.0,
                                          ),
                                          shape: const RoundedRectangleBorder(
                                            borderRadius: AppRadius.pill,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (widget.onFavorite != null) ...[
                                    const SizedBox(width: AppSpacing.xs),
                                    TvFocusable(
                                      onTap: widget.onFavorite,
                                      scale: 1.05,
                                      borderRadius: BorderRadius.circular(6),
                                      child: IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.all(4.0),
                                        constraints: const BoxConstraints(),
                                        onPressed: widget.onFavorite,
                                        icon: Icon(
                                          channel.favorite
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          color: channel.favorite
                                              ? AppColors.darkError
                                              : Colors.white70,
                                          size: 20.0,
                                        ),
                                        tooltip: channel.favorite
                                            ? 'Remove from Favorites'
                                            : 'Add to Favorites',
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
          ),
        ),
      ),
    );
  }

  Widget _buildLogoFallback(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: const ChannelPlaceholder(
        iconSize: 28.0,
        fontSize: 10.0,
      ),
    );
  }
}
