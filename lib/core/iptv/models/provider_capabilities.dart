import 'package:flutter/foundation.dart';

/// The set of features a detected provider is capable of exposing.
///
/// Produced by the Provider Capability Analyzer from a [ProviderDetectionResult]
/// and optional provider configuration. The UI and negotiation layer respond to
/// these capabilities instead of provider types.
@immutable
class ProviderCapabilities {
  final bool supportsLiveTv;
  final bool supportsMovies;
  final bool supportsSeries;
  final bool supportsRadio;
  final bool supportsCatchup;
  final bool supportsTimeshift;
  final bool supportsEpg;
  final bool supportsDownloads;
  final bool supportsStreamResolution;
  final bool supportsPlaylistRefresh;
  final bool supportsBackupStreams;
  final bool supportsCustomHeaders;
  final bool requiresCredentials;
  final bool supportsAnonymousAccess;
  final List<String> supportedProtocols;

  const ProviderCapabilities({
    this.supportsLiveTv = false,
    this.supportsMovies = false,
    this.supportsSeries = false,
    this.supportsRadio = false,
    this.supportsCatchup = false,
    this.supportsTimeshift = false,
    this.supportsEpg = false,
    this.supportsDownloads = false,
    this.supportsStreamResolution = false,
    this.supportsPlaylistRefresh = false,
    this.supportsBackupStreams = false,
    this.supportsCustomHeaders = false,
    this.requiresCredentials = false,
    this.supportsAnonymousAccess = true,
    this.supportedProtocols = const [],
  });

  /// A capabilities object for an unknown provider (everything disabled).
  const ProviderCapabilities.unknown()
    : this(
        supportsLiveTv: false,
        supportsMovies: false,
        supportsSeries: false,
        supportsRadio: false,
        supportsCatchup: false,
        supportsTimeshift: false,
        supportsEpg: false,
        supportsDownloads: false,
        supportsStreamResolution: false,
        supportsPlaylistRefresh: false,
        supportsBackupStreams: false,
        supportsCustomHeaders: false,
        requiresCredentials: false,
        supportsAnonymousAccess: true,
      );

  bool get supportsCatalogContent =>
      supportsLiveTv || supportsMovies || supportsSeries || supportsRadio;

  bool get supportsAdvancedPlayback =>
      supportsCatchup || supportsTimeshift || supportsBackupStreams;

  ProviderCapabilities copyWith({
    bool? supportsLiveTv,
    bool? supportsMovies,
    bool? supportsSeries,
    bool? supportsRadio,
    bool? supportsCatchup,
    bool? supportsTimeshift,
    bool? supportsEpg,
    bool? supportsDownloads,
    bool? supportsStreamResolution,
    bool? supportsPlaylistRefresh,
    bool? supportsBackupStreams,
    bool? supportsCustomHeaders,
    bool? requiresCredentials,
    bool? supportsAnonymousAccess,
    List<String>? supportedProtocols,
  }) {
    return ProviderCapabilities(
      supportsLiveTv: supportsLiveTv ?? this.supportsLiveTv,
      supportsMovies: supportsMovies ?? this.supportsMovies,
      supportsSeries: supportsSeries ?? this.supportsSeries,
      supportsRadio: supportsRadio ?? this.supportsRadio,
      supportsCatchup: supportsCatchup ?? this.supportsCatchup,
      supportsTimeshift: supportsTimeshift ?? this.supportsTimeshift,
      supportsEpg: supportsEpg ?? this.supportsEpg,
      supportsDownloads: supportsDownloads ?? this.supportsDownloads,
      supportsStreamResolution:
          supportsStreamResolution ?? this.supportsStreamResolution,
      supportsPlaylistRefresh:
          supportsPlaylistRefresh ?? this.supportsPlaylistRefresh,
      supportsBackupStreams: supportsBackupStreams ?? this.supportsBackupStreams,
      supportsCustomHeaders: supportsCustomHeaders ?? this.supportsCustomHeaders,
      requiresCredentials: requiresCredentials ?? this.requiresCredentials,
      supportsAnonymousAccess:
          supportsAnonymousAccess ?? this.supportsAnonymousAccess,
      supportedProtocols: supportedProtocols ?? this.supportedProtocols,
    );
  }
}
