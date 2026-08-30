import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';
import 'package:stream_hub/core/streaming/network/header_engine.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory.dart';

/// Builds a [ProviderSession] for provider-free [MediaSourceType.custom]
/// media items (e.g. the built-in Free Live TV catalog).
///
/// These sources expose a direct stream URL and require no authentication,
/// credentials, or provider configuration. The base URL is derived from the
/// stream URL so relative segment/playlist references resolve correctly.
class CustomProviderSessionFactory implements ProviderSessionFactory {
  final String _userAgent;

  CustomProviderSessionFactory({String? userAgent})
    : _userAgent = userAgent ?? HeaderEngine.kDefaultUserAgent;

  @override
  MediaSourceType get providerType => MediaSourceType.custom;

  @override
  Future<ProviderSession> createSession({
    required String mediaItemId,
    required Map<String, dynamic> itemMetadata,
    Map<String, dynamic>? providerConfig,
    ProviderSession? existing,
  }) async {
    final config = providerConfig ?? const <String, dynamic>{};
    final sourceUrl =
        (config['sourceUrl'] ??
                itemMetadata['streamUrl'] ??
                itemMetadata['stream_url'] ??
                itemMetadata['url'] ??
                '')
            .toString();
    final baseUrl = _extractBaseUrl(sourceUrl);

    return ProviderSession(
      providerId:
          existing?.providerId ??
          (config['providerId'] ?? itemMetadata['providerId'] ?? 'custom')
              .toString(),
      providerType: MediaSourceType.custom,
      sessionId:
          existing?.sessionId ??
          'custom_${DateTime.now().millisecondsSinceEpoch}',
      headers: {
        ..._extractStringMap(itemMetadata['attributes']),
        ..._extractStringMap(itemMetadata['headers']),
        ..._extractStringMap(config['headers']),
      },
      expiresAt: existing?.expiresAt,
      userAgent: config['userAgent']?.toString() ?? _userAgent,
      referer: config['referer']?.toString() ?? itemMetadata['referer']?.toString(),
      origin: config['origin']?.toString() ?? itemMetadata['origin']?.toString(),
      timeout: Duration(seconds: (config['timeout'] ?? 15)),
      capabilities: StreamCapabilities(
        supportsSeeking: false,
        supportsPause: true,
        supportsRecording: true,
        supportsDownload: false,
        supportsCatchup: false,
        supportsTimeshift: false,
      ),
      baseUrl: baseUrl ?? sourceUrl,
    );
  }

  /// Derives the directory URL from a direct stream URL so relative HLS/DASH
  /// segment references can be resolved against it.
  String? _extractBaseUrl(String sourceUrl) {
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null || !uri.isAbsolute) return null;
    if (uri.path.endsWith('.m3u') ||
        uri.path.endsWith('.m3u8') ||
        uri.path.endsWith('.mpd')) {
      final segments = uri.pathSegments.toList();
      if (segments.isEmpty) return sourceUrl;
      segments.removeLast();
      var directory = uri.replace(pathSegments: segments);
      if (!directory.path.endsWith('/')) {
        directory = directory.replace(path: '${directory.path}/');
      }
      return directory.toString();
    }
    return null;
  }

  Map<String, String> _extractStringMap(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val.toString()));
    }
    return const {};
  }
}
