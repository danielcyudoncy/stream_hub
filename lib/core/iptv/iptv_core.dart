import 'package:stream_hub/core/iptv/analysis/stream_analyzer.dart';
import 'package:stream_hub/core/iptv/analysis/stream_diagnostics_builder.dart';
import 'package:stream_hub/core/iptv/debug/debug_mode_service.dart';
import 'package:stream_hub/core/iptv/detection/provider_capability_analyzer.dart';
import 'package:stream_hub/core/iptv/detection/provider_detector.dart';
import 'package:stream_hub/core/iptv/negotiation/stream_negotiation_engine.dart';
import 'package:stream_hub/core/iptv/playlist/playlist_analyzer.dart';
import 'package:stream_hub/core/iptv/recovery/error_recovery_engine.dart';
import 'package:stream_hub/core/iptv/tools/playback_test_tool.dart';
import 'package:stream_hub/core/iptv/tools/provider_test_tool.dart';
import 'package:stream_hub/core/iptv/tools/stream_test_tool.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/streaming/stream_engine.dart';
import 'package:stream_hub/core/streaming/validation/stream_validator.dart';

/// Facade over the IPTV Core subsystem.
///
/// Exposes provider detection, playlist analysis, stream negotiation, technical
/// analysis, diagnostics, error recovery, developer mode, and the internal test
/// tools. The IPTV Core sits between the existing [StreamEngine] and the
/// Playback Engine; it never touches the UI, the player, or providers directly.
class IptvCore {
  final ProviderDetector providerDetector;
  final ProviderCapabilityAnalyzer capabilityAnalyzer;
  final PlaylistAnalyzer playlistAnalyzer;
  final StreamNegotiationEngine negotiationEngine;
  final StreamAnalyzer streamAnalyzer;
  final StreamDiagnosticsBuilder diagnosticsBuilder;
  final ErrorRecoveryEngine errorRecovery;
  final DebugModeService debugMode;

  final PlaybackTestTool playbackTestTool;
  final ProviderTestTool providerTestTool;
  final StreamTestTool streamTestTool;

  IptvCore({
    required StreamEngine streamEngine,
    required StreamValidator streamValidator,
    LoggingService? logger,
    ProviderDetector? providerDetector,
    ProviderCapabilityAnalyzer? capabilityAnalyzer,
    PlaylistAnalyzer? playlistAnalyzer,
    StreamNegotiationEngine? negotiationEngine,
    StreamAnalyzer? streamAnalyzer,
    StreamDiagnosticsBuilder? diagnosticsBuilder,
    DebugModeService? debugMode,
    ErrorRecoveryEngine? errorRecovery,
  }) : providerDetector = providerDetector ?? ProviderDetector(),
       capabilityAnalyzer =
           capabilityAnalyzer ?? const ProviderCapabilityAnalyzer(),
       playlistAnalyzer = playlistAnalyzer ?? PlaylistAnalyzer(),
       negotiationEngine = negotiationEngine ?? StreamNegotiationEngine(),
       streamAnalyzer = streamAnalyzer ?? const StreamAnalyzer(),
       diagnosticsBuilder =
           diagnosticsBuilder ?? const StreamDiagnosticsBuilder(),
       debugMode = debugMode ?? DebugModeService(logger: logger),
       errorRecovery =
           errorRecovery ??
           ErrorRecoveryEngine(streamEngine: streamEngine, logger: logger),
       playbackTestTool = PlaybackTestTool(
         streamEngine: streamEngine,
         streamValidator: streamValidator,
         negotiationEngine: negotiationEngine ?? StreamNegotiationEngine(),
       ),
       providerTestTool = ProviderTestTool(),
       streamTestTool = StreamTestTool(
         streamEngine: streamEngine,
         streamValidator: streamValidator,
         negotiationEngine: negotiationEngine ?? StreamNegotiationEngine(),
       );
}
