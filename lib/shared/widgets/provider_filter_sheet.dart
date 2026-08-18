import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/responsive_helper.dart';
import '../../data/repositories/provider_repository.dart';
import '../../modules/provider_manager/models/provider_enums.dart';
import '../../modules/provider_manager/models/provider_model.dart';
import 'tv_focusable.dart';

class ProviderFilterSheet extends StatelessWidget {
  final String selectedProviderId;
  final ValueChanged<String> onSelectProvider;
  final String title;

  const ProviderFilterSheet({
    super.key,
    required this.selectedProviderId,
    required this.onSelectProvider,
    this.title = 'Select Provider',
  });

  static Future<void> show(
    BuildContext context, {
    required String selectedProviderId,
    required ValueChanged<String> onSelectProvider,
    String title = 'Select Provider',
  }) async {
    final isTV = ResponsiveHelper.isTV(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    if (isTV || isDesktop) {
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xl,
          ),
          child: Container(
            width: 480,
            constraints: const BoxConstraints(maxHeight: 600),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: AppRadius.large,
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ProviderFilterSheet(
              selectedProviderId: selectedProviderId,
              onSelectProvider: onSelectProvider,
              title: title,
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.extraLargeValue),
            ),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: ProviderFilterSheet(
            selectedProviderId: selectedProviderId,
            onSelectProvider: onSelectProvider,
            title: title,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final providerRepo = Get.isRegistered<ProviderRepository>()
        ? Get.find<ProviderRepository>()
        : null;

    return FutureBuilder<List<ProviderModel>>(
      future: providerRepo?.getAllProviders() ?? Future.value([]),
      builder: (context, snapshot) {
        final providers = snapshot.data ?? [];
        final isLoaded = snapshot.connectionState == ConnectionState.done;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar for Bottom Sheet
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: AppRadius.pill,
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: AppRadius.medium,
                    ),
                    child: Icon(
                      Icons.hub_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  AppSpacing.widthMD,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.getTitle(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Filter content by IPTV source',
                          style: AppTypography.getCaption(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // List of Providers
            Flexible(
              child: !isLoaded
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      children: [
                        // "All Providers" Option
                        _buildProviderItem(
                          context,
                          id: '',
                          name: 'All Providers (Unified)',
                          subtitle: 'Display content from all connected media sources',
                          icon: Icons.auto_awesome_rounded,
                          iconColor: colorScheme.primary,
                          isSelected: selectedProviderId.isEmpty,
                        ),

                        if (providers.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.sm,
                              AppSpacing.md,
                              AppSpacing.sm,
                              AppSpacing.xs,
                            ),
                            child: Text(
                              'CONNECTED PROVIDERS',
                              style: AppTypography.getCaption(
                                color: colorScheme.onSurfaceVariant,
                                scale: 0.8,
                              ).copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...providers.map((p) {
                            final iconData = _iconForProviderType(p.providerType);
                            final isSel = selectedProviderId == p.id;
                            return _buildProviderItem(
                              context,
                              id: p.id,
                              name: p.name,
                              subtitle: '${p.providerType.displayName} • ${p.status.displayName}',
                              icon: iconData,
                              iconColor: p.status == ProviderStatus.active
                                  ? AppColors.darkSuccess
                                  : colorScheme.secondary,
                              isSelected: isSel,
                            );
                          }),
                        ],
                      ],
                    ),
            ),
            AppSpacing.heightSM,
          ],
        );
      },
    );
  }

  Widget _buildProviderItem(
    BuildContext context, {
    required String id,
    required String name,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TvFocusable(
        onTap: () {
          onSelectProvider(id);
          Navigator.of(context).pop();
        },
        borderRadius: AppRadius.medium,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: AppRadius.medium,
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.medium,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              AppSpacing.widthMD,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.getBody(
                        color: colorScheme.onSurface,
                      ).copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.getCaption(
                        color: colorScheme.onSurfaceVariant,
                        scale: 0.85,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForProviderType(ProviderType type) {
    switch (type) {
      case ProviderType.xtream:
        return Icons.dns_rounded;
      case ProviderType.stalker:
        return Icons.router_rounded;
      case ProviderType.m3u:
        return Icons.playlist_play_rounded;
      case ProviderType.xmltv:
        return Icons.calendar_today_rounded;
      case ProviderType.custom:
        return Icons.extension_rounded;
    }
  }
}
