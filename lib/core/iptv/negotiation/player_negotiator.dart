import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/iptv/models/stream_protocol.dart';

/// Negotiates the best playback engine for a detected protocol.
///
/// Architecture only: the negotiator does not instantiate players. It returns
/// an ordered preference so the Playback Engine can select (or fall back to)
/// the most appropriate [PlaybackEngineKind].
///
/// Note: the negotiator is protocol-only. The live-versus-VOD nuance is applied
/// by the [PlayerSelectionStrategy] which also receives the media type, so the
/// two should stay consistent.
class PlayerNegotiator {
  const PlayerNegotiator();

  /// Returns the preferred playback engine for [protocol].
  PlayerNegotiation negotiate(StreamProtocol protocol) {
    switch (protocol) {
      case StreamProtocol.hls:
        return PlayerNegotiation(
          engine: PlaybackEngineKind.vlc,
          supportLevel: PlayerSupportLevel.supported,
          protocol: StreamProtocol.hls,
          reason:
              'HLS live playback prefers VLC for resilient video output on '
              'devices where MediaKit shows black video after buffering.',
          fallbackEngines: [PlaybackEngineKind.mediaKit.name],
        );
      case StreamProtocol.mpegTs:
        return PlayerNegotiation(
          engine: PlaybackEngineKind.vlc,
          supportLevel: PlayerSupportLevel.supported,
          protocol: StreamProtocol.mpegTs,
          reason:
              'MPEG-TS live relays prefer VLC, which handles unbounded TS '
              'feeds without the media_kit demuxer cache stalls.',
          fallbackEngines: [PlaybackEngineKind.mediaKit.name],
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
          reason:
              'Progressive HTTP(S) playback is supported by MediaKit; live '
              'HTTP relays may prefer VLC (see PlayerSelectionStrategy).',
        );
      case StreamProtocol.rtsp:
        return PlayerNegotiation(
          engine: PlaybackEngineKind.vlc,
          supportLevel: PlayerSupportLevel.supported,
          protocol: StreamProtocol.rtsp,
          reason: 'RTSP is natively supported by VLC (rtsp:// + RTP-over-TCP).',
          fallbackEngines: [PlaybackEngineKind.mediaKit.name],
        );
      case StreamProtocol.rtmp:
      case StreamProtocol.rtmps:
        return PlayerNegotiation(
          engine: PlaybackEngineKind.vlc,
          supportLevel: PlayerSupportLevel.supported,
          protocol: StreamProtocol.rtmp,
          reason: 'RTMP is supported by VLC, which bundles librtmp.',
          fallbackEngines: [PlaybackEngineKind.mediaKit.name],
        );
      case StreamProtocol.udp:
      case StreamProtocol.rtp:
        return PlayerNegotiation(
          engine: PlaybackEngineKind.vlc,
          supportLevel: PlayerSupportLevel.supported,
          protocol: StreamProtocol.udp,
          reason: 'UDP/RTP multicast is natively supported by VLC.',
          fallbackEngines: [PlaybackEngineKind.mediaKit.name],
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
