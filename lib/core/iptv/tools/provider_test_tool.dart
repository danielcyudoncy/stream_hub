import 'package:stream_hub/core/iptv/analysis/stream_diagnostics_builder.dart';
import 'package:stream_hub/core/iptv/detection/provider_capability_analyzer.dart';
import 'package:stream_hub/core/iptv/detection/provider_detector.dart';
import 'package:stream_hub/core/iptv/models/playlist_analysis.dart';
import 'package:stream_hub/core/iptv/models/provider_capabilities.dart';
import 'package:stream_hub/core/iptv/models/provider_detection.dart';
import 'package:stream_hub/core/iptv/models/stream_diagnostics_report.dart';
import 'package:stream_hub/core/iptv/playlist/playlist_analyzer.dart';

/// The result of a provider source test.
class ProviderTestResult {
  final StreamDiagnosticsReport report;
  final ProviderDetectionResult detection;
  final ProviderCapabilities capabilities;
  final PlaylistAnalysis? playlist;

  const ProviderTestResult({
    required this.report,
    required this.detection,
    required this.capabilities,
    this.playlist,
  });

  bool get isKnown => detection.isKnown;

  String? get title {
    if (detection.isKnown) return detection.providerKind.displayName;
    return null;
  }
}

/// Internal testing tool: paste a playlist URL or content, detect the provider
/// kind, analyze capabilities, and — for M3U — extract the full playlist
/// statistics. Used by the developer provider test screen.
class ProviderTestTool {
  final ProviderDetector providerDetector;
  final ProviderCapabilityAnalyzer capabilityAnalyzer;
  final PlaylistAnalyzer playlistAnalyzer;
  final StreamDiagnosticsBuilder diagnosticsBuilder;

  ProviderTestTool({
    ProviderDetector? providerDetector,
    ProviderCapabilityAnalyzer? capabilityAnalyzer,
    PlaylistAnalyzer? playlistAnalyzer,
    StreamDiagnosticsBuilder? diagnosticsBuilder,
  }) : providerDetector = providerDetector ?? ProviderDetector(),
       capabilityAnalyzer =
           capabilityAnalyzer ?? const ProviderCapabilityAnalyzer(),
       playlistAnalyzer = playlistAnalyzer ?? PlaylistAnalyzer(),
       diagnosticsBuilder =
           diagnosticsBuilder ?? const StreamDiagnosticsBuilder();

  /// Analyzes a provider source given a [url] and/or inline [content].
  Future<ProviderTestResult> analyze({
    String? url,
    String? content,
    bool analyzePlaylist = true,
  }) async {
    final startedAt = DateTime.now();
    final steps = <DiagnosticStep>[];
    final errors = <String>[];
    final warnings = <String>[];

    _beginStep(steps, 'Provider Detection');
    final detection = providerDetector.detect(
      ProviderInput(url: url, content: content),
    );
    _finishStep(
      steps,
      detail:
          '${detection.providerKind.displayName} '
          '(confidence ${(detection.confidence * 100).toStringAsFixed(0)}%, '
          '${detection.transportKind.displayName})',
    );
    if (!detection.isKnown) {
      warnings.add('Provider kind could not be determined from the input.');
    }
    warnings.addAll(detection.warnings);

    _beginStep(steps, 'Provider Capability Analysis');
    final capabilities = capabilityAnalyzer.analyze(detection);
    _finishStep(
      steps,
      detail: _summarizeCapabilities(capabilities),
    );

    PlaylistAnalysis? playlist;
    final looksLikePlaylist =
        content != null &&
        content.trim().isNotEmpty &&
        (detection.providerKind == DetectedProviderKind.m3u ||
            detection.providerKind == DetectedProviderKind.local ||
            detection.providerKind == DetectedProviderKind.unknown);

    if (analyzePlaylist && looksLikePlaylist) {
      _beginStep(steps, 'Playlist Analysis');
      playlist = playlistAnalyzer.analyze(
        content,
        sourceUrl: url,
        providerKind: detection.providerKind,
      );
      _finishStep(
        steps,
        detail: playlist.errors.isNotEmpty
            ? '${playlist.errors.length} error(s) found'
            : '${playlist.stats.totalEntries} entries in '
                  '${playlist.stats.analysisDuration.inMilliseconds}ms',
      );
      errors.addAll(playlist.errors);
      warnings.addAll(playlist.warnings);
    }

    final report = diagnosticsBuilder.build(
      inputUrl: url,
      providerDetection: detection,
      providerCapabilities: capabilities,
      playlistAnalysis: playlist,
      steps: List.unmodifiable(steps),
      extraErrors: errors,
      extraWarnings: warnings,
      startedAt: startedAt,
      completedAt: DateTime.now(),
      succeeded: errors.isEmpty,
    );

    return ProviderTestResult(
      report: report,
      detection: detection,
      capabilities: capabilities,
      playlist: playlist,
    );
  }

  String _summarizeCapabilities(ProviderCapabilities capabilities) {
    final supported = <String>[
      if (capabilities.supportsLiveTv) 'Live TV',
      if (capabilities.supportsMovies) 'VOD',
      if (capabilities.supportsSeries) 'Series',
      if (capabilities.supportsRadio) 'Radio',
      if (capabilities.supportsCatchup) 'Catch-up',
      if (capabilities.supportsTimeshift) 'Timeshift',
      if (capabilities.supportsEpg) 'EPG',
    ];
    return supported.isEmpty ? 'No known capabilities' : supported.join(', ');
  }

  void _beginStep(List<DiagnosticStep> steps, String name) {
    steps.add(
      DiagnosticStep(
        name: name,
        status: 'running',
        timestamp: DateTime.now(),
      ),
    );
  }

  void _finishStep(
    List<DiagnosticStep> steps, {
    String status = 'ok',
    String? detail,
  }) {
    if (steps.isEmpty) return;
    final last = steps.removeLast();
    steps.add(
      DiagnosticStep(
        name: last.name,
        status: status,
        detail: detail,
        duration: DateTime.now().difference(last.timestamp),
        timestamp: last.timestamp,
      ),
    );
  }
}
