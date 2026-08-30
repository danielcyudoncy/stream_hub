import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/modules/developer/pages/playback_test_controller.dart';
import 'package:stream_hub/modules/developer/widgets/diagnostics_report_view.dart';
import 'package:stream_hub/shared/widgets/app_card.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

class PlaybackTestPage extends GetView<PlaybackTestController> {
  const PlaybackTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'Playback Test',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  onChanged: controller.updateUrl,
                ),
                AppSpacing.heightSM,
                Obx(
                  () => TvFocusable(
                    onTap: controller.isRunning ? null : controller.run,
                    borderRadius: BorderRadius.circular(8),
                    focusColor: colorScheme.primary,
                    child: FilledButton.icon(
                      onPressed: controller.isRunning ? null : controller.run,
                      icon: Icon(
                        controller.isRunning ? AppIcons.pause : AppIcons.play,
                      ),
                      label: Text(
                        controller.isRunning ? 'Running…' : 'Run Test',
                      ),
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
              return _errorCard(colorScheme, error);
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

  Widget _errorCard(ColorScheme colorScheme, String message) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: AppCard(
        color: colorScheme.error.withValues(alpha: 0.06),
        child: Row(
          children: [
            Icon(AppIcons.error, color: colorScheme.error),
            AppSpacing.widthSM,
            Expanded(
              child: Text(
                message,
                style: AppTypography.getBody(color: colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
