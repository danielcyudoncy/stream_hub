import 'package:flutter/material.dart';
import 'package:stream_hub/core/utils/date_formatter.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/shared/widgets/live_badge.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

class ProgramTile extends StatelessWidget {
  final EPGProgram program;
  final bool isCurrent;
  final double width;
  final VoidCallback? onTap;

  const ProgramTile({
    super.key,
    required this.program,
    this.isCurrent = false,
    this.width = 200,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TvFocusable(
      onTap: onTap,
      borderRadius: AppRadius.medium,
      scale: 1.03,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isCurrent
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : colorScheme.surfaceContainer,
          borderRadius: AppRadius.medium,
          border: isCurrent
              ? Border.all(
                  color: colorScheme.primary,
                  width: 2,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (program.isLive) const LiveBadge(),
                if (program.isNew)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    margin: const EdgeInsets.only(right: AppSpacing.xxs),
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
                if (program.isPremiere)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    margin: const EdgeInsets.only(right: AppSpacing.xxs),
                    decoration: BoxDecoration(
                      color: AppColors.darkWarning,
                      borderRadius: AppRadius.small,
                    ),
                    child: const Text(
                      'PREMIERE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              program.title,
              style: AppTypography.getBody(
                color: colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              DateFormatter.formatTimeRange(program.startTime, program.endTime),
              style: AppTypography.getCaption(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (program.subtitle != null && program.subtitle!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                program.subtitle!,
                style: AppTypography.getCaption(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (isCurrent && program.duration.inMinutes > 0) ...[
              const SizedBox(height: AppSpacing.xxs),
              LinearProgressIndicator(
                value: program.progressPercent,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  colorScheme.primary,
                ),
                minHeight: 2,
              ),
            ],
          ],
        ),
      ),
    );
  }
}