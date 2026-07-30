class BufferInfo {
  final Duration currentBuffer;
  final Duration totalDuration;
  final double bufferPercentage;
  final int bufferHealthMs;
  final int droppedFrames;
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
    this.videoBitrate = 0,
    this.audioBitrate = 0,
    this.networkSpeedKbps = 0,
    this.playbackLatencyMs = 0,
    required this.measuredAt,
  });

  bool get isHealthy {
    return bufferPercentage > 10.0 && droppedFrames < 30;
  }

  BufferInfo copyWith({
    Duration? currentBuffer,
    Duration? totalDuration,
    double? bufferPercentage,
    int? bufferHealthMs,
    int? droppedFrames,
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
      videoBitrate: videoBitrate ?? this.videoBitrate,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      networkSpeedKbps: networkSpeedKbps ?? this.networkSpeedKbps,
      playbackLatencyMs: playbackLatencyMs ?? this.playbackLatencyMs,
      measuredAt: measuredAt ?? this.measuredAt,
    );
  }
}
