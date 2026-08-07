/// User preference for which playback backend to use.
///
/// `auto` lets the [PlayerSelectionStrategy] pick the best engine per stream
/// and enables automatic fallback to the alternate engine when playback fails.
/// The other values pin the backend and disable fallback.
enum PlaybackEnginePreference {
  auto,
  mediaKit,
  vlc;

  String get displayName {
    switch (this) {
      case PlaybackEnginePreference.auto:
        return 'Auto';
      case PlaybackEnginePreference.mediaKit:
        return 'MediaKit';
      case PlaybackEnginePreference.vlc:
        return 'VLC';
    }
  }
}
