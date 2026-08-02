import 'dart:async';
import 'dart:io';
import 'package:stream_hub/core/network/doh_http_client.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';

/// HTTP probe backed by dart:io [HttpClient]. Uses HEAD first and falls back
/// to a GET with a bounded body read when the server rejects HEAD.
class DartHttpProbe implements HttpProbe {
  const DartHttpProbe();

  @override
  Future<HttpProbeResult> probe(
    String url, {
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 10),
    bool followRedirects = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await _headProbe(
        url,
        headers,
        timeout,
        stopwatch,
        followRedirects,
      );
    } on HttpException {
      return await _getProbe(url, headers, timeout, stopwatch, followRedirects);
    } on SocketException catch (e) {
      throw StreamNetworkException(
        message: 'Network error while probing stream: ${e.message}',
        originalError: e,
      );
    } on TimeoutException {
      throw StreamTimeoutException(
        message: 'Timed out while probing stream URL.',
      );
    } on HandshakeException catch (e) {
      throw StreamNetworkException(
        message: 'SSL/TLS error while probing stream: ${e.message}',
        originalError: e,
      );
    }
  }

  Future<HttpProbeResult> _headProbe(
    String url,
    Map<String, String> headers,
    Duration timeout,
    Stopwatch stopwatch,
    bool followRedirects,
  ) async {
    final client = createDohAwareHttpClient();
    try {
      client.connectionTimeout = timeout;
      final request = await client.headUrl(Uri.parse(url)).timeout(timeout);
      headers.forEach(request.headers.set);
      request.followRedirects = followRedirects;
      request.maxRedirects = followRedirects ? 5 : 0;
      final response = await request.close().timeout(timeout);
      return _buildResult(response, url, stopwatch);
    } finally {
      client.close(force: true);
    }
  }

  Future<HttpProbeResult> _getProbe(
    String url,
    Map<String, String> headers,
    Duration timeout,
    Stopwatch stopwatch,
    bool followRedirects,
  ) async {
    final client = createDohAwareHttpClient();
    try {
      client.connectionTimeout = timeout;
      final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
      headers.forEach(request.headers.set);
      request.followRedirects = followRedirects;
      request.maxRedirects = followRedirects ? 5 : 0;
      final response = await request.close().timeout(timeout);
      // Bounded drain to avoid buffering large payloads.
      final sub = response.listen((_) {});
      await response.drain<void>();
      await sub.cancel();
      return _buildResult(response, url, stopwatch);
    } finally {
      client.close(force: true);
    }
  }

  HttpProbeResult _buildResult(
    HttpClientResponse response,
    String originalUrl,
    Stopwatch stopwatch,
  ) {
    stopwatch.stop();
    final location = _redirectLocation(response.statusCode, response.headers);
    final finalUri = response.redirects.isNotEmpty
        ? response.redirects.last.location
        : Uri.parse(originalUrl);
    return HttpProbeResult(
      statusCode: response.statusCode,
      contentType: response.headers.contentType?.mimeType,
      finalUri: finalUri,
      redirectUri: location,
      latencyMs: stopwatch.elapsedMilliseconds,
      contentLength: response.contentLength,
    );
  }

  Uri? _redirectLocation(int status, HttpHeaders headers) {
    if (status < 300 || status >= 400) return null;
    final location = headers.value(HttpHeaders.locationHeader);
    if (location == null) return null;
    return Uri.tryParse(location);
  }
}
