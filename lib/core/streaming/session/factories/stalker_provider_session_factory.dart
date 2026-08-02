import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory.dart';

/// Builds a [ProviderSession] for Stalker Portal sources.
///
/// Stalker portals authenticate using a MAC address plus a short-lived portal
/// token obtained during handshake.
class StalkerProviderSessionFactory implements ProviderSessionFactory {
  @override
  MediaSourceType get providerType => MediaSourceType.stalker;

  @override
  Future<ProviderSession> createSession({
    required String mediaItemId,
    required Map<String, dynamic> itemMetadata,
    Map<String, dynamic>? providerConfig,
    ProviderSession? existing,
  }) async {
    final config = providerConfig ?? const <String, dynamic>{};
    final portalUrl = (config['portalUrl'] ?? '').toString();

    return ProviderSession(
      providerId:
          existing?.providerId ??
          (config['providerId'] ?? mediaItemId).toString(),
      providerType: MediaSourceType.stalker,
      sessionId:
          existing?.sessionId ??
          'stalker_${DateTime.now().millisecondsSinceEpoch}',
      macAddress: existing?.macAddress ?? config['macAddress']?.toString(),
      deviceId: existing?.deviceId ?? config['deviceId']?.toString(),
      portalToken: existing?.portalToken ?? config['portalToken']?.toString(),
      expiresAt:
          existing?.expiresAt ?? DateTime.now().add(const Duration(hours: 8)),
      userAgent: config['userAgent']?.toString(),
      referer: config['referer']?.toString(),
      origin: config['origin']?.toString(),
      timeout: Duration(seconds: (config['timeout'] ?? 15)),
      capabilities: const StreamCapabilities.live(),
      baseUrl: portalUrl.isNotEmpty ? portalUrl : null,
    );
  }
}
