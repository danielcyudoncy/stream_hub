import 'package:stream_hub/core/streaming/models/drm_information.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/models/stream_resolution.dart';

/// Assembles the immutable [PlayableSession] from the resolved, authenticated,
/// and validated pipeline inputs.
class PlayableSessionFactory {
  PlayableSession create({
    required String mediaItemId,
    required ProviderSession providerSession,
    required StreamResolution resolution,
    required Map<String, String> headers,
    Map<String, String>? cookies,
    String? bearerToken,
    String? userAgent,
    String? referer,
    String? origin,
    Duration? networkTimeout,
    Map<String, dynamic>? extraMetadata,
  }) {
    final capabilities = resolution.capabilities;

    return PlayableSession(
      sessionId: _newSessionId(),
      mediaItemId: mediaItemId,
      providerId: providerSession.providerId,
      providerType: providerSession.providerType,
      streamUrl: resolution.url,
      streamType: resolution.streamType,
      mimeType: resolution.mimeType,
      headers: headers,
      cookies: cookies ?? providerSession.cookies,
      queryParameters: resolution.queryParameters,
      bearerToken: bearerToken ?? providerSession.bearerToken,
      referer: referer ?? providerSession.referer,
      origin: origin ?? providerSession.origin,
      userAgent: userAgent ?? providerSession.userAgent,
      expiresAt: resolution.expiresAt ?? providerSession.expiresAt,
      supportsSeeking: capabilities.supportsSeeking,
      supportsPause: capabilities.supportsPause,
      supportsRecording: capabilities.supportsRecording,
      supportsDownload: capabilities.supportsDownload,
      supportsCatchup: capabilities.supportsCatchup,
      supportsTimeshift: capabilities.supportsTimeshift,
      supportsSubtitles: capabilities.supportsSubtitles,
      supportsAudioTracks: capabilities.supportsAudioTracks,
      drmInformation: resolution.isDrmProtected
          ? DrmInformation(
              scheme: resolution.drmScheme,
              licenseUrl: resolution.drmLicenseUrl,
            )
          : null,
      networkTimeout: networkTimeout ?? providerSession.timeout,
      retryPolicy: providerSession.retryPolicy,
      metadata: {
        ...resolution.metadata,
        if (extraMetadata != null) ...extraMetadata,
        if (resolution.backupUrls.isNotEmpty)
          'backupUrls': resolution.backupUrls,
      },
    );
  }

  /// Builds a minimal session from an already-validated URL (used for cache
  /// hits and offline resolution).
  PlayableSession fromResolution({
    required String mediaItemId,
    required ProviderSession providerSession,
    required StreamResolution resolution,
    Map<String, String>? headers,
  }) {
    return create(
      mediaItemId: mediaItemId,
      providerSession: providerSession,
      resolution: resolution,
      headers: headers ?? providerSession.headers,
    );
  }

  String _newSessionId() {
    return 'ps_${DateTime.now().millisecondsSinceEpoch}_${_random()}';
  }

  String _random() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}
