import 'dart:async';
import 'dart:io';
import 'package:stream_hub/core/network/doh_http_client.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';

/// HTTP probe backed by dart:io [HttpClient]. Uses HEAD first and falls back
/// to a GET with a bounded body read whenever the server rejects HEAD — either
/// by throwing (connection closed / empty reply) or by answering with a
/// non-success status (panels and CDNs commonly answer HEAD with 403/405 while
/// serving the same resource fine over GET).
///
/// The probe exists to gate playback, and the player always requests streams
/// with GET, so the GET path is authoritative: a HEAD-only rejection must not
/// mark a playable stream as invalid.
class DartHttpProbe implements HttpProbe {
  const DartHttpProbe();

  /// Maximum body bytes read during a GET fallback probe. Live streams are
  /// endless, so the probe reads a bounded prefix and cancels the connection.
  static const int kMaxProbeBytes = 256 * 1024;

  @override
  Future<HttpProbeResult> probe(
    String url, {
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 10),
    bool followRedirects = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final head = await _headProbe(
        url,
        headers,
        timeout,
        stopwatch,
        followRedirects,
      );
      if (head.isSuccess) return head;
      return await _getProbe(url, headers, timeout, stopwatch, followRedirects);
    } on HttpException {
      return await _getProbe(url, headers, timeout, stopwatch, followRedirects);
    } on SocketException {
      // Some panels close the connection outright on HEAD (empty reply)
      // rather than answering with 405. Treat it like "HEAD unsupported".
      return await _getProbe(url, headers, timeout, stopwatch, followRedirects);
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
      // Bounded read: live streams never end, so draining would block until
      // the timeout. Read a prefix to confirm the stream is delivering data,
      // then cancel the connection.
      final completer = Completer<void>();
      var received = 0;
      final sub = response.listen(
        (chunk) {
          received += chunk.length;
          if (received >= kMaxProbeBytes && !completer.isCompleted) {
            completer.complete();
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object _) {
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );
      await completer.future.timeout(timeout);
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
