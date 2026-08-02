import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';
import 'package:stream_hub/core/streaming/network/header_engine.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory.dart';

/// Builds a [ProviderSession] for M3U sources.
///
/// Extracts the stream URL as the base URL, carries user-supplied headers, and
/// honors basic auth from provider config or credentials embedded in the URL.
class M3UProviderSessionFactory implements ProviderSessionFactory {
  final String _userAgent;

  M3UProviderSessionFactory({String? userAgent})
    : _userAgent = userAgent ?? HeaderEngine.kDefaultUserAgent;

  @override
  MediaSourceType get providerType => MediaSourceType.m3u;

  @override
  Future<ProviderSession> createSession({
    required String mediaItemId,
    required Map<String, dynamic> itemMetadata,
    Map<String, dynamic>? providerConfig,
    ProviderSession? existing,
  }) async {
    final config = providerConfig ?? const <String, dynamic>{};
    final sourceUrl = (config['sourceUrl'] ?? itemMetadata['streamUrl'] ?? '')
        .toString();
    final baseUrl = _extractBaseUrl(sourceUrl);

    final headers = <String, String>{
      ..._extractStringMap(itemMetadata['attributes']),
      ..._extractStringMap(config['headers']),
    };

    String? username = config['username']?.toString();
    String? password = config['password']?.toString();

    if (username == null && sourceUrl.isNotEmpty) {
      final uri = Uri.tryParse(sourceUrl);
      final userInfo = uri?.userInfo;
      if (userInfo != null && userInfo.isNotEmpty) {
        final parts = userInfo.split(':');
        username = parts.isNotEmpty ? parts[0] : null;
        password = parts.length > 1 ? parts.sublist(1).join(':') : null;
      }
    }

    final catchup = itemMetadata['catchup'];
    final isCatchup = catchup is Map && (catchup['supported'] ?? false) == true;

    return ProviderSession(
      providerId: existing?.providerId ?? _providerId(mediaItemId, config),
      providerType: MediaSourceType.m3u,
      sessionId:
          existing?.sessionId ?? 'm3u_${DateTime.now().millisecondsSinceEpoch}',
      headers: headers,
      bearerToken: existing?.bearerToken,
      username: username,
      password: password,
      expiresAt: existing?.expiresAt,
      userAgent: config['userAgent']?.toString() ?? _userAgent,
      referer: config['referer']?.toString(),
      origin: config['origin']?.toString(),
      timeout: Duration(seconds: (config['timeout'] ?? 15)),
      capabilities: StreamCapabilities(
        supportsSeeking: isCatchup,
        supportsPause: true,
        supportsRecording: true,
        supportsCatchup: isCatchup,
        supportsTimeshift: isCatchup,
      ),
      baseUrl: baseUrl ?? sourceUrl,
    );
  }

  String? _extractBaseUrl(String sourceUrl) {
    final uri = Uri.tryParse(sourceUrl);
    if (uri != null && uri.isAbsolute) {
      if (uri.path.endsWith('.m3u') || uri.path.endsWith('.m3u8')) {
        final segments = uri.pathSegments.toList();
        segments.removeLast();
        var directory = uri.replace(pathSegments: segments);
        if (!directory.path.endsWith('/')) {
          directory = directory.replace(path: '${directory.path}/');
        }
        return directory.toString();
      }
    }
    return null;
  }

  String _providerId(String mediaItemId, Map<String, dynamic> config) {
    final explicit = config['providerId']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final mediaItemIdPrefix = mediaItemId.split('-').first;
    return mediaItemIdPrefix;
  }

  Map<String, String> _extractStringMap(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val.toString()));
    }
    return const {};
  }
}
