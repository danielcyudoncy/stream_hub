import 'dart:convert';
import 'dart:io';

/// A lightweight in-process Xtream Codes `player_api.php` server used by unit
/// tests.
///
/// Responds to authenticated panel endpoints (`live`, `get_vod_streams`,
/// `get_series`, category lists, and `get_series_info`). A custom handler can
/// answer per `action`; the default returns canned fixture data.
class XtreamTestServer {
  final HttpServer _server;
  final dynamic Function(String action, Map<String, String> params)? _handler;

  late final String baseUrl;

  int requestCount = 0;
  String? lastUsername;
  String? lastPassword;

  XtreamTestServer._(this._server, this._handler);

  static Future<XtreamTestServer> start({
    dynamic Function(String action, Map<String, String> params)? handler,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final testServer = XtreamTestServer._(server, handler);
    testServer.baseUrl = 'http://127.0.0.1:${server.port}';
    server.listen(testServer._onRequest);
    return testServer;
  }

  Future<void> _onRequest(HttpRequest request) async {
    requestCount++;
    final path = request.uri.path;
    if (path != '/player_api.php') {
      request.response.statusCode = 404;
      await request.response.close();
      return;
    }

    final params = request.uri.queryParameters;
    lastUsername = params['username'];
    lastPassword = params['password'];
    final action = params['action'] ?? '';

    if (_handler != null) {
      final response = _handler(action, params);
      if (response is Map) {
        final status = response['__status__'];
        if (status is int) {
          request.response.statusCode = status;
          await request.response.close();
          return;
        }
        if (response['__empty__'] == true) {
          request.response.statusCode = 200;
          await request.response.close();
          return;
        }
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(json.encode(response));
      await request.response.close();
      return;
    }

    request.response.headers.contentType = ContentType.json;
    request.response.write(json.encode(defaultHandler(action, params)));
    await request.response.close();
  }

  Future<void> close() async {
    await _server.close(force: true);
  }
}

/// Default canned responses for a fully-featured Xtream panel.
Map<String, dynamic> defaultHandler(String action, Map<String, String> params) {
  switch (action) {
    case '':
      return {
        'user_info': {
          'username': params['username'] ?? '',
          'password': params['password'] ?? '',
          'auth': 1,
          'status': 'Active',
          'exp_date': '9999999999',
        },
        'server_info': {
          'url': 'http://example.com',
          'version': '1.0',
        },
      };
    case 'live':
      return {
        'data': [
          {
            'stream_id': 101,
            'name': 'BBC One',
            'stream_icon': 'http://cdn.example.com/bbc.png',
            'epg_channel_id': 'bbcone.uk',
            'category_id': '1',
            'container_extension': 'ts',
            'tv_archive': 1,
            'tv_archive_duration': '168',
            'stream_type': 'live',
          },
          {
            'stream_id': 102,
            'name': 'CNN',
            'epg_channel_id': 'cnn.us',
            'category_id': '1',
            'container_extension': 'm3u8',
            'tv_archive': 0,
            'stream_type': 'live',
          },
        ],
      };
    case 'get_vod_streams':
      return {
        'data': [
          {
            'stream_id': 501,
            'name': 'Inception',
            'stream_icon': 'http://cdn.example.com/inception.jpg',
            'backdrop_path': 'http://cdn.example.com/inception-bg.jpg',
            'category_id': '2',
            'container_extension': 'mp4',
            'rating': '8.8',
            'plot': 'A thief who steals corporate secrets.',
            'year': '2010',
            'duration': '8834',
            'genre': 'Sci-Fi',
          },
        ],
      };
    case 'get_series':
      return {
        'data': [
          {
            'series_id': 601,
            'name': 'Breaking Bad',
            'cover': 'http://cdn.example.com/bb.jpg',
            'backdrop_path': 'http://cdn.example.com/bb-bg.jpg',
            'category_id': '3',
            'rating': '9.5',
            'plot': 'A chemistry teacher turns to crime.',
            'year': '2008',
            'seasons': [1, 2, 3],
            'genre': 'Drama',
          },
        ],
      };
    case 'get_live_categories':
      return {
        'data': [
          {'category_id': '1', 'category_name': 'News'},
          {'category_id': '2', 'category_name': 'Entertainment'},
        ],
      };
    case 'get_vod_categories':
      return {
        'data': [
          {'category_id': '2', 'category_name': 'Movies'},
        ],
      };
    case 'get_series_categories':
      return {
        'data': [
          {'category_id': '3', 'category_name': 'Series'},
        ],
      };
    case 'get_series_info':
      return {
        'seasons': [
          {
            'id': '1',
            'name': 'Season 1',
            'episodes': [
              {
                'id': '7001',
                'title': 'Pilot',
                'container_extension': 'mp4',
                'season': 1,
                'episode_num': 1,
              },
              {
                'id': '7002',
                'title': 'Cat\'s in the Bag...',
                'container_extension': 'mp4',
                'season': 1,
                'episode_num': 2,
              },
            ],
          },
          {
            'id': '2',
            'name': 'Season 2',
            'episodes': [
              {
                'id': '7101',
                'title': 'Seven Thirty-Seven',
                'container_extension': 'mkv',
                'season': 2,
                'episode_num': 1,
              },
            ],
          },
        ],
      };
    default:
      return {
        'data': <dynamic>[],
      };
  }
}
