import 'dart:convert';
import 'dart:io';

/// A lightweight in-process Stalker portal used by unit tests.
///
/// Responds to POST requests on the configured script path. A custom handler
/// can answer per `action`; the default returns a canned response map. Set
/// [missingScript] to simulate a deployment where the primary script path
/// does not exist (404) so path auto-detection can be exercised.
class PortalTestServer {
  final HttpServer _server;
  final String _scriptPath;
  final Map<String, dynamic> Function(String action, Map<String, String> params)?
      _handler;
  final bool _missingScript;

  late final String baseUrl;

  int requestCount = 0;

  PortalTestServer._(this._server, this._scriptPath, this._handler, this._missingScript);

  static Future<PortalTestServer> start({
    String scriptPath = '/server/load.php',
    Map<String, dynamic> Function(String action, Map<String, String> params)?
        handler,
    bool missingScript = false,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final testServer = PortalTestServer._(
      server,
      scriptPath,
      handler,
      missingScript,
    );
    testServer.baseUrl =
        'http://127.0.0.1:${server.port}';
    server.listen(testServer._onRequest);
    return testServer;
  }

  Future<void> _onRequest(HttpRequest request) async {
    requestCount++;
    if (request.method != 'POST') {
      request.response.statusCode = 405;
      await request.response.close();
      return;
    }

    final path = request.uri.path;
    if (path != _scriptPath) {
      request.response.statusCode = 404;
      await request.response.close();
      return;
    }

    if (_missingScript) {
      request.response.statusCode = 404;
      await request.response.close();
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    final params = Uri.splitQueryString(body);
    final action = params['action'] ?? '';

    if (_handler != null) {
      final response = _handler(action, params);
      request.response.headers.contentType = ContentType.json;
      request.response.write(json.encode(response));
      await request.response.close();
      return;
    }

    request.response.headers.contentType = ContentType.json;
    request.response.write(json.encode(const <String, dynamic>{
      'js': <String, dynamic>{'data': <String, dynamic>{}},
    }));
    await request.response.close();
  }

  Future<void> close() async {
    await _server.close(force: true);
  }
}

/// Default canned responses for a fully-featured portal.
Map<String, dynamic> defaultHandler(String action, Map<String, String> params) {
  switch (action) {
    case 'handshake':
      return {
        'js': {
          'token': 'tok-abc-123',
          'serial': 'sn-001',
        },
      };
    case 'get_profile':
      return {
        'js': {
          'data': {'id': '1', 'name': 'Test User', 'auth_status': '1'},
        },
      };
    case 'get_categories':
      return {
        'js': {
          'data': [
            {'id': '1', 'title': 'News'},
            {'id': '2', 'title': 'Movies'},
          ],
        },
      };
    case 'get_ordered_list':
      return {
        'js': {
          'data': [
            {
              'id': '101',
              'name': 'BBC One',
              'number': '1',
              'logo': 'http://cdn.example.com/bbc.png',
              'genre_id': '1',
              'cmd': "ffmpeg -i 'http://cdn.example.com/live/101.m3u8' -f mpegts pipe:1",
            },
            {
              'id': '102',
              'name': 'CNN',
              'number': '2',
              'genre_id': '1',
              'direct_source': 'http://cdn.example.com/live/102.ts',
              'cmd': 'http://cdn.example.com/live/102.ts',
            },
          ],
        },
      };
    case 'get_vod_list':
      return {
        'js': {
          'data': [
            {
              'id': '501',
              'name': 'Inception',
              'cover_big': 'http://cdn.example.com/inception.jpg',
              'genre_id': '2',
              'rating_imdb': '8.8',
              'cmd': "ffmpeg -i 'http://cdn.example.com/vod/501.mp4' -f mp4 pipe:1",
            },
          ],
        },
      };
    case 'get_series_list':
      return {
        'js': {
          'data': [
            {
              'id': '601',
              'name': 'Breaking Bad',
              'genre_id': '2',
              'seasons': [
                {
                  'id': '1',
                  'name': 'Season 1',
                  'episodes': [
                    {
                      'id': '7001',
                      'name': 'Pilot',
                      'cmd': "ffmpeg -i 'http://cdn.example.com/series/601/1/7001.mp4' -f mp4 pipe:1",
                    },
                  ],
                },
              ],
            },
          ],
        },
      };
    case 'create_link':
      return {
        'js': {
          'cmd':
              "ffmpeg -i 'http://cdn.example.com/stream/${params['cmd']}.m3u8?token=${params['token']}' -f mpegts pipe:1",
        },
      };
    default:
      return {
        'js': {
          'data': <String, dynamic>{},
        },
      };
  }
}
