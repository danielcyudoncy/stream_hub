import 'package:stream_hub/core/iptv/analysis/stream_analyzer.dart';
import 'package:stream_hub/core/iptv/models/negotiated_stream.dart';
import 'package:stream_hub/core/iptv/negotiation/capability_detector.dart';
import 'package:stream_hub/core/iptv/negotiation/header_negotiator.dart';
import 'package:stream_hub/core/iptv/negotiation/player_negotiator.dart';
import 'package:stream_hub/core/iptv/negotiation/protocol_detector.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';

/// Orchestrates stream negotiation for a resolved [PlayableSession]:
///
/// Protocol Detection → Capability Detection → Player Negotiation →
/// Header Negotiation → Stream Analysis → [NegotiatedStream]
///
/// The negotiation layer never touches the player or the provider directly.
class StreamNegotiationEngine {
  final ProtocolDetector protocolDetector;
  final CapabilityDetector capabilityDetector;
  final PlayerNegotiator playerNegotiator;
  final HeaderNegotiator headerNegotiator;
  final StreamAnalyzer streamAnalyzer;

  StreamNegotiationEngine({
    ProtocolDetector? protocolDetector,
    CapabilityDetector? capabilityDetector,
    PlayerNegotiator? playerNegotiator,
    HeaderNegotiator? headerNegotiator,
    StreamAnalyzer? streamAnalyzer,
  }) : protocolDetector = protocolDetector ?? const ProtocolDetector(),
       capabilityDetector = capabilityDetector ?? const CapabilityDetector(),
       playerNegotiator = playerNegotiator ?? const PlayerNegotiator(),
       headerNegotiator = headerNegotiator ?? HeaderNegotiator(),
       streamAnalyzer = streamAnalyzer ?? const StreamAnalyzer();

  /// Negotiates a [PlayableSession] into a [NegotiatedStream].
  Future<NegotiatedStream> negotiate({
    required PlayableSession session,
    ProviderSession? providerSession,
    Map<String, dynamic> metadata = const {},
    HttpProbeResult? probe,
    bool withAnalysis = true,
  }) async {
    final initialProtocol = protocolDetector.fromUrl(
      session.streamUrl,
      streamType: session.streamType,
    );
    final protocolDetection = protocolDetector.refine(
      initialProtocol,
      mimeType: session.mimeType,
      probe: probe,
    );
    final protocol = protocolDetection.protocol;

    final streamType =
        session.streamType == StreamType.unknown
            ? protocol.toStreamType()
            : session.streamType;

    final metadataForDetection = metadata.isNotEmpty
        ? metadata
        : (session.metadata['iptv'] is Map
              ? session.metadata['iptv'] as Map<String, dynamic>
              : session.metadata);

    final detectedCapabilities = capabilityDetector.detect(
      protocol,
      metadata: metadataForDetection,
    );
    final capabilities = _mergeCapabilities(session, detectedCapabilities);
    final player = playerNegotiator.negotiate(protocol);

    final headers = providerSession != null
        ? headerNegotiator.negotiate(
            providerSession,
            metadata: metadataForDetection,
            includeAuth: true,
          )
        : Map<String, String>.from(session.headers);

    final analysis = withAnalysis
        ? await streamAnalyzer.analyze(session, probe: probe)
        : null;

    return NegotiatedStream(
      sourceUrl: session.streamUrl,
      protocol: protocol,
      streamType: streamType,
      mimeType: session.mimeType,
      playerNegotiation: player,
      capabilities: capabilities,
      headers: headers,
      cookies: Map<String, String>.from(session.cookies),
      userAgent: session.userAgent,
      referer: session.referer,
      origin: session.origin,
      fallbackUrls: _extractBackupUrls(session),
      analysis: analysis,
      expiresAt: session.expiresAt,
      metadata: metadataForDetection,
    );
  }

  /// The PlayableSession's explicit flags are authoritative where they are more
  /// restrictive than the protocol-derived defaults.
  StreamCapabilities _mergeCapabilities(
    PlayableSession session,
    StreamCapabilities detected,
  ) {
    return StreamCapabilities(
      supportsSeeking: detected.supportsSeeking,
      supportsPause: session.supportsPause && detected.supportsPause,
      supportsRecording:
          session.supportsRecording && detected.supportsRecording,
      supportsDownload: session.supportsDownload && detected.supportsDownload,
      supportsCatchup: detected.supportsCatchup,
      supportsTimeshift: detected.supportsTimeshift,
      supportsSubtitles: detected.supportsSubtitles,
      supportsAudioTracks: detected.supportsAudioTracks,
      supportsQualitySelection: detected.supportsQualitySelection,
      supportsResume: detected.supportsResume,
    );
  }

  List<String> _extractBackupUrls(PlayableSession session) {
    final raw = session.metadata['backupUrls'];
    if (raw is List) return raw.whereType<String>().toList();
    return const [];
  }
}
