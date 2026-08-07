import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/iptv/models/stream_protocol.dart';
import 'package:stream_hub/core/media/enums/playback_engine_preference.dart';
import 'package:stream_hub/core/media/player/vlc_player_adapter.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';

/// Selects the most appropriate playback backend for a stream.
///
/// The strategy is pure policy: it never instantiates players. The Playback
/// Engine calls [selectFor] with the resolved [PlayableSession] (and whether
/// the media is live) and then materializes the chosen backend through the
/// [PlayerAdapterFactory].
///
/// Policy summary (Auto):
/// - Explicit preference (MediaKit/VLC) wins and disables fallback.
/// - RTSP/RTMP/RTMPS/UDP/RTP always prefer VLC (bundled librtmp + robust
///   multicast/RTSP demuxing).
/// - Live MPEG-TS, HLS and raw HTTP(S) relays prefer VLC on Android/iOS. This
///   is the primary mitigation for the "audio plays, video stays black after
///   buffering" issue where media_kit's native EGL video output fails on some
///   GPUs/drivers.
/// - On-demand VOD (MP4, MKV, DASH, progressive HTTP) stays on MediaKit.
/// - When VLC is unavailable (desktop platforms), MediaKit is always used.
class PlayerSelectionStrategy {
  const PlayerSelectionStrategy();

  /// Resolves the backend for [session].
  PlaybackEngineKind selectFor(
    PlayableSession session, {
    PlaybackEnginePreference preference = PlaybackEnginePreference.auto,
    bool isLive = false,
  }) {
    return selectForUrl(
      session.streamUrl,
      preference: preference,
      isLive: isLive,
    );
  }

  /// Resolves the backend for a raw stream [url].
  PlaybackEngineKind selectForUrl(
    String url, {
    PlaybackEnginePreference preference = PlaybackEnginePreference.auto,
    bool isLive = false,
  }) {
    switch (preference) {
      case PlaybackEnginePreference.mediaKit:
        return PlaybackEngineKind.mediaKit;
      case PlaybackEnginePreference.vlc:
        if (VlcPlayerAdapter.isSupported) return PlaybackEngineKind.vlc;
        return PlaybackEngineKind.mediaKit;
      case PlaybackEnginePreference.auto:
        break;
    }

    final protocol = StreamProtocol.fromUrl(url);

    switch (protocol) {
      case StreamProtocol.rtsp:
      case StreamProtocol.rtmp:
      case StreamProtocol.rtmps:
      case StreamProtocol.udp:
      case StreamProtocol.rtp:
        if (VlcPlayerAdapter.isSupported) return PlaybackEngineKind.vlc;
        break;
      default:
        break;
    }

    if (isLive &&
        (protocol == StreamProtocol.hls ||
            protocol == StreamProtocol.mpegTs ||
            protocol == StreamProtocol.http ||
            protocol == StreamProtocol.https)) {
      if (VlcPlayerAdapter.isSupported) return PlaybackEngineKind.vlc;
    }

    return PlaybackEngineKind.mediaKit;
  }
}
