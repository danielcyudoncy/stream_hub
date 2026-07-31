import 'package:flutter/material.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_enums.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_model.dart';
import 'app_card.dart';

class ProviderCard extends StatelessWidget {
  final ProviderModel provider;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onEnabledToggle;

  const ProviderCard({
    super.key,
    required this.provider,
    this.onTap,
    this.onFavoriteToggle,
    this.onEnabledToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _resolveColor(colorScheme),
              borderRadius: AppRadius.medium,
            ),
            child: Icon(
              _resolveIcon(),
              color: colorScheme.onPrimary,
              size: 24,
            ),
          ),
          AppSpacing.widthMD,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.name,
                  style: AppTypography.getTitle(color: colorScheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.heightXXS,
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                          borderRadius: AppRadius.small,
                        ),
                        child: Text(
                          provider.providerType.displayName,
                          style: AppTypography.getCaption(color: colorScheme.primary),
                        ),
                      ),
                      AppSpacing.widthXS,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.outline.withValues(alpha: 0.15),
                          borderRadius: AppRadius.small,
                        ),
                        child: Text(
                          provider.status.displayName,
                          style: AppTypography.getCaption(color: colorScheme.outline),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onFavoriteToggle != null)
            IconButton(
              icon: Icon(
                provider.favorite ? Icons.favorite : Icons.favorite_border,
                color: provider.favorite ? colorScheme.error : colorScheme.onSurface.withValues(alpha: 0.5),
                size: 20,
              ),
              onPressed: onFavoriteToggle,
              tooltip: provider.favorite ? 'Remove from favorites' : 'Add to favorites',
            ),
          Switch(
            value: provider.enabled,
            onChanged: (_) => onEnabledToggle?.call(),
            activeThumbColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Color _resolveColor(ColorScheme colorScheme) {
    if (provider.color != null) {
      try {
        return Color(int.parse(provider.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return colorScheme.primary;
  }

  IconData _resolveIcon() {
    switch (provider.providerType) {
      case ProviderType.m3u:
        return Icons.playlist_play;
      case ProviderType.xtream:
        return Icons.api;
      case ProviderType.stalker:
        return Icons.devices;
      case ProviderType.xmltv:
        return Icons.tv;
      case ProviderType.custom:
        return Icons.extension;
    }
  }
}
