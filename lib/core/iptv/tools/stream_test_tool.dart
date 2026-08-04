import 'package:stream_hub/core/iptv/analysis/stream_diagnostics_builder.dart';
import 'package:stream_hub/core/iptv/debug/debug_mode_service.dart';
import 'package:stream_hub/core/iptv/detection/provider_capability_analyzer.dart';
import 'package:stream_hub/core/iptv/detection/provider_detector.dart';
import 'package:stream_hub/core/iptv/models/negotiated_stream.dart';
import 'package:stream_hub/core/iptv/models/provider_capabilities.dart';
import 'package:stream_hub/core/iptv/models/provider_detection.dart';
import 'package:stream_hub/core/iptv/models/stream_diagnostics_report.dart';
import 'package:stream_hub/core/iptv/negotiation/stream_negotiation_engine.dart';
import 'package:stream_hub/core/iptv/tools/playback_test_tool.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';
import 'package:stream_hub/core/streaming/models/stream_validation_result.dart';
import 'package:stream_hub/core/streaming/security/sensitive_data_redactor.dart';
import 'package:stream_hub/core/streaming/stream_engine.dart';
import 'package:stream_hub/core/streaming/validation/stream_validator.dart';

/// Internal testing tool: takes a stored media item (channel, movie, series
/// episode) and runs it through the full pipeline: session creation, stream
/// resolution, validation, and negotiation — producing the same diagnostics a
/// real playback attempt would, without touching a player.
class StreamTestTool {
  final StreamEngine streamEngine;
  final StreamValidator streamValidator;
  final StreamNegotiationEngine negotiationEngine;
  final ProviderDetector providerDetector;
  final ProviderCapabilityAnalyzer capabilityAnalyzer;
  final StreamDiagnosticsBuilder diagnosticsBuilder;
  final DebugModeService debugMode;
  final LoggingService logger;

  StreamTestTool({
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

  /// Tests a media item through the complete pipeline.
  Future<PlaybackTestResult> testItem({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
    bool validate = true,
    bool withAnalysis = true,
  }) async {
    final startedAt = DateTime.now();
    final steps = <DiagnosticStep>[];
    final errors = <String>[];
    final warnings = <String>[];

    final sourceUrl = _sourceUrl(itemMetadata, fallbackUrl);
    if (sourceUrl == null || sourceUrl.isEmpty) {
      errors.add('Media item has no resolvable stream URL.');
      final detection = providerDetector.detect(const ProviderInput());
      final report = diagnosticsBuilder.build(
        inputUrl: null,
        providerDetection: detection,
        providerCapabilities: capabilityAnalyzer.analyze(detection),
        steps: steps,
        extraErrors: errors,
        extraWarnings: warnings,
        startedAt: startedAt,
        completedAt: DateTime.now(),
        succeeded: false,
      );
      return PlaybackTestResult(
        report: report,
        detection: detection,
        capabilities: capabilityAnalyzer.analyze(detection),
      );
    }

    _beginStep(steps, 'Provider Detection');
    final detection = providerDetector.detect(ProviderInput(url: sourceUrl));
    _finishStep(
      steps,
      detail:
          '${detection.providerKind.displayName} '
          '(confidence ${(detection.confidence * 100).toStringAsFixed(0)}%)',
    );
    warnings.addAll(detection.warnings);

    _beginStep(steps, 'Provider Capability Analysis');
    final capabilities = capabilityAnalyzer.analyze(detection);
    _finishStep(steps);

    ProviderSession providerSession;
    _beginStep(steps, 'Provider Session');
    try {
      providerSession = await streamEngine.sessionManager.getOrCreateSession(
        mediaItemId: mediaItemId,
        providerType: providerType,
        itemMetadata: itemMetadata,
        providerId: providerId,
      );
      _finishStep(
        steps,
        detail: 'Session ${providerSession.sessionId} '
            '(${providerSession.providerType.displayName})',
      );
    } on Exception catch (e) {
      _finishStep(steps, status: 'error', detail: e.toString());
      errors.add('Provider session creation failed: $e');
      return _finalResult(
        startedAt,
        sourceUrl,
        detection,
        capabilities,
        steps,
        errors,
        warnings,
      );
    }

    PlayableSession? playable;
    _beginStep(steps, 'Stream Resolution');
    try {
      playable = await streamEngine.resolvePlayback(
        mediaItemId: mediaItemId,
        providerType: providerType,
        itemMetadata: itemMetadata,
        providerId: providerId,
        fallbackUrl: fallbackUrl,
        validate: false,
      );
      _finishStep(
        steps,
        detail: '${playable.streamType.displayName} · ${_redact(playable.streamUrl)}',
      );
    } on Exception catch (e) {
      _finishStep(steps, status: 'error', detail: e.toString());
      errors.add('Stream resolution failed: $e');
      return _finalResult(
        startedAt,
        sourceUrl,
        detection,
        capabilities,
        steps,
        errors,
        warnings,
        providerSession: providerSession,
      );
    }

    StreamValidationResult? validation;
    HttpProbeResult? probe;
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
        _finishStep(steps, status: 'error', detail: validation.errors.join('; '));
        errors.addAll(validation.errors);
      }
    }

    _beginStep(steps, 'Stream Negotiation');
    try {
      final negotiated = await negotiationEngine.negotiate(
        session: playable,
        providerSession: providerSession,
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
              'Fallback engines: ${negotiated.playerNegotiation.fallbackEngines.join(', ')}',
            ]
          : const <String>[]);

      final succeeded = errors.isEmpty && (validation?.isValid ?? true);
      return _finalResult(
        startedAt,
        sourceUrl,
        detection,
        capabilities,
        steps,
        errors,
        warnings,
        providerSession: providerSession,
        playable: playable,
        validation: validation,
        probe: probe,
        negotiated: negotiated,
        succeeded: succeeded,
      );
    } on Exception catch (e) {
      _finishStep(steps, status: 'error', detail: e.toString());
      errors.add('Stream negotiation failed: $e');
      return _finalResult(
        startedAt,
        sourceUrl,
        detection,
        capabilities,
        steps,
        errors,
        warnings,
        providerSession: providerSession,
        playable: playable,
        validation: validation,
        probe: probe,
      );
    }
  }

  PlaybackTestResult _finalResult(
    DateTime startedAt,
    String sourceUrl,
    ProviderDetectionResult detection,
    ProviderCapabilities capabilities,
    List<DiagnosticStep> steps,
    List<String> errors,
    List<String> warnings, {
    ProviderSession? providerSession,
    PlayableSession? playable,
    StreamValidationResult? validation,
    HttpProbeResult? probe,
    NegotiatedStream? negotiated,
    bool succeeded = false,
  }) {
    final report = diagnosticsBuilder.build(
      inputUrl: sourceUrl,
      providerDetection: detection,
      providerCapabilities: capabilities,
      session: playable,
      providerSession: providerSession,
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

  String? _sourceUrl(Map<String, dynamic> itemMetadata, String? fallbackUrl) {
    return itemMetadata['streamUrl']?.toString() ??
        itemMetadata['stream_url']?.toString() ??
        itemMetadata['url']?.toString() ??
        fallbackUrl;
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

  String _redact(String value) => SensitiveDataRedactor.redactUrl(value);

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
