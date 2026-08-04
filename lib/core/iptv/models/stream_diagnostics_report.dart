import 'package:flutter/foundation.dart';
import 'package:stream_hub/core/iptv/models/negotiated_stream.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/iptv/models/playlist_analysis.dart';
import 'package:stream_hub/core/iptv/models/provider_capabilities.dart';
import 'package:stream_hub/core/iptv/models/provider_detection.dart';
import 'package:stream_hub/core/iptv/models/stream_analysis.dart';
import 'package:stream_hub/core/iptv/models/stream_protocol.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';
import 'package:stream_hub/core/streaming/models/stream_validation_result.dart';

/// A single step recorded during diagnostics.
@immutable
class DiagnosticStep {
  final String name;
  final String status;
  final String? detail;
  final Duration duration;
  final DateTime timestamp;

  const DiagnosticStep({
    required this.name,
    required this.status,
    this.detail,
    this.duration = Duration.zero,
    required this.timestamp,
  });

  bool get isError => status == 'error';
  bool get isWarning => status == 'warning';
}

/// A complete, human-readable report explaining why a stream can or cannot
/// play. Every playback failure should be traceable to authentication, headers,
/// URL, timeout, protocol, codec, provider, player, or network.
@immutable
class StreamDiagnosticsReport {
  final String reportId;
  final String? inputUrl;
  final ProviderDetectionResult? providerDetection;
  final ProviderCapabilities? providerCapabilities;
  final PlaylistAnalysis? playlistAnalysis;
  final String? resolvedUrl;
  final String? sessionId;
  final String? providerId;
  final String? providerTypeName;
  final String? streamUrl;
  final StreamType? streamType;
  final StreamProtocol? protocol;
  final String? mimeType;
  final Map<String, String>? headers;
  final Map<String, String>? cookies;
  final PlayerNegotiation? player;
  final StreamCapabilities? capabilities;
  final StreamValidationResult? validation;
  final HttpProbeResult? probe;
  final StreamAnalysis? analysis;
  final NegotiatedStream? negotiated;
  final List<DiagnosticStep> steps;
  final List<String> errors;
  final List<String> warnings;
  final Duration totalDuration;
  final DateTime startedAt;
  final DateTime completedAt;
  final bool succeeded;

  const StreamDiagnosticsReport({
    required this.reportId,
    this.inputUrl,
    this.providerDetection,
    this.providerCapabilities,
    this.playlistAnalysis,
    this.resolvedUrl,
    this.sessionId,
    this.providerId,
    this.providerTypeName,
    this.streamUrl,
    this.streamType,
    this.protocol,
    this.mimeType,
    this.headers,
    this.cookies,
    this.player,
    this.capabilities,
    this.validation,
    this.probe,
    this.analysis,
    this.negotiated,
    this.steps = const [],
    this.errors = const [],
    this.warnings = const [],
    this.totalDuration = Duration.zero,
    required this.startedAt,
    required this.completedAt,
    this.succeeded = false,
  });

  /// The most likely root cause category of a failure.
  String? get rootCause {
    for (final error in errors) {
      final lower = error.toLowerCase();
      if (lower.contains('401') ||
          lower.contains('403') ||
          lower.contains('auth')) {
        return 'Authentication';
      }
      if (lower.contains('header') || lower.contains('cookie')) {
        return 'Headers';
      }
      if (lower.contains('404') || lower.contains('not found')) {
        return 'URL';
      }
      if (lower.contains('timeout')) return 'Timeout';
      if (lower.contains('protocol') ||
          lower.contains('unsupported') ||
          lower.contains('codec')) {
        return 'Protocol';
      }
      if (lower.contains('player')) return 'Player';
      if (lower.contains('provider') || lower.contains('session')) {
        return 'Provider';
      }
      if (lower.contains('network') ||
          lower.contains('socket') ||
          lower.contains('unreachable')) {
        return 'Network';
      }
    }
    return null;
  }
}
