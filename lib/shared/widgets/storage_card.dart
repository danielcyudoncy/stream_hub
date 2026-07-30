import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'app_card.dart';

class StorageCard extends StatelessWidget {
  final String title;
  final String usedSpace;
  final String totalSpace;
  final double usagePercent;
  final VoidCallback? onTap;

  const StorageCard({
    super.key,
    required this.title,
    required this.usedSpace,
    required this.totalSpace,
    required this.usagePercent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storage_outlined,
                color: colorScheme.primary,
                size: 20.0,
              ),
              AppSpacing.widthSM,
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.getTitle(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16.0,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
            ],
          ),
          AppSpacing.heightMD,
          Row(
            children: [
              Text(
                usedSpace,
                style: AppTypography.getBody(
                  color: colorScheme.onSurface,
                ),
              ),
              const Text(' / '),
              Text(
                totalSpace,
                style: AppTypography.getCaption(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AppSpacing.heightSM,
          LinearProgressIndicator(
            value: usagePercent.clamp(0.0, 1.0),
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              usagePercent > 0.8
                  ? colorScheme.error
                  : colorScheme.primary,
            ),
            minHeight: 6.0,
          ),
          AppSpacing.heightXXS,
          Text(
            '${(usagePercent * 100).toStringAsFixed(1)}% used',
            style: AppTypography.getCaption(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}