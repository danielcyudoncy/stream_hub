import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/shared/widgets/app_button.dart';
import 'package:stream_hub/shared/widgets/app_card.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/section_header.dart';
import 'package:stream_hub/shared/dialogs/confirmation_dialog.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_enums.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_model.dart';
import 'provider_manager_controller.dart';
import 'provider_form_page.dart';

class ProviderDetailsPage extends GetView<ProviderManagerController> {
  final String providerId;

  const ProviderDetailsPage({super.key, required this.providerId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Provider Details',
      body: Obx(() {
        final provider = controller.providers.firstWhereOrNull((p) => p.id == providerId);
        if (provider == null) {
          return Center(
            child: Column(
              children: [
                Icon(AppIcons.empty, size: 64, color: colorScheme.onSurface.withValues(alpha: 0.3)),
                AppSpacing.heightMD,
                Text('Provider not found', style: AppTypography.getBody(color: colorScheme.onSurface.withValues(alpha: 0.6))),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: AppRadius.medium,
                    ),
                    child: Icon(AppIcons.providers, color: colorScheme.primary, size: 28),
                  ),
                  AppSpacing.widthMD,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(provider.name, style: AppTypography.getHeadline(color: colorScheme.onSurface)),
                        AppSpacing.heightXXS,
                        Row(
                          children: [
                            _ProviderTypeBadge(type: provider.providerType),
                            AppSpacing.widthXS,
                            _ProviderStatusChip(status: provider.status),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.heightLG,
            SectionHeader(title: 'Details', subtitle: 'Provider configuration and status'),
            AppSpacing.heightXS,
            AppCard(
              child: Column(
                children: [
                  _detailRow(context, 'Type', provider.providerType.displayName),
                  _detailRow(context, 'Status', provider.status.displayName),
                  _detailRow(context, 'Enabled', provider.enabled ? 'Yes' : 'No'),
                  _detailRow(context, 'Favorite', provider.favorite ? 'Yes' : 'No'),
                  if (provider.serverUrl != null && provider.serverUrl!.isNotEmpty)
                    _detailRow(context, 'Server URL', provider.serverUrl!),
                  if (provider.username != null && provider.username!.isNotEmpty)
                    _detailRow(context, 'Username', provider.username!),
                  if (provider.macAddress != null && provider.macAddress!.isNotEmpty)
                    _detailRow(context, 'MAC Address', provider.macAddress!),
                  if (provider.xmltvUrl != null && provider.xmltvUrl!.isNotEmpty)
                    _detailRow(context, 'XMLTV URL', provider.xmltvUrl!),
                  if (provider.notes != null && provider.notes!.isNotEmpty)
                    _detailRow(context, 'Notes', provider.notes!),
                  _detailRow(context, 'Created', _formatDate(provider.createdAt)),
                  _detailRow(context, 'Last Updated', _formatDate(provider.updatedAt)),
                  if (provider.lastSync != null)
                    _detailRow(context, 'Last Sync', _formatDate(provider.lastSync!)),
                ],
              ),
            ),
            AppSpacing.heightLG,
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'Edit',
                    onPressed: () => Get.to(() => ProviderFormPage(provider: provider)),
                  ),
                ),
                AppSpacing.widthMD,
                Expanded(
                  child: AppButton(
                    text: 'Duplicate',
                    type: ButtonType.secondary,
                    onPressed: () => controller.duplicateProvider(provider.id),
                  ),
                ),
              ],
            ),
            AppSpacing.heightMD,
            AppButton(
              text: 'Delete Provider',
              type: ButtonType.danger,
              onPressed: () => _showDeleteDialog(context, provider),
            ),
          ],
        );
      }),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AppTypography.getCaption(color: colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          Expanded(
            child: Text(value, style: AppTypography.getBody(color: colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showDeleteDialog(BuildContext context, ProviderModel provider) {
    Get.dialog(DeleteDialog(
      title: 'Delete Provider',
      message: 'Are you sure you want to delete "${provider.name}"? This action cannot be undone.',
      onConfirm: () => controller.deleteProvider(provider.id),
    ));
  }
}

class _ProviderTypeBadge extends StatelessWidget {
  final ProviderType type;

  const _ProviderTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: AppRadius.small,
      ),
      child: Text(
        type.displayName,
        style: AppTypography.getCaption(color: colorScheme.primary),
      ),
    );
  }
}

class _ProviderStatusChip extends StatelessWidget {
  final ProviderStatus status;

  const _ProviderStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.outline.withValues(alpha: 0.15),
        borderRadius: AppRadius.small,
      ),
      child: Text(
        status.displayName,
        style: AppTypography.getCaption(color: colorScheme.outline),
      ),
    );
  }
}
