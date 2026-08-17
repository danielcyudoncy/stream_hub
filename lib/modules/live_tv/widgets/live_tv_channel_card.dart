import 'package:flutter/material.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/channel.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/live_badge.dart';

class LiveTvChannelCard extends StatefulWidget {
  final MediaItem channel;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool isList;
  final bool showFavoriteButton;
  final bool showChannelNumber;
  final bool showHD;

  const LiveTvChannelCard({
    super.key,
    required this.channel,
    this.onTap,
    this.onFavorite,
    this.isList = false,
    this.showFavoriteButton = true,
    this.showChannelNumber = true,
    this.showHD = true,
  });

  @override
  State<LiveTvChannelCard> createState() => _LiveTvChannelCardState();
}

class _LiveTvChannelCardState extends State<LiveTvChannelCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isList) {
      return _buildListTile(context);
    }
    return _buildGridCard(context);
  }

  Widget _buildGridCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isChannel = widget.channel is Channel;
    final channelNum = isChannel ? (widget.channel as Channel).number : null;
    final isLive = isChannel ? (widget.channel as Channel).isLive : true;
    final posterUrl = widget.channel.poster ?? widget.channel.thumbnail;
    final hasPoster = posterUrl != null && posterUrl.isNotEmpty;
    final resolution = widget.channel.metadata['resolution'] as String?;
    final isTV = PlatformHelper.isTV;

    return FocusableActionDetector(
      onShowFocusHighlight: (show) {
        if (mounted && _isFocused != show) {
          setState(() => _isFocused = show);
        }
      },
      mouseCursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isFocused ? (isTV ? 1.06 : 1.02) : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: AppRadius.medium,
              border: Border.all(
                color: _isFocused
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.1),
                width: _isFocused ? 2.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isFocused
                      ? colorScheme.primary.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.2),
                  blurRadius: _isFocused ? 16.0 : 8.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Logo / Preview Area
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10.0),
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Centered properly scaled channel logo
                        if (hasPoster)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Image.network(
                              posterUrl,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildFallbackLogo(colorScheme),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          _buildFallbackLogo(colorScheme),

                      // Top-Left: Channel number / Live badge
                      Positioned(
                        top: AppSpacing.xxs,
                        left: AppSpacing.xxs,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isLive) ...[
                              const LiveBadge(isLive: true),
                              const SizedBox(width: 4.0),
                            ],
                            if (widget.showChannelNumber && channelNum != null && channelNum.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5.0,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: AppRadius.small,
                                ),
                                child: Text(
                                  channelNum,
                                  style: TextStyle(
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Bottom-Left: Resolution badge
                      if (widget.showHD && resolution != null && resolution.isNotEmpty)
                        Positioned(
                          bottom: AppSpacing.xxs,
                          left: AppSpacing.xxs,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5.0,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: AppRadius.small,
                            ),
                            child: Text(
                              resolution.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                      // Top-Right: Favorite Button
                      if (widget.showFavoriteButton)
                        Positioned(
                          top: AppSpacing.xxs,
                          right: AppSpacing.xxs,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: widget.onFavorite,
                            child: Container(
                              padding: const EdgeInsets.all(5.0),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.channel.favorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: widget.channel.favorite
                                    ? AppColors.darkError
                                    : Colors.white70,
                                size: 16.0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Channel metadata section below image
              Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs + 2.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.channel.title,
                        style: AppTypography.getBody(
                          color: _isFocused ? Colors.white : colorScheme.onSurface,
                          scale: 0.9,
                        ).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.channel.genres.isNotEmpty ||
                          (widget.channel.subtitle != null && widget.channel.subtitle!.isNotEmpty)) ...[
                        const SizedBox(height: 1.5),
                        Text(
                          widget.channel.genres.isNotEmpty
                              ? widget.channel.genres.first
                              : (widget.channel.subtitle ?? ''),
                          style: AppTypography.getCaption(
                            color: AppColors.darkTextMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isChannel = widget.channel is Channel;
    final channelNum = isChannel ? (widget.channel as Channel).number : null;
    final isLive = isChannel ? (widget.channel as Channel).isLive : true;
    final posterUrl = widget.channel.poster ?? widget.channel.thumbnail;
    final hasPoster = posterUrl != null && posterUrl.isNotEmpty;
    final resolution = widget.channel.metadata['resolution'] as String?;
    final isTV = PlatformHelper.isTV;

    return FocusableActionDetector(
      onShowFocusHighlight: (show) {
        if (mounted && _isFocused != show) {
          setState(() => _isFocused = show);
        }
      },
      mouseCursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isFocused ? (isTV ? 1.02 : 1.01) : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xxs,
            ),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: AppRadius.medium,
              border: Border.all(
                color: _isFocused
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.08),
                width: _isFocused ? 2.0 : 1.0,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 10.0,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Thumbnail container
                Container(
                  width: 52.0,
                  height: 52.0,
                  padding: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: AppRadius.small,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasPoster
                      ? Image.network(
                          posterUrl,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildFallbackLogo(colorScheme),
                        )
                      : _buildFallbackLogo(colorScheme),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Channel Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          if (channelNum != null && channelNum.isNotEmpty) ...[
                            Text(
                              channelNum,
                              style: TextStyle(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 6.0),
                          ],
                          Expanded(
                            child: Text(
                              widget.channel.title,
                              style: AppTypography.getBody(
                                color: _isFocused ? Colors.white : colorScheme.onSurface,
                              ).copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2.0),
                      Row(
                        children: [
                          if (widget.channel.genres.isNotEmpty)
                            Flexible(
                              child: Text(
                                widget.channel.genres.take(2).join(' • '),
                                style: AppTypography.getCaption(
                                  color: AppColors.darkTextMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          else if (widget.channel.subtitle != null)
                            Flexible(
                              child: Text(
                                widget.channel.subtitle!,
                                style: AppTypography.getCaption(
                                  color: AppColors.darkTextMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (resolution != null && resolution.isNotEmpty) ...[
                            const SizedBox(width: 6.0),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                                vertical: 1.0,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: AppRadius.small,
                              ),
                              child: Text(
                                resolution.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 8.0,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Trailing actions (Live badge + Favorite icon)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLive) ...[
                      const LiveBadge(isLive: true),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    if (widget.showFavoriteButton)
                      IconButton(
                        icon: Icon(
                          widget.channel.favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: widget.channel.favorite
                              ? AppColors.darkError
                              : AppColors.darkTextSecondary,
                          size: 20.0,
                        ),
                        onPressed: widget.onFavorite,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackLogo(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.live_tv_rounded,
          color: colorScheme.primary.withValues(alpha: 0.6),
          size: 28.0,
        ),
      ),
    );
  }
}
