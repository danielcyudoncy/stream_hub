import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/player/media_kit_player_adapter.dart';
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
    if (kind == PlaybackEngineKind.vlc && VlcPlayerAdapter.isSupported) {
      return VlcPlayerAdapter(
        logger: logger,
        hardwareDecode: hardwareDecode,
      );
    }
    return MediaKitPlayerAdapter(logger: logger);
  }
}
