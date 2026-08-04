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

    test('probes the origin root when the base URL has a subpath', () async {
      final server = await PortalTestServer.start(
        scriptPath: '/server/load.php',
        handler: defaultHandler,
      );
      addTearDown(server.close);

      // Many portals serve the UI from /c/ while the API lives at the web
      // root (/server/load.php). A base URL with a subpath must still probe
      // the origin root, not only /c/server/load.php.
      final client = StalkerPortalClient(
        baseUrl: '${server.baseUrl}/c',
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      final result = await client.handshake();
      expect(result.token, 'tok-abc-123');
    });

    test('normalizes a schemeless base URL to http', () async {
      final server = await PortalTestServer.start(handler: defaultHandler);
      addTearDown(server.close);

      final bare = server.baseUrl.replaceFirst('http://', '');
      final client = StalkerPortalClient(
        baseUrl: bare,
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      expect(client.baseUrl, 'http://$bare');
      final result = await client.handshake();
      expect(result.token, 'tok-abc-123');
    });

    test('sends the MAC via the Cookie header (GET transport)', () async {
      final server = await PortalTestServer.start(handler: defaultHandler);
      addTearDown(server.close);

      final client = StalkerPortalClient(
        baseUrl: server.baseUrl,
        macAddress: 'AA:BB:CC:DD:EE:FF',
        serial: 'SN-123',
      );

      await client.handshake();

      final cookie = server.lastCookieHeader;
      expect(cookie, isNotNull);
      expect(cookie, contains('mac=AA%3ABB%3ACC%3ADD%3AEE%3AFF'));
      expect(cookie, contains('sn=SN-123'));
      expect(cookie, contains('stb_lang=en'));
    });

    test('retries throttled requests (HTTP 429)', () async {
      var attempts = 0;
      final server = await PortalTestServer.start(
        handler: (action, params) {
          if (action == 'get_ordered_list') {
            attempts++;
            if (attempts == 1) {
              return {'__status__': 429};
            }
          }
          return defaultHandler(action, params);
        },
      );
      addTearDown(server.close);

      final client = StalkerPortalClient(
        baseUrl: server.baseUrl,
        macAddress: 'AA:BB:CC:DD:EE:FF',
        token: 'tok-abc-123',
        retryBaseDelay: Duration.zero,
      );

      // Resolve the script path first so the 429 applies to a single action.
      await client.getProfile();

      final channels = await client.getOrderedList(StalkerContentType.live);
      expect(channels, hasLength(2));
      expect(attempts, 2, reason: 'first attempt 429, second succeeds');
    });

    test('tolerates empty bodies for category and list actions', () async {
      final server = await PortalTestServer.start(
        handler: (action, params) {
          if (action == 'get_categories') {
            return {'__empty__': true};
          }
          if (action == 'get_vod_list') {
            return {'__empty__': true};
          }
          if (action == 'get_ordered_list' && params['type'] == 'vod') {
            return {'__empty__': true};
          }
          return defaultHandler(action, params);
        },
      );
      addTearDown(server.close);

      final client = StalkerPortalClient(
        baseUrl: server.baseUrl,
        macAddress: 'AA:BB:CC:DD:EE:FF',
        token: 'tok-abc-123',
        retryBaseDelay: Duration.zero,
      );

      await client.getProfile();

      expect(
        await client.getCategories(StalkerContentType.live),
        isEmpty,
      );
      // Both the dedicated action and the get_ordered_list fallback are
      // empty, so the portal genuinely has no VOD.
      expect(await client.getVodList(), isEmpty);
      // Order matters: get_ordered_list still returns real channels.
      final channels = await client.getOrderedList(StalkerContentType.live);
      expect(channels, hasLength(2));
    });

    test('retries empty responses for data actions', () async {
      var attempts = 0;
      final server = await PortalTestServer.start(
        handler: (action, params) {
          if (action == 'get_ordered_list' && params['type'] == 'itv') {
            attempts++;
            if (attempts == 1) {
              return {'__empty__': true};
            }
          }
          return defaultHandler(action, params);
        },
      );
      addTearDown(server.close);

      final client = StalkerPortalClient(
        baseUrl: server.baseUrl,
        macAddress: 'AA:BB:CC:DD:EE:FF',
        token: 'tok-abc-123',
        retryBaseDelay: Duration.zero,
      );

      await client.getProfile();

      final channels = await client.getOrderedList(StalkerContentType.live);
      expect(channels, hasLength(2));
      expect(attempts, 2, reason: 'first attempt empty, second succeeds');
    });

    test('falls back to get_ordered_list when the dedicated list is empty',
        () async {
      final server = await PortalTestServer.start(
        handler: (action, params) {
          if (action == 'get_vod_list') {
            return {'__empty__': true};
          }
          if (action == 'get_ordered_list' && params['type'] == 'vod') {
            return {
              'js': {
                'data': [
                  {'id': '901', 'name': 'Fallback Movie'},
                ],
              },
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
        retryBaseDelay: Duration.zero,
      );

      await client.getProfile();

      final movies = await client.getVodList();
      expect(movies, hasLength(1));
      expect(movies.first['name'], 'Fallback Movie');
    });

    test('uses the itv content type for live TV', () async {
      final server = await PortalTestServer.start(
        handler: (action, params) {
          if (action == 'get_ordered_list') {
            expect(params['type'], 'itv');
            return {
              'js': {
                'data': [
                  {'id': '101', 'name': 'BBC One'},
                ],
              },
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

      final channels = await client.getOrderedList(StalkerContentType.live);
      expect(channels, hasLength(1));
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
