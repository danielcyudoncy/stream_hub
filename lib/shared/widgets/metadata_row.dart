import 'package:flutter/material.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class MetadataRow extends StatelessWidget {
  final List<MetadataItem> items;
  final bool wrap;

  const MetadataRow({
    super.key,
    required this.items,
    this.wrap = false,
  });

  @override
  Widget build(BuildContext context) {
    if (wrap) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: items.map((item) => _buildChip(context, item)).toList(),
      );
    }

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: items.map((item) => _buildRow(context, item)).toList(),
    );
  }

  Widget _buildRow(BuildContext context, MetadataItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          item.icon,
          size: 16.0,
          color: item.color ?? colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          item.value,
          style: AppTypography.getCaption(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildChip(BuildContext context, MetadataItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.small,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.icon,
            size: 14.0,
            color: item.color ?? colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4.0),
          Text(
            item.value,
            style: AppTypography.getCaption(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class MetadataItem {
  final IconData icon;
  final String value;
  final Color? color;

  const MetadataItem({
    required this.icon,
    required this.value,
    this.color,
  });
}