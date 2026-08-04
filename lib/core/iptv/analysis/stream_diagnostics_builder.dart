import 'package:stream_hub/core/iptv/models/negotiated_stream.dart';
import 'package:stream_hub/core/iptv/models/playlist_analysis.dart';
import 'package:stream_hub/core/iptv/models/provider_capabilities.dart';
import 'package:stream_hub/core/iptv/models/provider_detection.dart';
import 'package:stream_hub/core/iptv/models/stream_diagnostics_report.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';
import 'package:stream_hub/core/streaming/models/stream_validation_result.dart';
import 'package:stream_hub/core/streaming/security/sensitive_data_redactor.dart';

/// Builds a [StreamDiagnosticsReport] from every subsystem that contributed to
/// a playback attempt.
///
/// Sensitive values (URLs, headers, cookies) are redacted before they are
/// stored in the report so it can be displayed safely.
class StreamDiagnosticsBuilder {
  const StreamDiagnosticsBuilder();

  StreamDiagnosticsReport build({
    String? inputUrl,
    ProviderDetectionResult? providerDetection,
    ProviderCapabilities? providerCapabilities,
    PlaylistAnalysis? playlistAnalysis,
    PlayableSession? session,
    ProviderSession? providerSession,
    NegotiatedStream? negotiated,
    StreamValidationResult? validation,
    HttpProbeResult? probe,
    List<DiagnosticStep> steps = const [],
    List<String> extraErrors = const [],
    List<String> extraWarnings = const [],
    required DateTime startedAt,
    required DateTime completedAt,
    bool succeeded = false,
  }) {
    final reportId =
        'diag_${DateTime.now().millisecondsSinceEpoch}_${startedAt.microsecondsSinceEpoch}';

    final errors = <String>[
      ...extraErrors,
      if (validation != null && !validation.isValid) ...validation.errors,
    ];
    final warnings = <String>[
      ...extraWarnings,
      if (validation != null) ...validation.warnings,
      ...providerDetection?.warnings ?? const <String>[],
      ...playlistAnalysis?.warnings ?? const <String>[],
    ];

    return StreamDiagnosticsReport(
      reportId: reportId,
      inputUrl: _safeUrl(inputUrl),
      providerDetection: providerDetection,
      providerCapabilities: providerCapabilities,
      playlistAnalysis: playlistAnalysis,
      resolvedUrl: _safeUrl(negotiated?.sourceUrl),
      sessionId: session?.sessionId,
      providerId: providerSession?.providerId ?? session?.providerId,
      providerTypeName:
          providerSession?.providerType.name ?? session?.providerType.name,
      streamUrl: session != null
          ? SensitiveDataRedactor.redactUrl(session.streamUrl)
          : null,
      streamType: session?.streamType,
      protocol: negotiated?.protocol,
      mimeType: negotiated?.mimeType,
      headers: negotiated != null
          ? SensitiveDataRedactor.redactHeaders(negotiated.headers)
          : null,
      cookies: negotiated != null
          ? _redactCookies(negotiated.cookies)
          : null,
      player: negotiated?.playerNegotiation,
      capabilities: negotiated?.capabilities,
      validation: validation,
      probe: probe,
      analysis: negotiated?.analysis,
      negotiated: negotiated,
      steps: steps,
      errors: errors,
      warnings: warnings,
      totalDuration: completedAt.difference(startedAt),
      startedAt: startedAt,
      completedAt: completedAt,
      succeeded: succeeded,
    );
  }

  String? _safeUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return SensitiveDataRedactor.redactUrl(url);
  }

  Map<String, String> _redactCookies(Map<String, String> cookies) {
    return cookies.map((key, value) => MapEntry(key, '[REDACTED]'));
  }
}
