import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';
import 'package:stream_hub/core/streaming/models/stream_validation_result.dart';
import 'package:stream_hub/core/streaming/network/dart_http_probe.dart';
import 'package:stream_hub/core/streaming/network/url_normalizer.dart';

/// Validates a [PlayableSession] before it reaches a player or download
/// engine: URL syntax, scheme support, expiration, header integrity, and —
/// for HTTP(S) streams — reachability, content-type, and response code.
class StreamValidator {
  final HttpProbe _probe;

  StreamValidator({HttpProbe? probe}) : _probe = probe ?? const DartHttpProbe();

  /// Validates the session. When [probeNetwork] is false only local checks are
  /// performed (useful for offline cache hits).
  Future<StreamValidationResult> validate(
    PlayableSession session, {
    bool probeNetwork = true,
  }) async {
    final urlCheck = _validateUrl(session);
    if (!urlCheck.isValid) return urlCheck;

    final scheme = Uri.parse(session.streamUrl).scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') {
      if (probeNetwork) {
        final probeResult = await _probeNetwork(session);
        return probeResult;
      }
      return StreamValidationResult.valid(url: session.streamUrl);
    }

    // Non-HTTP protocols (rtsp/rtmp) cannot be probed client-side; treat as
    // valid when the URL itself is well-formed.
    return StreamValidationResult.valid(
      url: session.streamUrl,
      warnings: const ['Non-HTTP stream; network probe skipped.'],
    );
  }

  StreamValidationResult _validateUrl(PlayableSession session) {
    final url = session.streamUrl;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute || uri.scheme.isEmpty) {
      return StreamValidationResult.invalid(
        reason: 'Stream URL is malformed or not absolute.',
        url: url,
      );
    }
    if (!UrlNormalizer.supportedSchemes.contains(uri.scheme.toLowerCase())) {
      return StreamValidationResult.invalid(
        reason: 'Stream protocol "${uri.scheme}" is not supported.',
        url: url,
      );
    }
    if (session.isExpired) {
      return StreamValidationResult.invalid(
        reason: 'Stream session has expired.',
        url: url,
      );
    }
    if (_hasInvalidHeaders(session)) {
      return StreamValidationResult.invalid(
        reason: 'Stream headers contain invalid line breaks.',
        url: url,
      );
    }
    if (session.streamType == StreamType.unknown) {
      return StreamValidationResult.valid(
        url: url,
        warnings: const ['Stream type is unknown.'],
      );
    }
    return StreamValidationResult.valid(url: url);
  }

  bool _hasInvalidHeaders(PlayableSession session) {
    bool bad(String? value) =>
        value != null && (value.contains('\r') || value.contains('\n'));
    for (final entry in session.headers.entries) {
      if (bad(entry.key) || bad(entry.value)) return true;
    }
    return false;
  }

  Future<StreamValidationResult> _probeNetwork(PlayableSession session) async {
    final headers = Map<String, String>.from(session.headers);
    if (session.cookies.isNotEmpty) {
      headers.putIfAbsent('Cookie', () {
        return session.cookies.entries
            .map((e) => '${e.key}=${e.value}')
            .join('; ');
      });
    }

    HttpProbeResult probe;
    try {
      probe = await _probe.probe(
        session.streamUrl,
        headers: headers,
        timeout: session.networkTimeout,
        followRedirects: true,
      );
    } catch (e) {
      return StreamValidationResult.invalid(
        reason: 'Stream is unreachable: $e',
        url: session.streamUrl,
      );
    }

    if (probe.isAuthFailure) {
      return StreamValidationResult.invalid(
        reason: probe.statusCode == 401
            ? 'Stream requires authentication (401).'
            : 'Stream access denied (403).',
        url: session.streamUrl,
        statusCode: probe.statusCode,
      );
    }
    if (probe.isNotFound) {
      return StreamValidationResult.invalid(
        reason: 'Stream not found (404).',
        url: session.streamUrl,
        statusCode: 404,
      );
    }
    if (!probe.isSuccess) {
      return StreamValidationResult.invalid(
        reason: 'Stream returned HTTP ${probe.statusCode}.',
        url: session.streamUrl,
        statusCode: probe.statusCode,
      );
    }

    return StreamValidationResult.valid(
      url: probe.finalUri.toString(),
      statusCode: probe.statusCode,
      contentType: probe.contentType,
      latencyMs: probe.latencyMs,
    );
  }
}
