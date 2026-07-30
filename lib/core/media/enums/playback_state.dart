enum PlaybackState {
  idle,
  loading,
  buffering,
  playing,
  paused,
  stopped,
  completed,
  seeking,
  error,
  disposed;

  String get displayName {
    switch (this) {
      case PlaybackState.idle:
        return 'Idle';
      case PlaybackState.loading:
        return 'Loading';
      case PlaybackState.buffering:
        return 'Buffering';
      case PlaybackState.playing:
        return 'Playing';
      case PlaybackState.paused:
        return 'Paused';
      case PlaybackState.stopped:
        return 'Stopped';
      case PlaybackState.completed:
        return 'Completed';
      case PlaybackState.seeking:
        return 'Seeking';
      case PlaybackState.error:
        return 'Error';
      case PlaybackState.disposed:
        return 'Disposed';
    }
  }

  bool get isActive {
    return this == PlaybackState.playing ||
        this == PlaybackState.buffering ||
        this == PlaybackState.seeking;
  }

  bool get isStoppedLike {
    return this == PlaybackState.idle ||
        this == PlaybackState.stopped ||
        this == PlaybackState.completed ||
        this == PlaybackState.disposed;
  }
}
