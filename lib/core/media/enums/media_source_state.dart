enum MediaSourceState {
  created,
  initializing,
  ready,
  syncing,
  connected,
  offline,
  error,
  disabled,
  disposed;

  String get displayName {
    switch (this) {
      case MediaSourceState.created:
        return 'Created';
      case MediaSourceState.initializing:
        return 'Initializing';
      case MediaSourceState.ready:
        return 'Ready';
      case MediaSourceState.syncing:
        return 'Syncing';
      case MediaSourceState.connected:
        return 'Connected';
      case MediaSourceState.offline:
        return 'Offline';
      case MediaSourceState.error:
        return 'Error';
      case MediaSourceState.disabled:
        return 'Disabled';
      case MediaSourceState.disposed:
        return 'Disposed';
    }
  }
}
