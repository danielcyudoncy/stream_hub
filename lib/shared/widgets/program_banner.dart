import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/program.dart';

class ProgramBanner extends StatelessWidget {
  final Program program;
  final bool showChannelName;
  final String? channelName;

  const ProgramBanner({
    super.key,
    required this.program,
    this.showChannelName = false,
    this.channelName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showChannelName && channelName != null) ...[
            Text(
              channelName!,
              style: AppTypography.getCaption(
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
          ],
          Text(
            program.title,
            style: AppTypography.getBody(
              color: colorScheme.onSurface,
              scale: 0.95,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          if (program.subtitle != null)
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
                _formatTime(program.startTime),
                style: AppTypography.getCaption(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Text(' - '),
              Text(
                _formatTime(program.endTime),
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

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}