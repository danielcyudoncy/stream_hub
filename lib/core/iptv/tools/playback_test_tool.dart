import 'package:stream_hub/core/iptv/analysis/stream_diagnostics_builder.dart';
import 'package:stream_hub/core/iptv/debug/debug_mode_service.dart';
import 'package:stream_hub/core/iptv/detection/provider_capability_analyzer.dart';
import 'package:stream_hub/core/iptv/detection/provider_detector.dart';
import 'package:stream_hub/core/iptv/models/provider_capabilities.dart';
import 'package:stream_hub/core/iptv/models/provider_detection.dart';
import 'package:stream_hub/core/iptv/models/debug_config.dart';
import 'package:stream_hub/core/iptv/models/negotiated_stream.dart';
import 'package:stream_hub/core/iptv/models/stream_diagnostics_report.dart';
import 'package:stream_hub/core/iptv/negotiation/stream_negotiation_engine.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';
import 'package:stream_hub/core/streaming/models/stream_validation_result.dart';
import 'package:stream_hub/core/streaming/network/header_engine.dart';
import 'package:stream_hub/core/streaming/security/sensitive_data_redactor.dart';
import 'package:stream_hub/core/streaming/stream_engine.dart';
import 'package:stream_hub/core/streaming/validation/stream_validator.dart';

/// The result of a playback test.
class PlaybackTestResult {
  final StreamDiagnosticsReport report;
  final PlayableSession? session;
  final ProviderDetectionResult detection;
  final ProviderCapabilities capabilities;

  const PlaybackTestResult({
    required this.report,
    this.session,
    required this.detection,
    required this.capabilities,
  });

  bool get canPlay => report.succeeded && session != null;
}

/// Internal testing tool: paste a stream URL, validate it, display diagnostics,
/// and play. Bypasses UI complexity so streams can be tested in isolation.
class PlaybackTestTool {
  final StreamEngine streamEngine;
  final StreamValidator streamValidator;
  final StreamNegotiationEngine negotiationEngine;
  final ProviderDetector providerDetector;
  final ProviderCapabilityAnalyzer capabilityAnalyzer;
  final StreamDiagnosticsBuilder diagnosticsBuilder;
  final DebugModeService debugMode;
  final LoggingService logger;

  PlaybackTestTool({
    required this.streamEngine,
    required this.streamValidator,
    required this.negotiationEngine,
    ProviderDetector? providerDetector,
    ProviderCapabilityAnalyzer? capabilityAnalyzer,
    StreamDiagnosticsBuilder? diagnosticsBuilder,
    DebugModeService? debugMode,
    LoggingService? logger,
  }) : providerDetector = providerDetector ?? ProviderDetector(),
       capabilityAnalyzer =
           capabilityAnalyzer ?? const ProviderCapabilityAnalyzer(),
       diagnosticsBuilder =
           diagnosticsBuilder ?? const StreamDiagnosticsBuilder(),
       debugMode = debugMode ?? DebugModeService(),
       logger = logger ?? LoggingService();

  /// Tests an arbitrary [url] and returns a full diagnostics report.
  Future<PlaybackTestResult> testUrl(
    String url, {
    Map<String, String>? headers,
    bool validate = true,
    bool withAnalysis = true,
  }) async {
    final startedAt = DateTime.now();
    final steps = <DiagnosticStep>[];
    final errors = <String>[];
    final warnings = <String>[];

    _step(
      steps,
      'Provider Detection',
      'Detecting provider, transport and compression.',
      (elapsed) {},
    );
    final detection = providerDetector.detect(ProviderInput(url: url));
    if (!detection.isKnown) {
      warnings.add('Provider kind could not be determined from the URL.');
    }
    _finishStep(steps);

    _beginStep(steps, 'Provider Capability Analysis');
    final capabilities = capabilityAnalyzer.analyze(detection);
    _finishStep(steps);

    final session = _anonymousSession(url, headers: headers);
    debugMode.log(
      DebugLogCategory.session,
      'Anonymous provider session created for ${session.providerId}',
    );

    PlayableSession? playable;
    StreamValidationResult? validation;
    HttpProbeResult? probe;

    _beginStep(steps, 'Stream Resolution');
    try {
      playable = await streamEngine.resolveStream(
        mediaItemId: 'debug-${_hash(url)}',
        url: url,
        providerSession: session,
        itemMetadata: {'referer': session.referer ?? ''},
      );
      _finishStep(steps, detail: _redact(playable.streamUrl));
    } on Exception catch (e) {
      _finishStep(
        steps,
        status: 'error',
        detail: e.toString(),
      );
      errors.add('Stream resolution failed: $e');
      return _buildResult(
        startedAt,
        url,
        detection,
        capabilities,
        steps,
        errors,
        warnings,
        session: session,
      );
    }

    if (validate) {
      _beginStep(steps, 'Stream Validation');
      validation = await streamValidator.validate(playable);
      probe = _probeFromValidation(validation);
      if (validation.isValid) {
        _finishStep(
          steps,
          detail:
              'HTTP ${validation.statusCode ?? 200} '
              '${validation.contentType ?? ''} in ${validation.latencyMs}ms',
        );
      } else {
        _finishStep(
          steps,
          status: 'error',
          detail: validation.errors.join('; '),
        );
        errors.addAll(validation.errors);
      }
    }

    _beginStep(steps, 'Stream Negotiation');
    try {
      final negotiated = await negotiationEngine.negotiate(
        session: playable,
        providerSession: session,
        probe: probe,
        withAnalysis: withAnalysis,
      );
      _finishStep(
        steps,
        detail:
            '${negotiated.protocol.displayName} → ${negotiated.playerName} '
            '(${negotiated.playerNegotiation.supportLevel.displayName})',
      );

      if (!negotiated.isPlayable) {
        errors.add(
          'No playback engine supports protocol ${negotiated.protocol.displayName}.',
        );
      }
      warnings.addAll(negotiated.playerNegotiation.fallbackEngines.isNotEmpty
          ? [
              'Fallback engines available: ${negotiated.playerNegotiation.fallbackEngines.join(', ')}',
            ]
          : const <String>[]);

      final succeeded = errors.isEmpty && (validation?.isValid ?? true);
      return _buildResult(
        startedAt,
        url,
        detection,
        capabilities,
        steps,
        errors,
        warnings,
        session: session,
        playable: playable,
        validation: validation,
        probe: probe,
        negotiated: negotiated,
        succeeded: succeeded,
      );
    } on Exception catch (e) {
      _finishStep(steps, status: 'error', detail: e.toString());
      errors.add('Stream negotiation failed: $e');
      return _buildResult(
        startedAt,
        url,
        detection,
        capabilities,
        steps,
        errors,
        warnings,
        session: session,
        playable: playable,
        validation: validation,
        probe: probe,
        succeeded: false,
      );
    }
  }

  /// Builds a playable session from an already-produced report (used by the
  /// "Play" button after a successful test).
  Future<PlayableSession> buildPlayableSession(String url) async {
    final session = _anonymousSession(url);
    return streamEngine.resolveStream(
      mediaItemId: 'debug-${_hash(url)}',
      url: url,
      providerSession: session,
    );
  }

  ProviderSession _anonymousSession(
    String url, {
    Map<String, String>? headers,
  }) {
    final origin = Uri.tryParse(url)?.origin;
    return ProviderSession(
      providerId: 'debug-${_hash(url)}',
      providerType: MediaSourceType.m3u,
      sessionId: 'debug-session-${DateTime.now().millisecondsSinceEpoch}',
      baseUrl: origin,
      userAgent: HeaderEngine.kDefaultUserAgent,
      referer: origin,
      headers: headers ?? const {},
      timeout: const Duration(seconds: 15),
    );
  }

  HttpProbeResult? _probeFromValidation(StreamValidationResult? validation) {
    if (validation == null) return null;
    if (validation.statusCode == null && validation.contentType == null) {
      return null;
    }
    return HttpProbeResult(
      statusCode: validation.statusCode ?? 200,
      contentType: validation.contentType,
      finalUri: Uri.tryParse(validation.url ?? '') ?? Uri(),
      latencyMs: validation.latencyMs,
    );
  }

  PlaybackTestResult _buildResult(
    DateTime startedAt,
    String url,
    ProviderDetectionResult detection,
    ProviderCapabilities capabilities,
    List<DiagnosticStep> steps,
    List<String> errors,
    List<String> warnings, {
    ProviderSession? session,
    PlayableSession? playable,
    StreamValidationResult? validation,
    HttpProbeResult? probe,
    NegotiatedStream? negotiated,
    bool succeeded = false,
  }) {
    final report = diagnosticsBuilder.build(
      inputUrl: url,
      providerDetection: detection,
      providerCapabilities: capabilities,
      session: playable,
      providerSession: session,
      negotiated: negotiated,
      validation: validation,
      probe: probe,
      steps: List.unmodifiable(steps),
      extraErrors: errors,
      extraWarnings: warnings,
      startedAt: startedAt,
      completedAt: DateTime.now(),
      succeeded: succeeded,
    );
    return PlaybackTestResult(
      report: report,
      session: playable,
      detection: detection,
      capabilities: capabilities,
    );
  }

  int _hash(String value) {
    var hash = 17;
    for (final code in value.codeUnits) {
      hash = 31 * hash + code;
    }
    return hash & 0x7fffffff;
  }

  String _redact(String value) => SensitiveDataRedactor.redactUrl(value);

  // --- step helpers ---
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

  void _step(
    List<DiagnosticStep> steps,
    String name,
    String message,
    void Function(Duration) onElapsed,
  ) {
    _beginStep(steps, name);
    _finishStep(steps, detail: message);
  }
}
