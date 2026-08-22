import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory.dart';

/// Builds a [ProviderSession] for Xtream Codes sources.
///
/// Xtream authenticates streams by appending the server URL, username, and
/// password as query parameters to every stream request.
class XtreamProviderSessionFactory implements ProviderSessionFactory {
  @override
  MediaSourceType get providerType => MediaSourceType.xtream;

  @override
  Future<ProviderSession> createSession({
    required String mediaItemId,
    required Map<String, dynamic> itemMetadata,
    Map<String, dynamic>? providerConfig,
    ProviderSession? existing,
  }) async {
    final config = providerConfig ?? const <String, dynamic>{};
    final serverUrl = (config['serverUrl'] ?? '').toString();

    return ProviderSession(
      providerId:
          existing?.providerId ??
          (config['providerId'] ?? mediaItemId).toString(),
      providerType: MediaSourceType.xtream,
      sessionId:
          existing?.sessionId ??
          'xtream_${DateTime.now().millisecondsSinceEpoch}',
      bearerToken: existing?.bearerToken,
      username: config['username']?.toString(),
      password: config['password']?.toString(),
      expiresAt:
          existing?.expiresAt ?? DateTime.now().add(const Duration(days: 30)),
      userAgent: config['userAgent']?.toString(),
      referer: config['referer']?.toString(),
      origin: config['origin']?.toString(),
      timeout: Duration(seconds: (config['timeout'] ?? 15)),
      capabilities: const StreamCapabilities.live(),
      baseUrl: serverUrl.isNotEmpty ? serverUrl : null,
    );
  }
}
