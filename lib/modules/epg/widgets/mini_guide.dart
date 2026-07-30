import 'package:flutter/material.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/shared/widgets/live_badge.dart';

class MiniGuide extends StatelessWidget {
  final List<EPGProgram> programs;
  final int maxItems;
  final VoidCallback? onViewAll;

  const MiniGuide({
    super.key,
    required this.programs,
    this.maxItems = 5,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppRadius.medium,
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.live_tv_outlined,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Guide',
                style: AppTypography.getBody(
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  child: Text(
                    'View All',
                    style: AppTypography.getCaption(
                      color: colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...programs.take(maxItems).map(
                (program) => _buildProgramItem(context, colorScheme, program),
              ),
        ],
      ),
    );
  }

  Widget _buildProgramItem(
    BuildContext context,
    ColorScheme colorScheme,
    EPGProgram program,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            '${program.startTime.hour.toString().padLeft(2, '0')}:${program.startTime.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              program.title,
              style: AppTypography.getBody(
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (program.isLive) const LiveBadge(),
        ],
      ),
    );
  }
}