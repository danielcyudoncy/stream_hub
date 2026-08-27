import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/responsive_helper.dart';
import '../../data/repositories/provider_repository.dart';
import '../../modules/provider_manager/models/provider_model.dart';
import 'provider_filter_sheet.dart';
import 'tv_focusable.dart';

class ProviderSelectorButton extends StatelessWidget {
  final String selectedProviderId;
  final ValueChanged<String> onSelectProvider;
  final String sheetTitle;
  final bool isCompact;

  const ProviderSelectorButton({
    super.key,
    required this.selectedProviderId,
    required this.onSelectProvider,
    this.sheetTitle = 'Select Provider',
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final providerRepo = Get.isRegistered<ProviderRepository>()
        ? Get.find<ProviderRepository>()
        : null;

    return FutureBuilder<List<ProviderModel>>(
      future: providerRepo != null
          ? providerRepo.getAllProviders()
          : Future.value([]),
      builder: (context, snapshot) {
        final allProviders = snapshot.data ?? [];

        ProviderModel? provider;
        if (selectedProviderId.isNotEmpty) {
          provider = allProviders.firstWhereOrNull(
            (p) =>
                p.id == selectedProviderId ||
                p.name.toLowerCase() == selectedProviderId.toLowerCase() ||
                p.providerType.displayName.toLowerCase() ==
                    selectedProviderId.toLowerCase() ||
                p.providerType.name.toLowerCase() ==
                    selectedProviderId.toLowerCase(),
          );
        } else if (allProviders.length == 1) {
          provider = allProviders.first;
        }

        final hasSpecificProvider = provider != null;
        final label = hasSpecificProvider
            ? provider.name
            : (selectedProviderId.isNotEmpty
                ? selectedProviderId
                : (allProviders.isNotEmpty
                    ? (allProviders.length == 1
                        ? allProviders.first.name
                        : 'All Providers')
                    : 'All Providers'));

        // Compute letter (e.g. 'P' from provider name, or 'A' from 'All Providers')
        final initialLetter = label.trim().isNotEmpty
            ? label.trim()[0].toUpperCase()
            : 'P';

        if (isCompact) {
          return Tooltip(
            message: 'Provider: $label',
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
                width: 36.0,
                height: 36.0,
                margin: const EdgeInsets.only(right: 6.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryContainer.withValues(alpha: 0.45),
                      AppColors.primary.withValues(alpha: 0.15),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 6.0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  initialLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 2.0,
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
                horizontal: AppSpacing.sm,
                vertical: 4.0,
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
                  Container(
                    width: 20.0,
                    height: 20.0,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initialLetter,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveHelper.isPhone(context) ? 80 : 110,
                    ),
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
