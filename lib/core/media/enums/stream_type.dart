enum StreamType {
  hls,
  mpegTs,
  dash,
  mp4,
  mkv,
  rtsp,
  rtmp,
  unknown;

  String get displayName {
    switch (this) {
      case StreamType.hls:
        return 'HLS';
      case StreamType.mpegTs:
        return 'MPEG-TS';
      case StreamType.dash:
        return 'DASH';
      case StreamType.mp4:
        return 'MP4';
      case StreamType.mkv:
        return 'MKV';
      case StreamType.rtsp:
        return 'RTSP';
      case StreamType.rtmp:
        return 'RTMP';
      case StreamType.unknown:
        return 'Unknown';
    }
  }

  static StreamType fromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8') || lower.contains('hls')) return StreamType.hls;
    if (lower.contains('.mpd') || lower.contains('dash')) return StreamType.dash;
    if (lower.contains('.mp4')) return StreamType.mp4;
    if (lower.contains('.mkv')) return StreamType.mkv;
    if (lower.contains('rtsp://')) return StreamType.rtsp;
    if (lower.contains('rtmp://')) return StreamType.rtmp;
    if (lower.contains('.ts')) return StreamType.mpegTs;
    return StreamType.unknown;
  }
}
