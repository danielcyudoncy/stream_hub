import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/models/playlist_analysis.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/modules/developer/pages/provider_test_controller.dart';
import 'package:stream_hub/modules/developer/widgets/diagnostics_report_view.dart';
import 'package:stream_hub/shared/widgets/app_card.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

class ProviderTestPage extends GetView<ProviderTestController> {
  const ProviderTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'Provider Test',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Provider URL',
                  style: AppTypography.getTitle(color: colorScheme.onSurface),
                ),
                AppSpacing.heightXS,
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'https://provider.example/get.php?...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: controller.updateUrl,
                ),
                AppSpacing.heightMD,
                Text(
                  'Or playlist content',
                  style: AppTypography.getTitle(color: colorScheme.onSurface),
                ),
                AppSpacing.heightXS,
                TextField(
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: '#EXTM3U\n#EXTINF:-1,Channel Name\nhttp://...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: controller.updateContent,
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
                        controller.isRunning ? 'Running…' : 'Analyze',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DiagnosticsReportView(report: result.report),
                  if (result.playlist != null) ...[
                    AppSpacing.heightXS,
                    _playlistCard(colorScheme, result.playlist!),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _playlistCard(ColorScheme colorScheme, PlaylistAnalysis playlist) {
    final stats = playlist.stats;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Playlist',
            style: AppTypography.getTitle(color: colorScheme.onSurface),
          ),
          AppSpacing.heightXS,
          _row(colorScheme, 'Entries', '${stats.totalEntries}'),
          _row(colorScheme, 'Valid', '${stats.validEntries}'),
          _row(colorScheme, 'Invalid', '${stats.invalidEntries}'),
          _row(colorScheme, 'Channels', '${playlist.channelCount}'),
          _row(colorScheme, 'Movies', '${playlist.movieCount}'),
          _row(colorScheme, 'Series', '${playlist.seriesCount}'),
          _row(colorScheme, 'Radio', '${playlist.radioCount}'),
          _row(colorScheme, 'Groups', '${playlist.groups.length}'),
          if (playlist.epgSources.isNotEmpty)
            _row(colorScheme, 'EPG sources', '${playlist.epgSources.length}'),
        ],
      ),
    );
  }

  Widget _row(ColorScheme colorScheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: AppTypography.getCaption(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.getLabel(color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
