import 'package:flutter/material.dart';
import 'package:stream_hub/core/utils/date_formatter.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/shared/widgets/live_badge.dart';

class ProgramCard extends StatelessWidget {
  final EPGProgram program;
  final VoidCallback? onTap;
  final bool showFavorite;
  final bool showProgress;

  const ProgramCard({
    super.key,
    required this.program,
    this.onTap,
    this.showFavorite = true,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: AppRadius.large,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: AppRadius.large,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (program.poster != null && program.poster!.isNotEmpty)
                      Image.network(
                        program.poster!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(context),
                      )
                    else
                      _placeholder(context),
                    Positioned(
                      top: AppSpacing.xs,
                      left: AppSpacing.xs,
                      child: Row(
                        children: [
                          if (program.isLive) const LiveBadge(),
                          if (program.isNew)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xxs,
                                vertical: AppSpacing.xxs,
                              ),
                              margin: const EdgeInsets.only(left: AppSpacing.xxs),
                              decoration: BoxDecoration(
                                color: AppColors.darkSuccess,
                                borderRadius: AppRadius.small,
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (showFavorite)
                      Positioned(
                        top: AppSpacing.xs,
                        right: AppSpacing.xs,
                        child: IconButton(
                          icon: Icon(
                            program.favorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: program.favorite
                                ? AppColors.darkError
                                : colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          onPressed: () {},
                        ),
                      ),
                    if (showProgress && program.isCurrentlyPlaying)
                      Positioned(
                        bottom: AppSpacing.xs,
                        left: AppSpacing.xs,
                        right: AppSpacing.xs,
                        child: LinearProgressIndicator(
                          value: program.progressPercent,
                          backgroundColor: Colors.black.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.darkSuccess,
                          ),
                          minHeight: 3,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      program.title,
                      style: AppTypography.getBody(
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    if (program.subtitle != null && program.subtitle!.isNotEmpty)
                      Text(
                        program.subtitle!,
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        Text(
                          DateFormatter.formatTimeRange(program.startTime, program.endTime),
                          style: AppTypography.getCaption(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${program.duration.inMinutes} min',
                          style: AppTypography.getCaption(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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

  Widget _placeholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.live_tv_outlined,
        color: colorScheme.onSurfaceVariant,
        size: 48,
      ),
    );
  }
}