import 'package:flutter/material.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/channel.dart';
import '../../../data/models/media_item.dart';

class LiveTvFavoritesRow extends StatelessWidget {
  final List<MediaItem> favorites;
  final ValueChanged<MediaItem> onChannelTap;
  final ValueChanged<MediaItem>? onFavoriteToggle;
  final VoidCallback? onSeeAll;

  const LiveTvFavoritesRow({
    super.key,
    required this.favorites,
    required this.onChannelTap,
    this.onFavoriteToggle,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 18.0),
                    const SizedBox(width: 6.0),
                    Text(
                      'Favorite Channels',
                      style: AppTypography.getTitle(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: AppRadius.pill,
                      ),
                      child: Text(
                        '${favorites.length}',
                        style: TextStyle(
                          fontSize: 10.0,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (onSeeAll != null)
                  TextButton(
                    onPressed: onSeeAll,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('See All'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 120.0,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final channel = favorites[index];
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _FavoriteQuickCard(
                    channel: channel,
                    onTap: () => onChannelTap(channel),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteQuickCard extends StatefulWidget {
  final MediaItem channel;
  final VoidCallback onTap;

  const _FavoriteQuickCard({
    required this.channel,
    required this.onTap,
  });

  @override
  State<_FavoriteQuickCard> createState() => _FavoriteQuickCardState();
}

class _FavoriteQuickCardState extends State<_FavoriteQuickCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isChannel = widget.channel is Channel;
    final isLive = isChannel ? (widget.channel as Channel).isLive : true;
    final posterUrl = widget.channel.poster ?? widget.channel.thumbnail;
    final hasPoster = posterUrl != null && posterUrl.isNotEmpty;
    final isTV = PlatformHelper.isTV;

    return FocusableActionDetector(
      onShowFocusHighlight: (show) {
        if (mounted && _isFocused != show) {
          setState(() => _isFocused = show);
        }
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onTap(),
        ),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
          onInvoke: (_) => widget.onTap(),
        ),
      },
      mouseCursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isFocused ? (isTV ? 1.08 : 1.03) : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 100.0,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: AppRadius.medium,
              border: Border.all(
                color: _isFocused
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.1),
                width: _isFocused ? 2.0 : 1.0,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.35),
                        blurRadius: 12.0,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: ClipRRect(
                          borderRadius: AppRadius.small,
                          child: hasPoster
                              ? Image.network(
                                  posterUrl,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildPlaceholder(colorScheme),
                                )
                              : _buildPlaceholder(colorScheme),
                        ),
                      ),
                      if (isLive)
                        Positioned(
                          top: 4.0,
                          left: 4.0,
                          child: Container(
                            width: 8.0,
                            height: 8.0,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.darkError,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 4.0,
                  ),
                  child: Text(
                    widget.channel.title,
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: _isFocused ? Colors.white : colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.live_tv_rounded,
          color: colorScheme.primary.withValues(alpha: 0.5),
          size: 24.0,
        ),
      ),
    );
  }
}
