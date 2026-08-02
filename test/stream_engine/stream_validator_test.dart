import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';
import 'package:stream_hub/core/streaming/validation/stream_validator.dart';

import 'fakes/fake_http_probe.dart';

PlayableSession _session({
  String url = 'https://example.com/stream.m3u8',
  StreamType streamType = StreamType.httpLive,
  DateTime? expiresAt,
  Map<String, String> headers = const {},
  Map<String, String> cookies = const {},
}) {
  return PlayableSession(
    sessionId: 's1',
    mediaItemId: 'item1',
    providerId: 'provider-1',
    providerType: MediaSourceType.xtream,
    streamUrl: url,
    streamType: streamType,
    headers: headers,
    cookies: cookies,
    expiresAt: expiresAt,
  );
}

void main() {
  group('StreamValidator', () {
    test('validates a reachable http stream', () async {
      final probe = FakeHttpProbe(
        results: {
          'https://example.com/stream.m3u8': HttpProbeResult(
            statusCode: 200,
            contentType: 'application/vnd.apple.mpegurl',
            finalUri: Uri.parse('https://cdn.example.com/stream.m3u8'),
          ),
        },
      );
      final validator = StreamValidator(probe: probe);
      final result = await validator.validate(_session());
      expect(result.isValid, isTrue);
      expect(result.url, 'https://cdn.example.com/stream.m3u8');
      expect(probe.headProbes, 1);
    });

    test('sends cookies as a Cookie header on the probe', () async {
      String? probedCookie;
      final probe = FakeHttpProbe(
        onProbe: (url, headers) {
          probedCookie = headers['Cookie'];
          return HttpProbeResult(statusCode: 200, finalUri: Uri.parse(url));
        },
      );
      final validator = StreamValidator(probe: probe);
      await validator.validate(_session(cookies: const {'session': 'abc'}));
      expect(probedCookie, 'session=abc');
    });

    test('rejects http 401', () async {
      final probe = FakeHttpProbe(
        results: {
          'https://example.com/stream.m3u8': HttpProbeResult(
            statusCode: 401,
            finalUri: Uri.parse('https://example.com/stream.m3u8'),
          ),
        },
      );
      final result = await StreamValidator(probe: probe).validate(_session());
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('authentication'));
    });

    test('rejects http 404', () async {
      final probe = FakeHttpProbe(
        results: {
          'https://example.com/stream.m3u8': HttpProbeResult(
            statusCode: 404,
            finalUri: Uri.parse('https://example.com/stream.m3u8'),
          ),
        },
      );
      final result = await StreamValidator(probe: probe).validate(_session());
      expect(result.isValid, isFalse);
      expect(result.statusCode, 404);
    });

    test('rejects other non-success codes', () async {
      final probe = FakeHttpProbe(
        results: {
          'https://example.com/stream.m3u8': HttpProbeResult(
            statusCode: 500,
            finalUri: Uri.parse('https://example.com/stream.m3u8'),
          ),
        },
      );
      final result = await StreamValidator(probe: probe).validate(_session());
      expect(result.isValid, isFalse);
    });

    test('reports unreachable streams', () async {
      final probe = FakeHttpProbe()..throwException = true;
      final result = await StreamValidator(probe: probe).validate(_session());
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('unreachable'));
    });

    test('rejects malformed URLs without probing', () async {
      final probe = FakeHttpProbe();
      final result = await StreamValidator(
        probe: probe,
      ).validate(_session(url: 'not a url'));
      expect(result.isValid, isFalse);
      expect(probe.headProbes, 0);
    });

    test('rejects unsupported protocols', () async {
      final result = await StreamValidator().validate(
        _session(url: 'ftp://example.com/file'),
      );
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('not supported'));
    });

    test('rejects expired sessions', () async {
      final result = await StreamValidator().validate(
        _session(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('expired'));
    });

    test('rejects headers containing line breaks', () async {
      final result = await StreamValidator().validate(
        _session(headers: const {'X-Foo': 'bar\r\nInjected'}),
      );
      expect(result.isValid, isFalse);
    });

    test('skips network probe when probeNetwork is false', () async {
      final probe = FakeHttpProbe();
      final result = await StreamValidator(
        probe: probe,
      ).validate(_session(), probeNetwork: false);
      expect(result.isValid, isTrue);
      expect(probe.headProbes, 0);
    });

    test('non-http streams are valid without probing', () async {
      final probe = FakeHttpProbe();
      final result = await StreamValidator(probe: probe).validate(
        _session(url: 'rtsp://example.com/live', streamType: StreamType.rtsp),
      );
      expect(result.isValid, isTrue);
      expect(result.warnings, isNotEmpty);
      expect(probe.headProbes, 0);
    });
  });
}
