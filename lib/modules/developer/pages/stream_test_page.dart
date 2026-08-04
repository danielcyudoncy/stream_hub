import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/modules/developer/pages/stream_test_controller.dart';
import 'package:stream_hub/modules/developer/widgets/diagnostics_report_view.dart';
import 'package:stream_hub/shared/widgets/app_card.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';

class StreamTestPage extends GetView<StreamTestController> {
  const StreamTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'Stream Test',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Media Item ID',
                  style: AppTypography.getTitle(color: colorScheme.onSurface),
                ),
                AppSpacing.heightXS,
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'channel-1234',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: controller.updateMediaItemId,
                ),
                AppSpacing.heightMD,
                Text(
                  'Stream URL',
                  style: AppTypography.getTitle(color: colorScheme.onSurface),
                ),
                AppSpacing.heightXS,
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'https://provider.example/stream.m3u8',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: controller.updateStreamUrl,
                ),
                AppSpacing.heightMD,
                Text(
                  'Provider Type',
                  style: AppTypography.getTitle(color: colorScheme.onSurface),
                ),
                AppSpacing.heightXS,
                Obx(
                  () => Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final type in controller.providerTypes)
                        ChoiceChip(
                          label: Text(type.displayName),
                          selected: controller.providerType == type,
                          onSelected: (_) => controller.setProviderType(type),
                        ),
                    ],
                  ),
                ),
                AppSpacing.heightMD,
                Text(
                  'Provider ID (optional)',
                  style: AppTypography.getTitle(color: colorScheme.onSurface),
                ),
                AppSpacing.heightXS,
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'provider-1',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: controller.updateProviderId,
                ),
                AppSpacing.heightSM,
                Obx(
                  () => FilledButton.icon(
                    onPressed: controller.isRunning ? null : controller.run,
                    icon: Icon(
                      controller.isRunning ? AppIcons.pause : AppIcons.play,
                    ),
                    label: Text(
                      controller.isRunning ? 'Running…' : 'Run Test',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Obx(() {
            if (controller.isRunning) {
              return const Padding(
                padding: EdgeInsets.only(top: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final error = controller.error;
            if (error != null) {
              return AppCard(
                color: colorScheme.error.withValues(alpha: 0.06),
                child: Text(
                  error,
                  style: AppTypography.getBody(color: colorScheme.onSurface),
                ),
              );
            }
            final result = controller.result;
            if (result == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: DiagnosticsReportView(report: result.report),
            );
          }),
        ],
      ),
    );
  }
}
