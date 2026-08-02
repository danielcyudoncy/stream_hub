import 'package:flutter/foundation.dart';

/// A lightweight HTTP probe result used for reachability, redirect, and
/// content-type checks without downloading the full stream.
@immutable
class HttpProbeResult {
  final int statusCode;
  final String? contentType;
  final Uri finalUri;
  final Uri? redirectUri;
  final int latencyMs;
  final int contentLength;
  final bool isSuccess;

  const HttpProbeResult({
    required this.statusCode,
    this.contentType,
    required this.finalUri,
    this.redirectUri,
    this.latencyMs = 0,
    this.contentLength = -1,
  }) : isSuccess = statusCode >= 200 && statusCode < 300;

  bool get isRedirect =>
      statusCode >= 300 && statusCode < 400 && redirectUri != null;

  bool get isAuthFailure => statusCode == 401 || statusCode == 403;

  bool get isNotFound => statusCode == 404;
}

/// Abstraction over an HTTP client used by the stream engine so that
/// resolution, redirects, and validation can be tested without a real network.
abstract class HttpProbe {
  /// Performs a HEAD request (falling back to GET when the server rejects
  /// HEAD) and returns probe metadata.
  Future<HttpProbeResult> probe(
    String url, {
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 10),
    bool followRedirects = true,
  });
}
