import 'package:flutter/material.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';

class TimelineHeader extends StatelessWidget {
  final DateTime windowStart;
  final DateTime windowEnd;
  final int visibleHours;
  final VoidCallback? onNowTap;

  const TimelineHeader({
    super.key,
    required this.windowStart,
    required this.windowEnd,
    this.visibleHours = 6,
    this.onNowTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Text(
            _formatDateRange(windowStart, windowEnd),
            style: AppTypography.getTitle(
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          if (onNowTap != null)
            OutlinedButton.icon(
              onPressed: onNowTap,
              icon: const Icon(Icons.now_widgets, size: 18),
              label: const Text('Now'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.primary,
                side: BorderSide(color: colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDateRange(DateTime start, DateTime end) {
    return '${_formatDate(start)} - ${_formatDate(end)}';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}