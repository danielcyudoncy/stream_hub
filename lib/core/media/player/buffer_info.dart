class BufferInfo {
  final Duration currentBuffer;
  final Duration totalDuration;
  final double bufferPercentage;
  final int bufferHealthMs;
  final int droppedFrames;
  final int videoWidth;
  final int videoHeight;
  final int videoBitrate;
  final int audioBitrate;
  final int networkSpeedKbps;
  final int playbackLatencyMs;
  final DateTime measuredAt;

  const BufferInfo({
    required this.currentBuffer,
    required this.totalDuration,
    required this.bufferPercentage,
    required this.bufferHealthMs,
    this.droppedFrames = 0,
    this.videoWidth = 0,
    this.videoHeight = 0,
    this.videoBitrate = 0,
    this.audioBitrate = 0,
    this.networkSpeedKbps = 0,
    this.playbackLatencyMs = 0,
    required this.measuredAt,
  });

  /// Whether the buffer suggests the stream is about to stall.
  ///
  /// Unbounded (live) streams have no total duration, so a percentage-based
  /// assessment is meaningless — it computes to `0.0` by definition and would
  /// flag every live stream as unhealthy while it plays (live players keep a
  /// rolling buffer that drains to near-zero against a duration of zero).
  /// Live stalls are surfaced through the adapter's buffering/playing state
  /// machine instead.
  ///
  /// For VOD, players (ExoPlayer, mpv, VLC) maintain a rolling forward buffer
  /// (typically 20-60s) rather than loading the entire file into RAM. A buffer
  /// is considered healthy if there is at least 5 seconds buffered ahead of
  /// playback, or >10% for shorter media.
  bool get isHealthy {
    if (droppedFrames >= 30) return false;
    if (totalDuration <= Duration.zero) return true;
    return bufferHealthMs >= 5000 || bufferPercentage > 10.0;
  }

  /// Whether a video frame has been decoded with real pixel dimensions.
  ///
  /// On some Android devices (Unisoc/Mali) media_kit keeps playing with audio
  /// while Flutter's external-texture consumer never samples the decoded
  /// frames (black screen); `videoWidth`/`videoHeight` stay 0 in that case,
  /// letting the engine detect the silent failure and switch to VLC.
  bool get hasVideoFrame => videoWidth > 0 && videoHeight > 0;

  BufferInfo copyWith({
    Duration? currentBuffer,
    Duration? totalDuration,
    double? bufferPercentage,
    int? bufferHealthMs,
    int? droppedFrames,
    int? videoWidth,
    int? videoHeight,
    int? videoBitrate,
    int? audioBitrate,
    int? networkSpeedKbps,
    int? playbackLatencyMs,
    DateTime? measuredAt,
  }) {
    return BufferInfo(
      currentBuffer: currentBuffer ?? this.currentBuffer,
      totalDuration: totalDuration ?? this.totalDuration,
      bufferPercentage: bufferPercentage ?? this.bufferPercentage,
      bufferHealthMs: bufferHealthMs ?? this.bufferHealthMs,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      videoBitrate: videoBitrate ?? this.videoBitrate,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      networkSpeedKbps: networkSpeedKbps ?? this.networkSpeedKbps,
      playbackLatencyMs: playbackLatencyMs ?? this.playbackLatencyMs,
      measuredAt: measuredAt ?? this.measuredAt,
    );
  }
}
