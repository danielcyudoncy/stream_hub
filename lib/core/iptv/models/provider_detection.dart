import 'package:flutter/foundation.dart';

/// The broad category of an IPTV source.
enum DetectedProviderKind {
  m3u,
  xtream,
  stalker,
  xmltv,
  local,
  unknown;

  String get displayName {
    switch (this) {
      case DetectedProviderKind.m3u:
        return 'M3U Playlist';
      case DetectedProviderKind.xtream:
        return 'Xtream Codes';
      case DetectedProviderKind.stalker:
        return 'Stalker Portal';
      case DetectedProviderKind.xmltv:
        return 'XMLTV Guide';
      case DetectedProviderKind.local:
        return 'Local Playlist';
      case DetectedProviderKind.unknown:
        return 'Unknown';
    }
  }
}

/// How the provider content is transported to the device.
enum SourceTransportKind {
  remoteHttp,
  remoteHttps,
  localFile,
  inlineContent;

  String get displayName {
    switch (this) {
      case SourceTransportKind.remoteHttp:
        return 'Remote HTTP';
      case SourceTransportKind.remoteHttps:
        return 'Remote HTTPS';
      case SourceTransportKind.localFile:
        return 'Local File';
      case SourceTransportKind.inlineContent:
        return 'Inline Content';
    }
  }
}

/// Optional compression wrapping of a provider payload.
enum SourceCompressionKind {
  none,
  zip,
  gzip;

  String get displayName {
    switch (this) {
      case SourceCompressionKind.none:
        return 'None';
      case SourceCompressionKind.zip:
        return 'ZIP';
      case SourceCompressionKind.gzip:
        return 'GZIP';
    }
  }
}

/// The result of the [ProviderDetector].
///
/// Combines provider kind, transport, compression, and the evidence (signals)
/// that drove the decision so it can be shown on diagnostics screens.
@immutable
class ProviderDetectionResult {
  final DetectedProviderKind providerKind;
  final SourceTransportKind transportKind;
  final SourceCompressionKind compressionKind;

  /// Confidence in [providerKind] (0.0 – 1.0).
  final double confidence;

  /// The signals that matched, in the order they were evaluated.
  final List<String> matchedSignals;

  /// Warnings raised during detection (e.g. ambiguous input).
  final List<String> warnings;

  /// The raw input that was inspected (redacted externally when sensitive).
  final String? inspectedSource;

  /// Normalized candidate source URL, when one could be derived.
  final String? sourceUrl;

  const ProviderDetectionResult({
    required this.providerKind,
    required this.transportKind,
    required this.compressionKind,
    this.confidence = 0.0,
    this.matchedSignals = const [],
    this.warnings = const [],
    this.inspectedSource,
    this.sourceUrl,
  });

  bool get isKnown => providerKind != DetectedProviderKind.unknown;

  /// Whether credentials are generally expected for this provider kind.
  bool get likelyRequiresCredentials {
    switch (providerKind) {
      case DetectedProviderKind.xtream:
      case DetectedProviderKind.stalker:
        return true;
      case DetectedProviderKind.m3u:
      case DetectedProviderKind.local:
      case DetectedProviderKind.xmltv:
      case DetectedProviderKind.unknown:
        return false;
    }
  }

  ProviderDetectionResult copyWith({
    DetectedProviderKind? providerKind,
    SourceTransportKind? transportKind,
    SourceCompressionKind? compressionKind,
    double? confidence,
    List<String>? matchedSignals,
    List<String>? warnings,
    String? inspectedSource,
    String? sourceUrl,
  }) {
    return ProviderDetectionResult(
      providerKind: providerKind ?? this.providerKind,
      transportKind: transportKind ?? this.transportKind,
      compressionKind: compressionKind ?? this.compressionKind,
      confidence: confidence ?? this.confidence,
      matchedSignals: matchedSignals ?? this.matchedSignals,
      warnings: warnings ?? this.warnings,
      inspectedSource: inspectedSource ?? this.inspectedSource,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }
}
