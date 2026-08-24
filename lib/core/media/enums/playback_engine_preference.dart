/// User preference for which playback backend to use.
///
/// `auto` lets the [PlayerSelectionStrategy] pick the best engine per stream
/// and enables automatic fallback to the alternate engine when playback fails.
/// The other values pin the backend and disable fallback.
///
/// `ijk` is an experimental, opt-in-only backend (Phase 3 evaluation): it is
/// never chosen by `auto`, never appears in the automatic fallback chain, and
/// runs only when the user selects it explicitly.
enum PlaybackEnginePreference {
  auto,
  mediaKit,
  exoPlayer,
  nativeActivity,
  vlc,
  ijk;

  String get displayName {
    switch (this) {
      case PlaybackEnginePreference.auto:
        return 'Auto';
      case PlaybackEnginePreference.mediaKit:
        return 'MediaKit';
      case PlaybackEnginePreference.exoPlayer:
        return 'ExoPlayer';
      case PlaybackEnginePreference.nativeActivity:
        return 'Native Player';
      case PlaybackEnginePreference.vlc:
        return 'VLC';
      case PlaybackEnginePreference.ijk:
        return 'IJK (Experimental)';
    }
  }
}
