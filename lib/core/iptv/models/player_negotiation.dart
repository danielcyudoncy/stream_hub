import 'package:flutter/foundation.dart';
import 'package:stream_hub/core/iptv/models/stream_protocol.dart';

/// The playback engine family selected during player negotiation.
enum PlaybackEngineKind {
  mediaKit,
  avPlayer,
  exoPlayer,
  nativeActivity,
  vlc,
  ijk,
  fallback,
  none;

  String get displayName {
    switch (this) {
      case PlaybackEngineKind.mediaKit:
        return 'MediaKit';
      case PlaybackEngineKind.avPlayer:
        return 'AVPlayer';
      case PlaybackEngineKind.exoPlayer:
        return 'ExoPlayer';
      case PlaybackEngineKind.nativeActivity:
        return 'Native Player';
      case PlaybackEngineKind.vlc:
        return 'VLC';
      case PlaybackEngineKind.ijk:
        return 'IJK';
      case PlaybackEngineKind.fallback:
        return 'Fallback Player';
      case PlaybackEngineKind.none:
        return 'No Player';
    }
  }
}

/// How well a given engine supports a protocol.
enum PlayerSupportLevel {
  native,
  supported,
  degraded,
  unsupported;

  String get displayName {
    switch (this) {
      case PlayerSupportLevel.native:
        return 'Native';
      case PlayerSupportLevel.supported:
        return 'Supported';
      case PlayerSupportLevel.degraded:
        return 'Degraded';
      case PlayerSupportLevel.unsupported:
        return 'Unsupported';
    }
  }
}

/// The outcome of player negotiation for a detected protocol.
@immutable
class PlayerNegotiation {
  final PlaybackEngineKind engine;
  final PlayerSupportLevel supportLevel;
  final StreamProtocol protocol;
  final String reason;
  final List<String> fallbackEngines;

  const PlayerNegotiation({
    required this.engine,
    required this.supportLevel,
    required this.protocol,
    required this.reason,
    this.fallbackEngines = const [],
  });

  bool get isPlayable => supportLevel != PlayerSupportLevel.unsupported;
}
