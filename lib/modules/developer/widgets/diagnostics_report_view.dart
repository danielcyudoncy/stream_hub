import 'package:flutter/material.dart';
import 'package:stream_hub/core/iptv/models/stream_diagnostics_report.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/shared/widgets/app_card.dart';

class DiagnosticsReportView extends StatelessWidget {
  final StreamDiagnosticsReport report;

  const DiagnosticsReportView({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummary(context, colorScheme),
        AppSpacing.heightXS,
        if (report.rootCause != null) _buildRootCause(context, colorScheme),
        AppSpacing.heightXS,
        if (report.steps.isNotEmpty) _buildSteps(context, colorScheme),
        AppSpacing.heightXS,
        if (report.providerDetection != null)
          _buildDetection(context, colorScheme),
        AppSpacing.heightXS,
        if (report.providerCapabilities != null)
          _buildCapabilities(context, colorScheme),
        if (report.negotiated != null)
          _buildNegotiated(context, colorScheme),
      ],
    );
  }

  Widget _buildSummary(BuildContext context, ColorScheme colorScheme) {
    final statusColor =
        report.succeeded ? colorScheme.primary : colorScheme.error;
    return AppCard(
      child: Row(
        children: [
          Icon(
            report.succeeded ? AppIcons.success : AppIcons.error,
            color: statusColor,
            size: 28,
          ),
          AppSpacing.widthSM,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.succeeded ? 'Stream is playable' : 'Stream failed',
                  style: AppTypography.getTitle(color: statusColor),
                ),
                if (report.negotiated != null)
                  Text(
                    '${report.negotiated!.protocol.displayName} → '
                    '${report.negotiated!.playerName}',
                    style: AppTypography.getCaption(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                Text(
                  '${report.totalDuration.inMilliseconds}ms · '
                  '${report.errors.length} error(s) · '
                  '${report.warnings.length} warning(s)',
                  style: AppTypography.getCaption(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRootCause(BuildContext context, ColorScheme colorScheme) {
    return AppCard(
      color: colorScheme.error.withValues(alpha: 0.06),
      child: Row(
        children: [
          Icon(AppIcons.warning, color: colorScheme.error, size: 22),
          AppSpacing.widthSM,
          Expanded(
            child: Text(
              'Likely cause: ${report.rootCause}',
              style: AppTypography.getLabel(color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteps(BuildContext context, ColorScheme colorScheme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Diagnostics',
            style: AppTypography.getTitle(color: colorScheme.onSurface),
          ),
          AppSpacing.heightXS,
          for (final step in report.steps) _buildStep(step, colorScheme),
        ],
      ),
    );
  }

  Widget _buildStep(DiagnosticStep step, ColorScheme colorScheme) {
    final icon = step.isError
        ? AppIcons.error
        : step.isWarning
            ? AppIcons.warning
            : AppIcons.success;
    final iconColor = step.isError
        ? colorScheme.error
        : step.isWarning
            ? colorScheme.tertiary
            : colorScheme.primary;
    final statusLabel = step.isError
        ? 'failed'
        : step.isWarning
            ? 'warning'
            : 'ok';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          AppSpacing.widthXS,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${step.name} · $statusLabel',
                  style: AppTypography.getLabel(color: colorScheme.onSurface),
                ),
                if (step.detail != null && step.detail!.isNotEmpty)
                  Text(
                    step.detail!,
                    style: AppTypography.getCaption(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          if (step.duration > Duration.zero)
            Text(
              '${step.duration.inMilliseconds}ms',
              style: AppTypography.getCaption(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetection(BuildContext context, ColorScheme colorScheme) {
    final detection = report.providerDetection!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Provider',
            style: AppTypography.getTitle(color: colorScheme.onSurface),
          ),
          AppSpacing.heightXS,
          _labelValue(
            colorScheme,
            'Kind',
            '${detection.providerKind.displayName} '
            '(${(detection.confidence * 100).toStringAsFixed(0)}%)',
          ),
          _labelValue(
            colorScheme,
            'Transport',
            detection.transportKind.displayName,
          ),
          _labelValue(
            colorScheme,
            'Compression',
            detection.compressionKind.displayName,
          ),
          if (detection.matchedSignals.isNotEmpty)
            _labelValue(
              colorScheme,
              'Signals',
              detection.matchedSignals.join(', '),
            ),
        ],
      ),
    );
  }

  Widget _buildCapabilities(BuildContext context, ColorScheme colorScheme) {
    final caps = report.providerCapabilities!;
    final supported = <String>[
      if (caps.supportsLiveTv) 'Live TV',
      if (caps.supportsMovies) 'Movies',
      if (caps.supportsSeries) 'Series',
      if (caps.supportsRadio) 'Radio',
      if (caps.supportsCatchup) 'Catch-up',
      if (caps.supportsTimeshift) 'Timeshift',
      if (caps.supportsEpg) 'EPG',
      if (caps.supportsDownloads) 'Downloads',
      if (caps.supportsBackupStreams) 'Backup streams',
      if (caps.supportsCustomHeaders) 'Custom headers',
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capabilities',
            style: AppTypography.getTitle(color: colorScheme.onSurface),
          ),
          AppSpacing.heightXS,
          _labelValue(
            colorScheme,
            'Supported',
            supported.isEmpty ? 'None detected' : supported.join(', '),
          ),
          if (caps.supportedProtocols.isNotEmpty)
            _labelValue(
              colorScheme,
              'Protocols',
              caps.supportedProtocols.join(', '),
            ),
        ],
      ),
    );
  }

  Widget _buildNegotiated(BuildContext context, ColorScheme colorScheme) {
    final negotiated = report.negotiated!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Negotiated Stream',
            style: AppTypography.getTitle(color: colorScheme.onSurface),
          ),
          AppSpacing.heightXS,
          _labelValue(colorScheme, 'Protocol', negotiated.protocol.displayName),
          _labelValue(
            colorScheme,
            'Player',
            '${negotiated.playerName} '
            '(${negotiated.playerNegotiation.supportLevel.displayName})',
          ),
          if (negotiated.mimeType != null)
            _labelValue(colorScheme, 'MIME', negotiated.mimeType!),
          if (negotiated.playerNegotiation.fallbackEngines.isNotEmpty)
            _labelValue(
              colorScheme,
              'Fallbacks',
              negotiated.playerNegotiation.fallbackEngines.join(', '),
            ),
        ],
      ),
    );
  }

  Widget _labelValue(ColorScheme colorScheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Expanded(
            child: Text(
              value,
              style: AppTypography.getLabel(color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
