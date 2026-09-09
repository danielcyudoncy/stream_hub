import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';
import 'package:stream_hub/core/streaming/series/xtream_series_info_service.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory.dart';
import 'package:stream_hub/data/providers/xtream/xtream_url_detector.dart';

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
    var serverUrl = (config['serverUrl'] ?? config['sourceUrl'] ?? itemMetadata['serverUrl'] ?? '').toString();
    var username = config['username']?.toString();
    var password = config['password']?.toString();

    // If serverUrl is an export link or contains credentials/php endpoints, extract parts & sanitize
    if (serverUrl.isNotEmpty) {
      final parts = XtreamUrlDetector.parse(serverUrl);
      if (parts != null) {
        serverUrl = parts.serverUrl;
        username ??= parts.username;
        password ??= parts.password;
      }
      serverUrl = XtreamSeriesInfoService.sanitizeBaseUrl(serverUrl);
    }

    // If still missing, check itemMetadata for streamUrl: /(live|movie|series)/username/password/
    if ((username == null || username.isEmpty || password == null || password.isEmpty)) {
      final streamUrl = (itemMetadata['streamUrl'] ?? '').toString();
      if (streamUrl.isNotEmpty) {
        final match = RegExp(r'/(?:live|movie|series)/([^/]+)/([^/]+)/').firstMatch(streamUrl);
        if (match != null) {
          username ??= match.group(1);
          password ??= match.group(2);
          if (serverUrl.isEmpty) {
            final uri = Uri.tryParse(streamUrl);
            if (uri != null && uri.host.isNotEmpty) {
              serverUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
            }
          }
        }
      }
    }

    if (serverUrl.endsWith('/')) {
      serverUrl = serverUrl.substring(0, serverUrl.length - 1);
    }

    return ProviderSession(
      providerId:
          existing?.providerId ??
          (config['providerId'] ?? mediaItemId).toString(),
      providerType: MediaSourceType.xtream,
      sessionId:
          existing?.sessionId ??
          'xtream_${DateTime.now().millisecondsSinceEpoch}',
      bearerToken: existing?.bearerToken,
      username: username ?? existing?.username,
      password: password ?? existing?.password,
      expiresAt:
          existing?.expiresAt ?? DateTime.now().add(const Duration(days: 30)),
      userAgent: config['userAgent']?.toString(),
      referer: config['referer']?.toString(),
      origin: config['origin']?.toString(),
      timeout: Duration(seconds: (config['timeout'] ?? 15)),
      capabilities: const StreamCapabilities.live(),
      baseUrl: serverUrl.isNotEmpty ? serverUrl : existing?.baseUrl,
    );
  }
}

