import 'package:flutter/foundation.dart';

/// A snapshot of stream health tracked by the [StreamHealthMonitor].
@immutable
class StreamHealthSnapshot {
  final String sessionId;
  final bool isAvailable;
  final int latencyMs;
  final int responseTimeMs;
  final int failures;
  final int retries;
  final double averageSpeedKbps;
  final int currentBitrateKbps;
  final double packetLoss; // Reserved for future use.
  final String? lastError;
  final DateTime sampledAt;

  const StreamHealthSnapshot({
    required this.sessionId,
    this.isAvailable = false,
    this.latencyMs = 0,
    this.responseTimeMs = 0,
    this.failures = 0,
    this.retries = 0,
    this.averageSpeedKbps = 0,
    this.currentBitrateKbps = 0,
    this.packetLoss = 0,
    this.lastError,
    required this.sampledAt,
  });

  bool get isHealthy => isAvailable && failures == 0;

  StreamHealthSnapshot copyWith({
    String? sessionId,
    bool? isAvailable,
    int? latencyMs,
    int? responseTimeMs,
    int? failures,
    int? retries,
    double? averageSpeedKbps,
    int? currentBitrateKbps,
    double? packetLoss,
    String? lastError,
    DateTime? sampledAt,
  }) {
    return StreamHealthSnapshot(
      sessionId: sessionId ?? this.sessionId,
      isAvailable: isAvailable ?? this.isAvailable,
      latencyMs: latencyMs ?? this.latencyMs,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      failures: failures ?? this.failures,
      retries: retries ?? this.retries,
      averageSpeedKbps: averageSpeedKbps ?? this.averageSpeedKbps,
      currentBitrateKbps: currentBitrateKbps ?? this.currentBitrateKbps,
      packetLoss: packetLoss ?? this.packetLoss,
      lastError: lastError ?? this.lastError,
      sampledAt: sampledAt ?? this.sampledAt,
    );
  }
}
