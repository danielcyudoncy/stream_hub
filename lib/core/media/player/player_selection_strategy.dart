import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/iptv/models/stream_protocol.dart';
import 'package:stream_hub/core/media/enums/playback_engine_preference.dart';
import 'package:stream_hub/core/media/player/exo_player_surface_view_adapter.dart';
import 'package:stream_hub/core/media/player/native_activity_player_adapter.dart';
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
/// - Explicit preference (MediaKit/ExoPlayer/Native Player/VLC) wins and
///   disables fallback.
/// - RTSP/RTMP/RTMPS/UDP/RTP always prefer VLC (bundled librtmp + robust
///   multicast/RTSP demuxing; ExoPlayer has no RTMP/UDP/RTP support).
/// - Live MPEG-TS, HLS and raw HTTP(S) relays prefer the Native Player on
///   Android. The native Activity renders ExoPlayer through a plain TextureView
///   outside the Flutter view hierarchy, which is the only render path proven to
///   display video on Unisoc/Mali devices. Flutter's own video paths are all
///   broken there: external textures are never sampled and hybrid-composition
///   platform views (SurfaceView composited or not) black-screen
///   (docs/PLAYBACK_ENGINEERING.md §1.1 and §8.3).
/// - On-demand VOD (MP4, MKV, DASH, progressive HTTP) stays on MediaKit.
/// - When the preferred backend is unavailable (desktop platforms, missing
///   native player), MediaKit is always used.
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
      case PlaybackEnginePreference.exoPlayer:
        if (ExoPlayerSurfaceViewAdapter.isSupported) {
          return PlaybackEngineKind.exoPlayer;
        }
        return PlaybackEngineKind.mediaKit;
      case PlaybackEnginePreference.nativeActivity:
        if (NativeActivityPlayerAdapter.isSupported) {
          return PlaybackEngineKind.nativeActivity;
        }
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
      if (NativeActivityPlayerAdapter.isSupported) {
        return PlaybackEngineKind.nativeActivity;
      }
      if (ExoPlayerSurfaceViewAdapter.isSupported) {
        return PlaybackEngineKind.exoPlayer;
      }
      if (VlcPlayerAdapter.isSupported) return PlaybackEngineKind.vlc;
    }

    return PlaybackEngineKind.mediaKit;
  }

  /// Ordered fallback candidates for a stream [url], most preferred first.
  ///
  /// Used by the Playback Engine in Auto mode when the selected backend fails
  /// to load. The engine skips candidates that are unavailable on the current
  /// platform and the one currently active.
  List<PlaybackEngineKind> fallbackOrderFor(
    String url, {
    bool isLive = false,
  }) {
    final protocol = StreamProtocol.fromUrl(url);

    if (protocol == StreamProtocol.rtsp ||
        protocol == StreamProtocol.rtmp ||
        protocol == StreamProtocol.rtmps ||
        protocol == StreamProtocol.udp ||
        protocol == StreamProtocol.rtp) {
      return const [
        PlaybackEngineKind.vlc,
        PlaybackEngineKind.mediaKit,
      ];
    }

    if (isLive &&
        (protocol == StreamProtocol.hls ||
            protocol == StreamProtocol.mpegTs ||
            protocol == StreamProtocol.http ||
            protocol == StreamProtocol.https)) {
      return const [
        PlaybackEngineKind.nativeActivity,
        PlaybackEngineKind.exoPlayer,
        PlaybackEngineKind.vlc,
        PlaybackEngineKind.mediaKit,
      ];
    }

    return const [
      PlaybackEngineKind.mediaKit,
      PlaybackEngineKind.exoPlayer,
      PlaybackEngineKind.nativeActivity,
      PlaybackEngineKind.vlc,
    ];
  }
}
