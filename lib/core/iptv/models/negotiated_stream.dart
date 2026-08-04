import 'package:flutter/foundation.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/iptv/models/stream_analysis.dart';
import 'package:stream_hub/core/iptv/models/stream_protocol.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';

/// The output of stream negotiation for a resolved [PlayableSession].
///
/// Combines the detected protocol, the negotiated player, negotiated headers,
/// capabilities, fallbacks, and technical analysis. This is what the diagnostics
/// layer and test tools present to the user.
@immutable
class NegotiatedStream {
  final String sourceUrl;
  final StreamProtocol protocol;
  final StreamType streamType;
  final String? mimeType;
  final PlayerNegotiation playerNegotiation;
  final StreamCapabilities capabilities;
  final Map<String, String> headers;
  final Map<String, String> cookies;
  final String? userAgent;
  final String? referer;
  final String? origin;
  final List<String> fallbackUrls;
  final StreamAnalysis? analysis;
  final DateTime? expiresAt;
  final Map<String, dynamic> metadata;

  const NegotiatedStream({
    required this.sourceUrl,
    required this.protocol,
    required this.streamType,
    this.mimeType,
    required this.playerNegotiation,
    this.capabilities = const StreamCapabilities(),
    this.headers = const {},
    this.cookies = const {},
    this.userAgent,
    this.referer,
    this.origin,
    this.fallbackUrls = const [],
    this.analysis,
    this.expiresAt,
    this.metadata = const {},
  });

  bool get isPlayable => playerNegotiation.isPlayable;

  bool get isAdaptive => protocol.isAdaptive;

  String get playerName => playerNegotiation.engine.displayName;
}
