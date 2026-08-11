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
/// two should stay consistent. The Native Player (fullscreen Android Activity)
/// is the protocol-native engine for HTTP adaptive streams (HLS/MPEG-TS) on
/// Android because it renders through a plain TextureView composited by
/// the Android view system, which is the only render path that displays video on
/// Unisoc/Mali devices (docs/PLAYBACK_ENGINEERING.md §1.1 and §8.3).
class PlayerNegotiator {
  const PlayerNegotiator();

  /// Returns the preferred playback engine for [protocol].
  PlayerNegotiation negotiate(StreamProtocol protocol) {
    switch (protocol) {
      case StreamProtocol.hls:
        return PlayerNegotiation(
          engine: PlaybackEngineKind.nativeActivity,
          supportLevel: PlayerSupportLevel.native,
          protocol: StreamProtocol.hls,
          reason:
              'HLS is played by the native Android Activity (ExoPlayer + '
              'TextureView), bypassing Flutter '
              'compositing which black-screens on Unisoc/Mali devices.',
          fallbackEngines: [
            PlaybackEngineKind.exoPlayer.name,
            PlaybackEngineKind.vlc.name,
            PlaybackEngineKind.mediaKit.name,
          ],
        );
      case StreamProtocol.mpegTs:
        return PlayerNegotiation(
          engine: PlaybackEngineKind.nativeActivity,
          supportLevel: PlayerSupportLevel.native,
          protocol: StreamProtocol.mpegTs,
          reason:
              'MPEG-TS live relays are handled by the native Android Activity '
              '(ExoPlayer progressive extractor + TextureView) for reliable '
              'video output on devices where Flutter compositing is broken.',
          fallbackEngines: [
            PlaybackEngineKind.exoPlayer.name,
            PlaybackEngineKind.vlc.name,
            PlaybackEngineKind.mediaKit.name,
          ],
        );
      case StreamProtocol.dash:
        return PlayerNegotiation(
          engine: PlaybackEngineKind.mediaKit,
          supportLevel: PlayerSupportLevel.supported,
          protocol: StreamProtocol.dash,
          reason: 'DASH is supported by MediaKit when ffmpeg has dash enabled.',
          fallbackEngines: [PlaybackEngineKind.exoPlayer.name],
        );
      case StreamProtocol.mp4:
        return PlayerNegotiation(
          engine: PlaybackEngineKind.mediaKit,
          supportLevel: PlayerSupportLevel.native,
          protocol: StreamProtocol.mp4,
          reason: 'MP4 is natively supported by MediaKit.',
          fallbackEngines: [PlaybackEngineKind.exoPlayer.name],
        );
      case StreamProtocol.mkv:
        return PlayerNegotiation(
          engine: PlaybackEngineKind.mediaKit,
          supportLevel: PlayerSupportLevel.supported,
          protocol: StreamProtocol.mkv,
          reason: 'MKV is supported by MediaKit through Matroska demuxing.',
          fallbackEngines: [PlaybackEngineKind.exoPlayer.name],
        );
      case StreamProtocol.http:
      case StreamProtocol.https:
        return PlayerNegotiation(
          engine: PlaybackEngineKind.mediaKit,
          supportLevel: PlayerSupportLevel.supported,
          protocol: StreamProtocol.http,
          reason:
              'Progressive HTTP(S) playback is supported by MediaKit; live '
              'HTTP relays prefer the Native Player/VLC (see '
              'PlayerSelectionStrategy).',
          fallbackEngines: [
            PlaybackEngineKind.nativeActivity.name,
            PlaybackEngineKind.exoPlayer.name,
            PlaybackEngineKind.vlc.name,
          ],
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
