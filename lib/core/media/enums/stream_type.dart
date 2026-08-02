enum StreamType {
  hls,
  httpLive,
  httpsLive,
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
      case StreamType.httpLive:
        return 'HTTP Live';
      case StreamType.httpsLive:
        return 'HTTPS Live';
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

  bool get isPlayable {
    switch (this) {
      case StreamType.unknown:
        return false;
      default:
        return true;
    }
  }

  bool get supportsSeeking => this == StreamType.mp4 || this == StreamType.mkv;

  bool get supportsPause => true;

  static StreamType fromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('rtsp://')) return StreamType.rtsp;
    if (lower.contains('rtmp://')) return StreamType.rtmp;
    if (lower.contains('.m3u8') || lower.contains('hls')) {
      if (lower.startsWith('https://')) return StreamType.httpsLive;
      if (lower.startsWith('http://')) return StreamType.httpLive;
      return StreamType.hls;
    }
    if (lower.contains('.mpd') || lower.contains('dash')) return StreamType.dash;
    if (lower.contains('.mp4')) return StreamType.mp4;
    if (lower.contains('.mkv')) return StreamType.mkv;
    if (lower.contains('.ts')) return StreamType.mpegTs;
    return StreamType.unknown;
  }

  static StreamType fromMimeType(String? mimeType) {
    if (mimeType == null) return StreamType.unknown;
    final lower = mimeType.toLowerCase();
    if (lower.contains('mpegurl') || lower.contains('hls')) {
      return StreamType.hls;
    }
    if (lower.contains('dash') || lower.contains('mpd')) return StreamType.dash;
    if (lower.contains('mpegurl')) return StreamType.hls;
    if (lower.contains('mp4')) return StreamType.mp4;
    if (lower.contains('matroska')) return StreamType.mkv;
    if (lower.contains('mpeg') && lower.contains('video')) {
      return StreamType.mpegTs;
    }
    return StreamType.unknown;
  }
}
