import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/network/header_engine.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory.dart';

/// Builds a [ProviderSession] for token-based media servers (Plex, Jellyfin,
/// Emby). These servers require a bearer/API token on every stream request.
class BearerServerProviderSessionFactory implements ProviderSessionFactory {
  final MediaSourceType type;

  const BearerServerProviderSessionFactory(this.type);

  @override
  MediaSourceType get providerType => type;

  @override
  Future<ProviderSession> createSession({
    required String mediaItemId,
    required Map<String, dynamic> itemMetadata,
    Map<String, dynamic>? providerConfig,
    ProviderSession? existing,
  }) async {
    final config = providerConfig ?? const <String, dynamic>{};
    final serverUrl = (config['serverUrl'] ?? '').toString();
    final token =
        existing?.bearerToken ??
        config['apiKey']?.toString() ??
        config['token']?.toString();

    return ProviderSession(
      providerId:
          existing?.providerId ??
          (config['providerId'] ?? mediaItemId).toString(),
      providerType: type,
      sessionId:
          existing?.sessionId ??
          '${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      bearerToken: token,
      headers: {
        ..._extractStringMap(itemMetadata['headers']),
        ..._extractStringMap(config['headers']),
      },
      expiresAt: existing?.expiresAt,
      userAgent:
          config['userAgent']?.toString() ?? HeaderEngine.kDefaultUserAgent,
      referer: config['referer']?.toString(),
      origin: config['origin']?.toString(),
      timeout: Duration(seconds: (config['timeout'] ?? 15)),
      baseUrl: serverUrl.isNotEmpty ? serverUrl : null,
    );
  }

  Map<String, String> _extractStringMap(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val.toString()));
    }
    return const {};
  }
}
