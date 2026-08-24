import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/player/exo_player_surface_view_adapter.dart';
import 'package:stream_hub/core/media/player/ijk_player_adapter.dart';
import 'package:stream_hub/core/media/player/media_kit_player_adapter.dart';
import 'package:stream_hub/core/media/player/native_activity_player_adapter.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/media/player/vlc_player_adapter.dart';

/// Creates [PlayerAdapter] instances for the requested [PlaybackEngineKind].
///
/// The factory is the only place that maps an engine kind onto a concrete
/// adapter, keeping the Playback Engine and the UI free of backend imports.
class PlayerAdapterFactory {
  PlayerAdapterFactory._();

  /// Creates the adapter for [kind], falling back to MediaKit when the
  /// requested backend is unavailable on the current platform.
  static PlayerAdapter create(
    PlaybackEngineKind kind, {
    LoggingService? logger,
    bool hardwareDecode = true,
  }) {
    if (kind == PlaybackEngineKind.exoPlayer &&
        ExoPlayerSurfaceViewAdapter.isSupported) {
      return ExoPlayerSurfaceViewAdapter(
        logger: logger,
        hardwareDecode: hardwareDecode,
      );
    }
    if (kind == PlaybackEngineKind.nativeActivity &&
        NativeActivityPlayerAdapter.isSupported) {
      return NativeActivityPlayerAdapter(logger: logger);
    }
    if (kind == PlaybackEngineKind.vlc && VlcPlayerAdapter.isSupported) {
      return VlcPlayerAdapter(
        logger: logger,
        hardwareDecode: hardwareDecode,
      );
    }
    if (kind == PlaybackEngineKind.ijk && IjkPlayerAdapter.isSupported) {
      return IjkPlayerAdapter(logger: logger);
    }
    return MediaKitPlayerAdapter(
      logger: logger,
      hardwareDecode: hardwareDecode,
    );
  }

  /// Returns whether [kind] is supported on the current platform.
  static bool isSupported(PlaybackEngineKind kind) {
    switch (kind) {
      case PlaybackEngineKind.exoPlayer:
        return ExoPlayerSurfaceViewAdapter.isSupported;
      case PlaybackEngineKind.nativeActivity:
        return NativeActivityPlayerAdapter.isSupported;
      case PlaybackEngineKind.vlc:
        return VlcPlayerAdapter.isSupported;
      case PlaybackEngineKind.ijk:
        return IjkPlayerAdapter.isSupported;
      case PlaybackEngineKind.mediaKit:
        return true;
      case PlaybackEngineKind.avPlayer:
      case PlaybackEngineKind.fallback:
      case PlaybackEngineKind.none:
        return false;
    }
  }
}
