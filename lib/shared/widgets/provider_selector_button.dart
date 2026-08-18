import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/repositories/provider_repository.dart';
import '../../modules/provider_manager/models/provider_model.dart';
import 'provider_filter_sheet.dart';
import 'tv_focusable.dart';

class ProviderSelectorButton extends StatelessWidget {
  final String selectedProviderId;
  final ValueChanged<String> onSelectProvider;
  final String sheetTitle;

  const ProviderSelectorButton({
    super.key,
    required this.selectedProviderId,
    required this.onSelectProvider,
    this.sheetTitle = 'Select Provider',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final providerRepo = Get.isRegistered<ProviderRepository>()
        ? Get.find<ProviderRepository>()
        : null;

    return FutureBuilder<ProviderModel?>(
      future: selectedProviderId.isNotEmpty && providerRepo != null
          ? providerRepo.getProviderById(selectedProviderId)
          : Future.value(null),
      builder: (context, snapshot) {
        final provider = snapshot.data;
        final hasSpecificProvider = selectedProviderId.isNotEmpty && provider != null;
        final label = hasSpecificProvider ? provider.name : 'All Providers';

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: TvFocusable(
            onTap: () {
              ProviderFilterSheet.show(
                context,
                selectedProviderId: selectedProviderId,
                onSelectProvider: onSelectProvider,
                title: sheetTitle,
              );
            },
            borderRadius: AppRadius.pill,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 2,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: hasSpecificProvider
                    ? colorScheme.primary.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: AppRadius.pill,
                border: Border.all(
                  color: hasSpecificProvider
                      ? colorScheme.primary.withValues(alpha: 0.4)
                      : colorScheme.outline.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasSpecificProvider ? Icons.hub_rounded : Icons.auto_awesome_rounded,
                    size: 15,
                    color: hasSpecificProvider ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      label,
                      style: AppTypography.getCaption(
                        color: hasSpecificProvider ? colorScheme.primary : colorScheme.onSurface,
                      ).copyWith(
                        fontWeight: hasSpecificProvider ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 18,
                    color: hasSpecificProvider ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
