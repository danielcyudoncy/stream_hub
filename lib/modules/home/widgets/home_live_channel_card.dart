import 'package:flutter/material.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/cached_home_image.dart';
import '../../../shared/widgets/live_badge.dart';
import '../../../shared/widgets/tv_focusable.dart';

class HomeLiveChannelCard extends StatelessWidget {
  final MediaItem channel;
  final VoidCallback? onTap;

  const HomeLiveChannelCard({
    super.key,
    required this.channel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final logo = channel.poster ?? channel.thumbnail;
    final currentProgram = channel.subtitle ??
        channel.metadata['currentProgram']?.toString() ??
        channel.metadata['epgTitle']?.toString();

    return TvFocusable(
      onTap: onTap,
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
                  color: colorScheme.surface,
                  borderRadius: AppRadius.medium,
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.12),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Channel logo / background
                    if (logo != null && logo.isNotEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: CachedHomeImage(
                            imageUrl: logo,
                            fit: BoxFit.contain,
                            errorBuilder: (context, url) =>
                                _buildPlaceholder(colorScheme),
                          ),
                        ),
                      )
                    else
                      _buildPlaceholder(colorScheme),

                    // Top Left LIVE Badge
                    const Positioned(
                      top: AppSpacing.xs,
                      left: AppSpacing.xs,
                      child: LiveBadge(isLive: true),
                    ),

                    // Resolution badge if available
                    if (channel.metadata['resolution'] != null)
                      Positioned(
                        top: AppSpacing.xs,
                        right: AppSpacing.xs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: AppRadius.small,
                          ),
                          child: Text(
                            channel.metadata['resolution'] as String? ?? '',
                            style: const TextStyle(
                              fontSize: 9.0,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          AppSpacing.heightXS,
          Text(
            channel.title,
            style: AppTypography.getCaption(
              color: colorScheme.onSurface,
            ).copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (currentProgram != null && currentProgram.isNotEmpty) ...[
            AppSpacing.heightXXS,
            Text(
              currentProgram,
              style: AppTypography.getCaption(
                color: colorScheme.onSurfaceVariant,
                scale: 0.82,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        AppIcons.liveTv,
        size: 36.0,
        color: colorScheme.primary.withValues(alpha: 0.4),
      ),
    );
  }
}
