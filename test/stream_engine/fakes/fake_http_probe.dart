import 'package:stream_hub/core/streaming/models/stream_probe.dart';

/// Controllable [HttpProbe] for stream engine tests.
class FakeHttpProbe implements HttpProbe {
  final Map<String, HttpProbeResult> results;
  HttpProbeResult Function(String url, Map<String, String> headers)? onProbe;
  bool throwException = false;
  int probeCalls = 0;
  int get headProbes => probeCalls;

  FakeHttpProbe({Map<String, HttpProbeResult> results = const {}, this.onProbe})
    : results = Map<String, HttpProbeResult>.from(results);

  @override
  Future<HttpProbeResult> probe(
    String url, {
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 10),
    bool followRedirects = true,
  }) async {
    probeCalls++;
    if (throwException) {
      throw Exception('probe failed');
    }
    if (onProbe != null) {
      return onProbe!(url, headers);
    }
    final result = results[url];
    if (result != null) return result;
    return HttpProbeResult(statusCode: 200, finalUri: Uri.parse(url));
  }
}
