import 'package:stream_hub/core/media/enums/stream_type.dart';

/// The transport protocol detected for a stream.
///
/// Protocol detection is richer than [StreamType] — it distinguishes UDP/RTP
/// multicast, RTMPS, and plain HTTP(S) from the container-oriented types so the
/// player negotiator can pick the most appropriate playback engine.
enum StreamProtocol {
  /// HTTP Live Streaming (`.m3u8` manifest + TS/fMP4 segments).
  hls,

  /// Dynamic Adaptive Streaming over HTTP (`.mpd` manifest).
  dash,

  /// MPEG transport stream (live `udp://` or `http://.../stream.ts`).
  mpegTs,

  /// Progressive MP4 container.
  mp4,

  /// Matroska container.
  mkv,

  /// Real Time Streaming Protocol.
  rtsp,

  /// Real Time Messaging Protocol.
  rtmp,

  /// Secure RTMP.
  rtmps,

  /// UDP multicast (unbuffered).
  udp,

  /// Raw RTP over UDP.
  rtp,

  /// Plain HTTP progressive download / live relay.
  http,

  /// HTTPS progressive download / live relay.
  https,

  /// Protocol could not be determined.
  unknown;

  String get displayName {
    switch (this) {
      case StreamProtocol.hls:
        return 'HLS';
      case StreamProtocol.dash:
        return 'DASH';
      case StreamProtocol.mpegTs:
        return 'MPEG-TS';
      case StreamProtocol.mp4:
        return 'MP4';
      case StreamProtocol.mkv:
        return 'MKV';
      case StreamProtocol.rtsp:
        return 'RTSP';
      case StreamProtocol.rtmp:
        return 'RTMP';
      case StreamProtocol.rtmps:
        return 'RTMPS';
      case StreamProtocol.udp:
        return 'UDP';
      case StreamProtocol.rtp:
        return 'RTP';
      case StreamProtocol.http:
        return 'HTTP';
      case StreamProtocol.https:
        return 'HTTPS';
      case StreamProtocol.unknown:
        return 'Unknown';
    }
  }

  /// Adaptive protocols expose a manifest and support quality switching.
  bool get isAdaptive =>
      this == StreamProtocol.hls || this == StreamProtocol.dash;

  /// Whether the protocol is carried over HTTP(S).
  bool get isHttpBased =>
      this == StreamProtocol.hls ||
      this == StreamProtocol.dash ||
      this == StreamProtocol.mpegTs ||
      this == StreamProtocol.mp4 ||
      this == StreamProtocol.mkv ||
      this == StreamProtocol.http ||
      this == StreamProtocol.https;

  /// Whether seeking is generally possible for this protocol.
  bool get isSeekable =>
      this == StreamProtocol.mp4 ||
      this == StreamProtocol.mkv ||
      this == StreamProtocol.http ||
      this == StreamProtocol.https;

  /// Whether the protocol is suited to live (unbounded) playback.
  bool get isLiveCapable =>
      this == StreamProtocol.hls ||
      this == StreamProtocol.dash ||
      this == StreamProtocol.mpegTs ||
      this == StreamProtocol.rtsp ||
      this == StreamProtocol.rtmp ||
      this == StreamProtocol.rtmps ||
      this == StreamProtocol.udp ||
      this == StreamProtocol.rtp ||
      this == StreamProtocol.http ||
      this == StreamProtocol.https;

  /// Whether the protocol can carry multicast (UDP/RTP).
  bool get isMulticast => this == StreamProtocol.udp || this == StreamProtocol.rtp;

  /// Best-effort detection from a raw URL string.
  static StreamProtocol fromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.startsWith('rtsp://')) return StreamProtocol.rtsp;
    if (lower.startsWith('rtmps://')) return StreamProtocol.rtmps;
    if (lower.startsWith('rtmp://')) return StreamProtocol.rtmp;
    if (lower.startsWith('udp://')) return StreamProtocol.udp;
    if (lower.startsWith('rtp://')) return StreamProtocol.rtp;
    if (lower.startsWith('https://')) {
      if (lower.contains('.m3u8') || lower.contains('hls')) {
        return StreamProtocol.hls;
      }
      if (lower.contains('.mpd') || lower.contains('dash')) {
        return StreamProtocol.dash;
      }
      if (lower.contains('.ts')) return StreamProtocol.mpegTs;
      if (lower.contains('.mp4')) return StreamProtocol.mp4;
      if (lower.contains('.mkv')) return StreamProtocol.mkv;
      return StreamProtocol.https;
    }
    if (lower.startsWith('http://')) {
      if (lower.contains('.m3u8') || lower.contains('hls')) {
        return StreamProtocol.hls;
      }
      if (lower.contains('.mpd') || lower.contains('dash')) {
        return StreamProtocol.dash;
      }
      if (lower.contains('.ts')) return StreamProtocol.mpegTs;
      if (lower.contains('.mp4')) return StreamProtocol.mp4;
      if (lower.contains('.mkv')) return StreamProtocol.mkv;
      return StreamProtocol.http;
    }
    return StreamProtocol.unknown;
  }

  /// Best-effort detection from a MIME type string.
  static StreamProtocol fromMimeType(String? mimeType) {
    if (mimeType == null) return StreamProtocol.unknown;
    final lower = mimeType.toLowerCase();
    if (lower.contains('mpegurl') || lower.contains('hls')) {
      return StreamProtocol.hls;
    }
    if (lower.contains('dash') || lower.contains('mpd')) {
      return StreamProtocol.dash;
    }
    if (lower.contains('mp4')) return StreamProtocol.mp4;
    if (lower.contains('matroska')) return StreamProtocol.mkv;
    if (lower.contains('mpeg') && lower.contains('video')) {
      return StreamProtocol.mpegTs;
    }
    if (lower.contains('mpeg')) return StreamProtocol.mpegTs;
    return StreamProtocol.unknown;
  }

  /// Maps a protocol back onto the canonical [StreamType] used by the existing
  /// Stream Engine and [PlayableSession].
  StreamType toStreamType() {
    switch (this) {
      case StreamProtocol.hls:
        return StreamType.hls;
      case StreamProtocol.dash:
        return StreamType.dash;
      case StreamProtocol.mpegTs:
        return StreamType.mpegTs;
      case StreamProtocol.mp4:
        return StreamType.mp4;
      case StreamProtocol.mkv:
        return StreamType.mkv;
      case StreamProtocol.rtsp:
        return StreamType.rtsp;
      case StreamProtocol.rtmp:
      case StreamProtocol.rtmps:
        return StreamType.rtmp;
      case StreamProtocol.udp:
      case StreamProtocol.rtp:
      case StreamProtocol.http:
        return StreamType.httpLive;
      case StreamProtocol.https:
        return StreamType.httpsLive;
      case StreamProtocol.unknown:
        return StreamType.unknown;
    }
  }
}
