import 'package:stream_hub/core/iptv/models/provider_capabilities.dart';
import 'package:stream_hub/core/iptv/models/provider_detection.dart';

/// Analyzes what a detected provider is capable of exposing.
///
/// The output is a normalized [ProviderCapabilities] so the UI and negotiation
/// layer can respond to capabilities rather than provider types.
class ProviderCapabilityAnalyzer {
  const ProviderCapabilityAnalyzer();

  /// Builds provider capabilities from a detection result.
  ProviderCapabilities analyze(
    ProviderDetectionResult detection, {
    Map<String, dynamic>? config,
  }) {
    final base = _capabilitiesFor(detection);
    final cfg = config ?? const {};
    return base.copyWith(
      supportsCatchup: _configOverride(
        base.supportsCatchup,
        const ['catchup', 'catchupSupported'],
        cfg,
      ),
      supportsTimeshift: _configOverride(
        base.supportsTimeshift,
        const ['timeshift', 'timeshiftSupported'],
        cfg,
      ),
      supportsCustomHeaders: _configOverride(
        base.supportsCustomHeaders,
        const ['customHeaders', 'supportsHeaders'],
        cfg,
      ),
    );
  }

  ProviderCapabilities _capabilitiesFor(ProviderDetectionResult detection) {
    return switch (detection.providerKind) {
      DetectedProviderKind.m3u => ProviderCapabilities(
        supportsLiveTv: true,
        supportsMovies: true,
        supportsSeries: true,
        supportsRadio: true,
        supportsCatchup: true,
        supportsTimeshift: true,
        supportsEpg: true,
        supportsDownloads: true,
        supportsStreamResolution: true,
        supportsPlaylistRefresh: true,
        supportsBackupStreams: true,
        supportsCustomHeaders: true,
        requiresCredentials: detection.likelyRequiresCredentials,
        supportsAnonymousAccess: true,
        supportedProtocols: const ['hls', 'mpegts', 'mp4', 'mkv', 'dash'],
      ),
      DetectedProviderKind.xtream => ProviderCapabilities(
        supportsLiveTv: true,
        supportsMovies: true,
        supportsSeries: true,
        supportsRadio: true,
        supportsCatchup: true,
        supportsTimeshift: true,
        supportsEpg: true,
        supportsDownloads: true,
        supportsStreamResolution: true,
        supportsPlaylistRefresh: true,
        supportsBackupStreams: false,
        supportsCustomHeaders: true,
        requiresCredentials: true,
        supportsAnonymousAccess: false,
        supportedProtocols: const ['hls', 'mpegts', 'mp4', 'mkv', 'dash'],
      ),
      DetectedProviderKind.stalker => ProviderCapabilities(
        supportsLiveTv: true,
        supportsMovies: true,
        supportsSeries: true,
        supportsRadio: false,
        supportsCatchup: false,
        supportsTimeshift: false,
        supportsEpg: true,
        supportsDownloads: true,
        supportsStreamResolution: true,
        supportsPlaylistRefresh: true,
        supportsBackupStreams: false,
        supportsCustomHeaders: false,
        requiresCredentials: true,
        supportsAnonymousAccess: false,
        supportedProtocols: const ['hls', 'mpegts', 'rtsp'],
      ),
      DetectedProviderKind.xmltv => ProviderCapabilities(
        supportsLiveTv: false,
        supportsMovies: false,
        supportsSeries: false,
        supportsRadio: false,
        supportsCatchup: false,
        supportsTimeshift: false,
        supportsEpg: true,
        supportsDownloads: false,
        supportsStreamResolution: false,
        supportsPlaylistRefresh: true,
        supportsBackupStreams: false,
        supportsCustomHeaders: true,
        requiresCredentials: false,
        supportsAnonymousAccess: true,
        supportedProtocols: const [],
      ),
      DetectedProviderKind.local => ProviderCapabilities(
        supportsLiveTv: true,
        supportsMovies: true,
        supportsSeries: true,
        supportsRadio: true,
        supportsCatchup: false,
        supportsTimeshift: false,
        supportsEpg: true,
        supportsDownloads: true,
        supportsStreamResolution: true,
        supportsPlaylistRefresh: true,
        supportsBackupStreams: false,
        supportsCustomHeaders: false,
        requiresCredentials: false,
        supportsAnonymousAccess: true,
        supportedProtocols: const ['hls', 'mpegts', 'mp4', 'mkv'],
      ),
      DetectedProviderKind.unknown => const ProviderCapabilities.unknown(),
    };
  }

  /// Returns [base], overridden by any truthy/falsy values in [config] for the
  /// given [keys].
  bool _configOverride(
    bool base,
    List<String> keys,
    Map<String, dynamic> config,
  ) {
    var override = base;
    for (final key in keys) {
      final value = config[key];
      if (value == true) {
        override = true;
      } else if (value == false) {
        override = false;
      }
    }
    return override;
  }
}
