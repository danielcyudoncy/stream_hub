import 'package:flutter/material.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/shared/widgets/live_badge.dart';

class NowIndicator extends StatelessWidget {
  final EPGProgram program;
  final double progressPercent;
  final Duration remainingTime;

  const NowIndicator({
    super.key,
    required this.program,
    this.progressPercent = 0.0,
    this.remainingTime = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: AppRadius.medium,
        border: Border.all(
          color: colorScheme.primary,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LiveBadge(),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'LIVE NOW',
                style: AppTypography.getCaption(
                  color: AppColors.darkError,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            program.title,
            style: AppTypography.getBody(
              color: colorScheme.onSurface,
            ),
          ),
          if (program.subtitle != null && program.subtitle!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              program.subtitle!,
              style: AppTypography.getCaption(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: progressPercent.clamp(0.0, 1.0),
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              colorScheme.primary,
            ),
            minHeight: 4,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                '${(progressPercent * 100).toStringAsFixed(0)}% watched',
                style: AppTypography.getCaption(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                'Remaining: ${_formatDuration(remainingTime)}',
                style: AppTypography.getCaption(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}