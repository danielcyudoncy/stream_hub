import 'dart:async';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';
import 'package:stream_hub/core/streaming/models/stream_resolution.dart';
import 'package:stream_hub/core/streaming/network/dart_http_probe.dart';
import 'package:stream_hub/core/streaming/network/url_normalizer.dart';
import 'package:stream_hub/core/streaming/resolver/stream_resolver.dart';

/// The default provider-agnostic stream resolver.
///
/// 1. Resolves relative URLs against the provider base URL.
/// 2. Follows redirects (with loop detection).
/// 3. Detects stream type, mime type, quality, and capabilities.
/// 4. Detects expiration from item metadata.
/// 5. Collects backup URLs and DRM hints.
class DefaultStreamResolver implements StreamResolver {
  final UrlNormalizer _normalizer;
  final HttpProbe _probe;

  DefaultStreamResolver({UrlNormalizer? normalizer, HttpProbe? probe})
    : _normalizer = normalizer ?? UrlNormalizer(),
      _probe = probe ?? const DartHttpProbe();

  @override
  Future<StreamResolution> resolve(StreamResolutionRequest request) async {
    final session = request.session;
    var url = _normalizer.resolveRelative(
      request.sourceUrl,
      session.baseUrl ?? '',
    );

    if (!_normalizer.isSupported(url)) {
      throw StreamUnsupportedProtocolException(
        message: 'Unsupported stream protocol: $url',
      );
    }

    if (request.options.followRedirects) {
      url = await _followRedirects(
        url,
        maxRedirects: request.options.maxRedirects,
        headers: session.headers,
        timeout: request.options.probeTimeout,
      );
    }

    url = _normalizer.canonicalize(url);
    final uri = Uri.parse(url);

    final streamType = _detectStreamType(url, request.itemMetadata);
    final mimeType = request.itemMetadata['mimeType'] as String?;
    final expires = _detectExpiration(request.itemMetadata, session);
    final capabilities = _buildCapabilities(streamType, request.itemMetadata);

    return StreamResolution(
      url: url,
      streamType: streamType,
      mimeType: mimeType,
      expiresAt: expires,
      capabilities: capabilities,
      queryParameters: Map<String, String>.from(uri.queryParameters),
      backupUrls: _extractBackupUrls(request.itemMetadata),
      drmScheme: request.itemMetadata['drmScheme'] as String?,
      drmLicenseUrl: request.itemMetadata['drmLicenseUrl'] as String?,
      metadata: Map<String, dynamic>.from(request.itemMetadata),
    );
  }

  StreamType _detectStreamType(String url, Map<String, dynamic> metadata) {
    final fromUrl = StreamType.fromUrl(url);
    if (fromUrl != StreamType.unknown) return fromUrl;

    final fromMime = StreamType.fromMimeType(metadata['mimeType'] as String?);
    if (fromMime != StreamType.unknown) return fromMime;

    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    if (scheme == 'rtsp' || scheme == 'rtmp' || scheme == 'rtmps') {
      return StreamType.fromUrl(url);
    }
    return StreamType.unknown;
  }

  StreamCapabilities _buildCapabilities(
    StreamType type,
    Map<String, dynamic> metadata,
  ) {
    final catchup = metadata['catchup'];
    final isCatchup = catchup is Map && (catchup['supported'] ?? false) == true;

    final capabilities = StreamCapabilities(
      supportsSeeking: type.supportsSeeking,
      supportsPause: type.supportsPause,
      supportsRecording:
          type == StreamType.hls ||
          type == StreamType.httpLive ||
          type == StreamType.httpsLive ||
          type == StreamType.mpegTs,
      supportsDownload:
          type == StreamType.mp4 ||
          type == StreamType.mkv ||
          (isCatchup && type.supportsSeeking),
      supportsCatchup: isCatchup,
      supportsTimeshift: isCatchup,
      supportsSubtitles: metadata['subtitles'] != null,
      supportsAudioTracks: metadata['audioTracks'] != null,
      supportsQualitySelection:
          type == StreamType.hls ||
          type == StreamType.httpLive ||
          type == StreamType.httpsLive ||
          type == StreamType.dash,
    );
    return capabilities;
  }

  DateTime? _detectExpiration(
    Map<String, dynamic> metadata,
    ProviderSession session,
  ) {
    final raw = metadata['expiresAt'];
    if (raw is DateTime) return raw;
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    if (metadata['isTemporary'] == true) {
      return DateTime.now().add(const Duration(minutes: 30));
    }
    return session.expiresAt;
  }

  List<String> _extractBackupUrls(Map<String, dynamic> metadata) {
    final raw = metadata['backupUrls'];
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    return const [];
  }

  Future<String> _followRedirects(
    String url, {
    required int maxRedirects,
    required Map<String, String> headers,
    required Duration timeout,
  }) async {
    final visited = <String>{url};
    var current = url;

    for (var i = 0; i < maxRedirects; i++) {
      HttpProbeResult result;
      try {
        result = await _probe.probe(
          current,
          headers: headers,
          timeout: timeout,
          followRedirects: false,
        );
      } on StreamRedirectLoopException {
        rethrow;
      } on TimeoutException {
        throw StreamTimeoutException(
          message: 'Timed out while resolving redirects.',
        );
      } catch (e) {
        // Probe is best-effort: fall back to the current URL when the server
        // does not answer HEAD probes.
        return current;
      }

      if (!result.isRedirect) {
        return result.finalUri.toString();
      }
      final next = result.redirectUri;
      if (next == null) return current;

      final resolved = Uri.parse(current).resolveUri(next).toString();
      if (visited.contains(resolved)) {
        throw StreamRedirectLoopException(
          message: 'Redirect loop detected: $resolved',
        );
      }
      visited.add(resolved);
      current = resolved;
    }

    throw const StreamRedirectLoopException(
      message: 'Too many redirects while resolving stream URL.',
    );
  }
}
