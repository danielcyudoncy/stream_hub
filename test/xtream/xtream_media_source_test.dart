import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_state.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/providers/xtream/xtream_media_source.dart';

import 'xtream_test_server.dart';

void main() {
  group('XtreamMediaSource', () {
    test('syncs live channels, movies, series and categories', () async {
      final server = await XtreamTestServer.start();
      addTearDown(server.close);

      final source = XtreamMediaSource(
        id: 'p1',
        config: {
          'sourceUrl': server.baseUrl,
          'username': 'demo',
          'password': 'secret',
        },
        logger: LoggingService(),
      );

      final result = await source.sync();

      expect(result.success, isTrue);
      expect(source.state, MediaSourceState.ready);

      final channels = await source.getChannels();
      expect(channels, hasLength(2));
      expect(channels.first.id, 'xtream-live-101');
      expect(channels.first.mediaType, MediaType.channel);
      expect(channels.first.metadata['streamUrl'],
          '${server.baseUrl}/live/demo/secret/101.ts');
      expect(channels.first.metadata['isLive'], isTrue);
      expect(channels.first.poster, 'http://cdn.example.com/bbc.png');

      final movies = await source.getMovies();
      expect(movies, hasLength(1));
      expect(movies.first.id, 'xtream-movie-501');
      expect(movies.first.mediaType, MediaType.movie);
      expect(movies.first.rating, 8.8);
      expect(movies.first.metadata['streamUrl'],
          '${server.baseUrl}/movie/demo/secret/501.mp4');
      expect(movies.first.metadata['isVod'], isTrue);

      final series = await source.getSeries();
      expect(series, hasLength(1));
      expect(series.first.id, 'xtream-series-601');
      expect(series.first.mediaType, MediaType.series);
      expect(series.first.metadata['seriesId'], '601');
      expect(series.first.metadata['seasonCount'], 3);

      final categories = await source.getCategories();
      expect(categories, hasLength(4));
      expect(categories.first.mediaType, MediaType.collection);

      final stats = await source.statistics();
      expect(stats.channels, 2);
      expect(stats.movies, 1);
      expect(stats.series, 1);
    });

    test('passes credentials to the player_api endpoint', () async {
      final server = await XtreamTestServer.start();
      addTearDown(server.close);

      final source = XtreamMediaSource(
        id: 'p1',
        config: {
          'sourceUrl': server.baseUrl,
          'username': 'alice',
          'password': 'hunter2',
        },
        logger: LoggingService(),
      );

      await source.sync();

      expect(server.lastUsername, 'alice');
      expect(server.lastPassword, 'hunter2');
    });

    test('live channels default to ts when container_extension is missing',
        () async {
      final server = await XtreamTestServer.start(
        handler: (action, params) {
          if (action == 'live') {
            return {
              'data': [
                {
                  'stream_id': 777,
                  'name': 'Sky Sports F1 UHD',
                  'category_id': '1',
                  'stream_type': 'live',
                },
              ],
            };
          }
          return {
            'data': [],
          };
        },
      );
      addTearDown(server.close);

      final source = XtreamMediaSource(
        id: 'p1',
        config: {
          'sourceUrl': server.baseUrl,
          'username': 'demo',
          'password': 'secret',
        },
        logger: LoggingService(),
      );

      await source.sync();

      final channels = await source.getChannels();
      expect(channels, hasLength(1));
      expect(channels.first.id, 'xtream-live-777');
      expect(channels.first.metadata['streamUrl'],
          '${server.baseUrl}/live/demo/secret/777.ts');
      expect(channels.first.metadata['isLive'], isTrue);
    });

    test('normalizes the server URL when the scheme is missing', () async {
      final source = XtreamMediaSource(
        id: 'p1',
        config: {'sourceUrl': 'example.com'},
        logger: LoggingService(),
      );

      expect(source.buildSeriesEpisodeUrl('7001', 'mp4'),
          'http://example.com/series///7001.mp4');
    });

    test('validate succeeds with authenticated user_info', () async {
      final server = await XtreamTestServer.start();
      addTearDown(server.close);

      final source = XtreamMediaSource(
        id: 'p1',
        config: {
          'sourceUrl': server.baseUrl,
          'username': 'demo',
          'password': 'secret',
        },
        logger: LoggingService(),
      );

      expect(await source.validate(), isTrue);
    });

    test('validate fails when user_info reports an unauthenticated session',
        () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        return {
          'user_info': {'auth': 0},
          'server_info': const <String, dynamic>{},
        };
      });
      addTearDown(server.close);

      final source = XtreamMediaSource(
        id: 'p1',
        config: {
          'sourceUrl': server.baseUrl,
          'username': 'demo',
          'password': 'wrong',
        },
        logger: LoggingService(),
      );

      expect(await source.validate(), isFalse);
    });

    test('falls back to get_live_streams when action=live returns no data',
        () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'live') {
          return {
            'user_info': {
              'username': params['username'] ?? '',
              'auth': 1,
              'status': 'Active',
            },
            'server_info': const <String, dynamic>{},
          };
        }
        if (action == 'get_live_streams') {
          return {
            'data': [
              {
                'stream_id': 201,
                'name': 'News 24',
                'epg_channel_id': 'news24',
                'category_id': '1',
                'container_extension': 'ts',
              },
            ],
          };
        }
        return {'data': <dynamic>[]};
      });
      addTearDown(server.close);

      final source = XtreamMediaSource(
        id: 'p1',
        config: {
          'sourceUrl': server.baseUrl,
          'username': 'demo',
          'password': 'secret',
        },
        logger: LoggingService(),
      );

      final result = await source.sync();

      expect(result.success, isTrue);
      final channels = await source.getChannels();
      expect(channels, hasLength(1));
      expect(channels.first.id, 'xtream-live-201');
      expect(channels.first.metadata['streamUrl'],
          '${server.baseUrl}/live/demo/secret/201.ts');
    });

    test('syncs panels that return bare top-level arrays for list endpoints',
        () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == '') {
          return {
            'user_info': {'auth': 1},
            'server_info': const <String, dynamic>{},
          };
        }
        if (action == 'live') {
          return {
            'user_info': {'auth': 1},
            'server_info': const <String, dynamic>{},
          };
        }
        if (action == 'get_live_streams') {
          return [
            {
              'stream_id': 301,
              'name': 'Sports HD',
              'category_id': '1',
              'container_extension': 'ts',
            },
          ];
        }
        if (action == 'get_vod_streams') {
          return [
            {
              'stream_id': 501,
              'name': 'Inception',
              'category_id': '2',
              'container_extension': 'mp4',
            },
          ];
        }
        if (action == 'get_series') {
          return [
            {'series_id': 601, 'name': 'Breaking Bad', 'category_id': '3'},
          ];
        }
        if (action == 'get_live_categories') {
          return [
            {'category_id': '1', 'category_name': 'News'},
          ];
        }
        return const <dynamic>[];
      });
      addTearDown(server.close);

      final source = XtreamMediaSource(
        id: 'p1',
        config: {
          'sourceUrl': server.baseUrl,
          'username': 'demo',
          'password': 'secret',
        },
        logger: LoggingService(),
      );

      final result = await source.sync();

      expect(result.success, isTrue);
      expect(await source.getChannels(), hasLength(1));
      expect((await source.getChannels()).first.id, 'xtream-live-301');
      expect(await source.getMovies(), hasLength(1));
      expect(await source.getSeries(), hasLength(1));
      expect(await source.getCategories(), hasLength(1));
      expect(await source.validate(), isTrue);
    });

    test('tolerates non-string values for string metadata fields', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == '') {
          return {
            'user_info': {'auth': 1},
            'server_info': const <String, dynamic>{},
          };
        }
        if (action == 'get_series') {
          return [
            {
              'series_id': 601,
              'name': 'Breaking Bad',
              'category_id': '3',
              'backdrop_path': <dynamic>[],
              'cover': 123,
              'plot': <String, dynamic>{},
            },
          ];
        }
        if (action == 'get_vod_streams') {
          return [
            {
              'stream_id': 501,
              'name': 'Inception',
              'category_id': '2',
              'stream_icon': <dynamic>['http://poster'],
            },
          ];
        }
        return const <dynamic>[];
      });
      addTearDown(server.close);

      final source = XtreamMediaSource(
        id: 'p1',
        config: {
          'sourceUrl': server.baseUrl,
          'username': 'demo',
          'password': 'secret',
        },
        logger: LoggingService(),
      );

      final result = await source.sync();

      expect(result.success, isTrue);

      final series = await source.getSeries();
      expect(series, hasLength(1));
      expect(series.first.poster, '123');
      expect(series.first.backdrop, isNull);
      expect(series.first.description, isNull);

      final movies = await source.getMovies();
      expect(movies, hasLength(1));
      expect(movies.first.poster, 'http://poster');
    });

    test('captures account metadata from user_info during sync', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == '') {
          return {
            'user_info': {
              'username': 'demo',
              'auth': 1,
              'status': 'Active',
              'created_at': '1783507521',
              'exp_date': '1817721921',
              'is_trial': '0',
              'max_connections': '1',
            },
            'server_info': const <String, dynamic>{},
          };
        }
        return {'data': <dynamic>[]};
      });
      addTearDown(server.close);

      final source = XtreamMediaSource(
        id: 'p1',
        config: {
          'sourceUrl': server.baseUrl,
          'username': 'demo',
          'password': 'secret',
        },
        logger: LoggingService(),
      );

      await source.sync();

      final meta = source.accountMetadata;
      expect(meta, isNotNull);
      expect(meta!.status, 'Active');
      expect(meta.createdAt,
          DateTime.fromMillisecondsSinceEpoch(1783507521000));
      expect(meta.expiresAt,
          DateTime.fromMillisecondsSinceEpoch(1817721921000));
      expect(meta.isTrial, isFalse);
      expect(meta.maxConnections, 1);
    });

    test('sync returns a failure result when the server is unreachable',
        () async {
      final source = XtreamMediaSource(
        id: 'p1',
        config: {
          'sourceUrl': 'http://127.0.0.1:1',
          'username': 'demo',
          'password': 'secret',
          'maxRetries': 0,
        },
        logger: LoggingService(),
      );

      final result = await source.sync();

      expect(result.success, isFalse);
      expect(source.state, MediaSourceState.error);
    });
  });
}
