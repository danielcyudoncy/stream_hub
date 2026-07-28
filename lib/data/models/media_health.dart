class MediaHealth {
  final bool isConnected;
  final int latencyMs;
  final bool isAuthenticated;
  final DateTime? lastSync;
  final List<String> errors;

  const MediaHealth({
    this.isConnected = false,
    this.latencyMs = 0,
    this.isAuthenticated = false,
    this.lastSync,
    this.errors = const [],
  });

  MediaHealth copyWith({
    bool? isConnected,
    int? latencyMs,
    bool? isAuthenticated,
    DateTime? lastSync,
    List<String>? errors,
  }) {
    return MediaHealth(
      isConnected: isConnected ?? this.isConnected,
      latencyMs: latencyMs ?? this.latencyMs,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      lastSync: lastSync ?? this.lastSync,
      errors: errors ?? this.errors,
    );
  }
}
