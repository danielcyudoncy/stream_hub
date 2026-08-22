class SyncProgress {
  final int completed;
  final int total;
  final String? currentProvider;
  final String? message;

  const SyncProgress({
    required this.completed,
    required this.total,
    this.currentProvider,
    this.message,
  });

  double get fraction => total == 0 ? 0.0 : completed / total;
}
