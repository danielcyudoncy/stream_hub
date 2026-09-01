class MediaSyncResult {
  final String sourceId;
  final bool success;
  final int added;
  final int updated;
  final int removed;
  final String? error;
  final String? epgUrl;
  final DateTime completedAt;

  const MediaSyncResult({
    required this.sourceId,
    required this.success,
    this.added = 0,
    this.updated = 0,
    this.removed = 0,
    this.error,
    this.epgUrl,
    required this.completedAt,
  });
}
