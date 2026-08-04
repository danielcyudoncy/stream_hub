import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/iptv/models/stream_protocol.dart';

/// Negotiates the best playback engine for a detected protocol.
///
/// Architecture only: the negotiator does not instantiate players. It returns
/// an ordered preference so the Playback Engine can select (or fall back to)
/// the most appropriate [PlaybackEngineKind].
class PlayerNegotiator {
  const PlayerNegotiator();

  /// Returns the preferred playback engine for [protocol].
  PlayerNegotiation negotiate(StreamProtocol protocol) {
    switch (protocol) {
      case StreamProtocol.hls:
        return const PlayerNegotiation(
          engine: PlaybackEngineKind.mediaKit,
          supportLevel: PlayerSupportLevel.native,
          protocol: StreamProtocol.hls,
          reason: 'HLS is natively supported by MediaKit (libmpv/ffmpeg).',
        );
      case StreamProtocol.mpegTs:
        return const PlayerNegotiation(
          engine: PlaybackEngineKind.mediaKit,
          supportLevel: PlayerSupportLevel.supported,
          protocol: StreamProtocol.mpegTs,
          reason: 'MPEG-TS is supported by MediaKit through ffmpeg demuxing.',
        );
      case StreamProtocol.dash:
        return const PlayerNegotiation(
          engine: PlaybackEngineKind.mediaKit,
          supportLevel: PlayerSupportLevel.supported,
          protocol: StreamProtocol.dash,
          reason: 'DASH is supported by MediaKit when ffmpeg has dash enabled.',
        );
      case StreamProtocol.mp4:
        return const PlayerNegotiation(
          engine: PlaybackEngineKind.mediaKit,
          supportLevel: PlayerSupportLevel.native,
          protocol: StreamProtocol.mp4,
          reason: 'MP4 is natively supported by MediaKit.',
        );
      case StreamProtocol.mkv:
        return const PlayerNegotiation(
          engine: PlaybackEngineKind.mediaKit,
          supportLevel: PlayerSupportLevel.supported,
          protocol: StreamProtocol.mkv,
          reason: 'MKV is supported by MediaKit through Matroska demuxing.',
        );
      case StreamProtocol.http:
      case StreamProtocol.https:
        return const PlayerNegotiation(
          engine: PlaybackEngineKind.mediaKit,
          supportLevel: PlayerSupportLevel.supported,
          protocol: StreamProtocol.http,
          reason: 'Progressive HTTP(S) playback is supported by MediaKit.',
        );
      case StreamProtocol.rtsp:
        return PlayerNegotiation(
          engine: PlaybackEngineKind.mediaKit,
          supportLevel: PlayerSupportLevel.degraded,
          protocol: StreamProtocol.rtsp,
          reason: 'RTSP requires ffmpeg network support; may be degraded.',
          fallbackEngines: [PlaybackEngineKind.vlc.displayName],
        );
      case StreamProtocol.rtmp:
      case StreamProtocol.rtmps:
        return PlayerNegotiation(
          engine: PlaybackEngineKind.fallback,
          supportLevel: PlayerSupportLevel.degraded,
          protocol: StreamProtocol.rtmp,
          reason:
              'RTMP is not reliably available in MediaKit builds; prefer a '
              'fallback player (VLC) that bundles librtmp.',
          fallbackEngines: [
            PlaybackEngineKind.vlc.displayName,
            PlaybackEngineKind.mediaKit.displayName,
          ],
        );
      case StreamProtocol.udp:
      case StreamProtocol.rtp:
        return PlayerNegotiation(
          engine: PlaybackEngineKind.mediaKit,
          supportLevel: PlayerSupportLevel.degraded,
          protocol: StreamProtocol.udp,
          reason:
              'UDP/RTP multicast requires ffmpeg UDP demuxing and network '
              'multicast permissions; may be degraded.',
          fallbackEngines: [PlaybackEngineKind.vlc.displayName],
        );
      case StreamProtocol.unknown:
        return const PlayerNegotiation(
          engine: PlaybackEngineKind.fallback,
          supportLevel: PlayerSupportLevel.unsupported,
          protocol: StreamProtocol.unknown,
          reason: 'Protocol could not be determined; cannot pick a player.',
        );
    }
  }
}
