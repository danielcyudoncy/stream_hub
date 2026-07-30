import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'app_card.dart';

class ProviderSummaryCard extends StatelessWidget {
  final int providerCount;
  final String lastSync;
  final VoidCallback? onManageTap;

  const ProviderSummaryCard({
    super.key,
    required this.providerCount,
    required this.lastSync,
    this.onManageTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      onTap: onManageTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.playlist_play_outlined,
              color: colorScheme.primary,
              size: 24.0,
            ),
          ),
          AppSpacing.widthMD,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Media Sources',
                  style: AppTypography.getTitle(
                    color: colorScheme.onSurface,
                  ),
                ),
                AppSpacing.heightXXS,
                Text(
                  '$providerCount Connected',
                  style: AppTypography.getCaption(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Sync: $lastSync',
                style: AppTypography.getCaption(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.heightXXS,
              Text(
                'Manage',
                style: AppTypography.getCaption(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}