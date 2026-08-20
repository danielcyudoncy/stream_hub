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
    final portalUrl = (config['portalUrl'] ??
            config['serverUrl'] ??
            config['sourceUrl'] ??
            itemMetadata['portalUrl'] ??
            '')
        .toString();

    final mac = existing?.macAddress ??
        config['macAddress']?.toString() ??
        itemMetadata['macAddress']?.toString();
    final deviceId = existing?.deviceId ??
        config['deviceId']?.toString() ??
        (mac != null && mac.isNotEmpty ? mac : null);
    final token = existing?.portalToken ?? config['portalToken']?.toString();

    final headers = <String, String>{
      'X-User-Agent': 'Model: MAG250; Link: WiFi',
      if (existing?.headers != null) ...existing!.headers,
    };

    final cookies = <String, String>{
      if (mac != null && mac.isNotEmpty) 'mac': mac,
      if (deviceId != null && deviceId.isNotEmpty) 'sn': deviceId,
      'stb_lang': 'en',
      'timezone': 'UTC',
      if (token != null && token.isNotEmpty) 'token': token,
      if (existing?.cookies != null) ...existing!.cookies,
    };

    return ProviderSession(
      providerId:
          existing?.providerId ??
          (config['providerId'] ?? mediaItemId).toString(),
      providerType: MediaSourceType.stalker,
      sessionId:
          existing?.sessionId ??
          'stalker_${DateTime.now().millisecondsSinceEpoch}',
      macAddress: mac,
      deviceId: deviceId,
      portalToken: token,
      expiresAt:
          existing?.expiresAt ?? DateTime.now().add(const Duration(hours: 8)),
      userAgent: config['userAgent']?.toString() ??
          'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 4.8.0 rev: 1.0',
      referer: config['referer']?.toString() ??
          (portalUrl.isNotEmpty ? '$portalUrl/' : null),
      origin: config['origin']?.toString() ??
          (portalUrl.isNotEmpty ? portalUrl : null),
      timeout: Duration(seconds: (config['timeout'] ?? 15)),
      capabilities: const StreamCapabilities.live(),
      baseUrl: portalUrl.isNotEmpty ? portalUrl : null,
      headers: headers,
      cookies: cookies,
    );
  }
}
