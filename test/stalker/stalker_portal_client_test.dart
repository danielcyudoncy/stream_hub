import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/data/providers/stalker/stalker_portal_client.dart';

import 'portal_test_server.dart';

void main() {
  group('StalkerPortalClient', () {
    test('performs a handshake and stores the token', () async {
      final server = await PortalTestServer.start(handler: defaultHandler);
      addTearDown(server.close);

      final client = StalkerPortalClient(
        baseUrl: server.baseUrl,
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      final result = await client.handshake();

      expect(result.token, 'tok-abc-123');
      expect(result.serial, 'sn-001');
      expect(client.token, 'tok-abc-123');
      expect(client.macAddress, 'AA:BB:CC:DD:EE:FF');
    });

    test('normalizes MAC addresses to colon-separated uppercase', () async {
      final server = await PortalTestServer.start(handler: defaultHandler);
      addTearDown(server.close);

      final client = StalkerPortalClient(
        baseUrl: server.baseUrl,
        macAddress: 'aabb.ccdd.eeff',
      );
      expect(client.macAddress, 'AA:BB:CC:DD:EE:FF');
    });

    test('fetches profile and content lists', () async {
      final server = await PortalTestServer.start(handler: defaultHandler);
      addTearDown(server.close);

      final client = StalkerPortalClient(
        baseUrl: server.baseUrl,
        macAddress: 'AA:BB:CC:DD:EE:FF',
        token: 'tok-abc-123',
      );

      final profile = await client.getProfile();
      expect(profile['auth_status'], '1');

      final channels = await client.getOrderedList(StalkerContentType.live);
      expect(channels, hasLength(2));
      expect(channels.first['name'], 'BBC One');

      final movies = await client.getVodList();
      expect(movies, hasLength(1));
      expect(movies.first['name'], 'Inception');

      final series = await client.getSeriesList();
      expect(series, hasLength(1));
      expect(series.first['seasons'], isA<List>());
    });

    test('create_link extracts the stream URL from an ffmpeg command',
        () async {
      final server = await PortalTestServer.start(handler: defaultHandler);
      addTearDown(server.close);

      final client = StalkerPortalClient(
        baseUrl: server.baseUrl,
        macAddress: 'AA:BB:CC:DD:EE:FF',
        token: 'tok-abc-123',
      );

      final url = await client.createLink(
        type: StalkerContentType.live,
        cmd: '101',
        genre: '1',
      );

      expect(url, 'http://cdn.example.com/stream/101.m3u8?token=tok-abc-123');
    });

    test('create_link uses a direct url response when present', () async {
      final server = await PortalTestServer.start(
        handler: (action, params) {
          if (action == 'create_link') {
            return {
              'js': {'url': 'http://cdn.example.com/direct/vod.mp4'},
            };
          }
          return defaultHandler(action, params);
        },
      );
      addTearDown(server.close);

      final client = StalkerPortalClient(
        baseUrl: server.baseUrl,
        macAddress: 'AA:BB:CC:DD:EE:FF',
        token: 'tok-abc-123',
      );

      final url = await client.createLink(
        type: StalkerContentType.vod,
        cmd: 'ffmpeg -i http://example.com/x.mp4',
      );
      expect(url, 'http://cdn.example.com/direct/vod.mp4');
    });

    test('falls back to a direct cmd URL when the portal returns nothing',
        () async {
      final server = await PortalTestServer.start(
        handler: (action, params) {
          if (action == 'create_link') {
            return {
              'js': {'data': <String, dynamic>{}},
            };
          }
          return defaultHandler(action, params);
        },
      );
      addTearDown(server.close);

      final client = StalkerPortalClient(
        baseUrl: server.baseUrl,
        macAddress: 'AA:BB:CC:DD:EE:FF',
        token: 'tok-abc-123',
      );

      final url = await client.createLink(
        type: StalkerContentType.live,
        cmd: 'http://cdn.example.com/raw/99.ts',
      );
      expect(url, 'http://cdn.example.com/raw/99.ts');
    });

    test('auto-detects the portal script path', () async {
      final server = await PortalTestServer.start(
        scriptPath: '/portal.php',
        handler: defaultHandler,
      );
      addTearDown(server.close);

      final client = StalkerPortalClient(
        baseUrl: server.baseUrl,
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      final result = await client.handshake();
      expect(result.token, 'tok-abc-123');
      // Tried /server/load.php (404), then /stalker_portal (404), then /portal.php.
      expect(server.requestCount, greaterThan(0));
    });

    test('throws StalkerPortalException when every script path is missing',
        () async {
      final server = await PortalTestServer.start(
        missingScript: true,
        handler: defaultHandler,
      );
      addTearDown(server.close);

      final client = StalkerPortalClient(
        baseUrl: server.baseUrl,
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      expect(
        client.handshake(),
        throwsA(isA<StalkerPortalException>()),
      );
    });
  });
}
