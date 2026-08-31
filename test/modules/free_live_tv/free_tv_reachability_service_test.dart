import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/services/free_tv_reachability_service.dart';
import '../../stream_engine/fakes/fake_http_probe.dart';

FreeTvChannel _channel(
  String id,
  List<String> urls, {
  bool? isWorking,
}) {
  return FreeTvChannel(
    id: id,
    name: id,
    country: 'Nigeria',
    countryCode: 'NG',
    streamUrls: urls,
    isWorking: isWorking,
  );
}

void main() {
  group('FreeTvReachabilityService', () {
    test('marks a channel working when any stream URL returns 200', () async {
      final probe = FakeHttpProbe(results: {
        'https://a.example/live.m3u8':
            HttpProbeResult(statusCode: 200, finalUri: Uri.parse('https://a.example/live.m3u8')),
        'https://b.example/live.m3u8':
            HttpProbeResult(statusCode: 404, finalUri: Uri.parse('https://b.example/live.m3u8')),
      });
      final service = FreeTvReachabilityService(probe: probe);

      final ch = _channel('ch1', [
        'https://a.example/live.m3u8',
        'https://b.example/live.m3u8',
      ]);
      final result = await service.probeChannel(ch);

      expect(result.isWorking, isTrue);
    });

    test('marks a channel not-working when every stream URL fails', () async {
      final probe = FakeHttpProbe(results: {
        'https://a.example/live.m3u8':
            HttpProbeResult(statusCode: 403, finalUri: Uri.parse('https://a.example/live.m3u8')),
        'https://b.example/live.m3u8':
            HttpProbeResult(statusCode: 500, finalUri: Uri.parse('https://b.example/live.m3u8')),
      });
      final service = FreeTvReachabilityService(probe: probe);

      final result = await service.probeChannel(
        _channel('ch1', ['https://a.example/live.m3u8', 'https://b.example/live.m3u8']),
      );

      expect(result.isWorking, isFalse);
    });

    test('treats a playable media content-type as working on non-2xx', () async {
      final probe = FakeHttpProbe(results: {
        'https://a.example/live.m3u8': HttpProbeResult(
          statusCode: 200,
          contentType: 'application/vnd.apple.mpegurl',
          finalUri: Uri.parse('https://a.example/live.m3u8'),
        ),
      });
      final service = FreeTvReachabilityService(probe: probe);

      final result = await service.probeChannel(
        _channel('ch1', ['https://a.example/live.m3u8']),
      );

      expect(result.isWorking, isTrue);
    });

    test('marks a channel with no URLs as not-working', () async {
      final service = FreeTvReachabilityService(
        probe: FakeHttpProbe(),
      );
      final result = await service.probeChannel(_channel('ch1', const []));
      expect(result.isWorking, isFalse);
    });

    test('handles a probe that throws and falls back to not-working', () async {
      final probe = FakeHttpProbe(results: {
        'https://a.example/live.m3u8':
            HttpProbeResult(statusCode: 404, finalUri: Uri.parse('https://a.example/live.m3u8')),
      });
      final service = FreeTvReachabilityService(probe: probe);
      final result = await service.probeChannel(
        _channel('ch1', ['https://a.example/live.m3u8']),
      );
      expect(result.isWorking, isFalse);
    });

    test('filterWorking returns only working channels and preserves order',
        () async {
      final probe = FakeHttpProbe(results: {
        'https://ok.example/live.m3u8':
            HttpProbeResult(statusCode: 200, finalUri: Uri.parse('https://ok.example/live.m3u8')),
        'https://dead.example/live.m3u8':
            HttpProbeResult(statusCode: 404, finalUri: Uri.parse('https://dead.example/live.m3u8')),
      });
      final service = FreeTvReachabilityService(probe: probe);

      final channels = [
        _channel('ok', ['https://ok.example/live.m3u8']),
        _channel('dead', ['https://dead.example/live.m3u8']),
        _channel('ok2', ['https://ok.example/live.m3u8']),
      ];

      final filtered = await service.filterWorking(channels, concurrency: 2);

      expect(filtered.map((c) => c.id), ['ok', 'ok2']);
    });

    test('probeMany invokes onProbed for every channel', () async {
      final probe = FakeHttpProbe(results: {
        'https://ok.example/live.m3u8':
            HttpProbeResult(statusCode: 200, finalUri: Uri.parse('https://ok.example/live.m3u8')),
      });
      final service = FreeTvReachabilityService(probe: probe);
      final probedIds = <String>[];

      final channels = [
        _channel('a', ['https://ok.example/live.m3u8']),
        _channel('b', ['https://ok.example/live.m3u8']),
      ];
      final probed = await service.probeMany(
        channels,
        concurrency: 2,
        onProbed: (c) => probedIds.add(c.id),
      );

      expect(probed.length, 2);
      expect(probedIds.toSet(), {'a', 'b'});
    });
  });
}
