import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/vod/xtream_vod_info_service.dart';
import 'package:stream_hub/data/models/media_item.dart';

import 'xtream_test_server.dart';

void main() {
  group('XtreamVodInfoService', () {
    test('fetches and parses info object from get_vod_info', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_vod_info') {
          return {
            'info': {
              'name': 'The Example Movie',
              'cover_big': 'https://image.tmdb.org/t/p/w600_and_h900_bestv2/qJ2tW6WMUDux911r6m7haRef0WH.jpg',
              'movie_image': 'https://image.tmdb.org/t/p/w600_and_h900_bestv2/qJ2tW6WMUDux911r6m7haRef0WH.jpg',
              'backdrop_path': ['https://image.tmdb.org/t/p/w1280/8ZTVqvKDQ8emSGUEMjsS4yHAwrp.jpg'],
              'plot': 'A thrilling undercover story.',
              'genre': 'Action / Crime',
              'releasedate': '2023-05-12',
              'rating': '7.8',
              'duration': '02:04:11',
              'duration_secs': 7451,
            },
            'movie_data': {
              'stream_id': 12345,
              'name': 'The Example Movie',
              'container_extension': 'mp4',
            },
          };
        }
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final service = XtreamVodInfoService(logger: LoggingService());
      final info = await service.fetch(
        baseUrl: server.baseUrl,
        username: 'demo',
        password: 'secret',
        vodId: '12345',
      );

      expect(info.vodId, '12345');
      expect(info.name, 'The Example Movie');
      expect(info.poster, 'https://image.tmdb.org/t/p/w600_and_h900_bestv2/qJ2tW6WMUDux911r6m7haRef0WH.jpg');
      expect(info.backdrop, 'https://image.tmdb.org/t/p/w1280/8ZTVqvKDQ8emSGUEMjsS4yHAwrp.jpg');
      expect(info.plot, 'A thrilling undercover story.');
      expect(info.genre, 'Action / Crime');
      expect(info.rating, 7.8);
      expect(info.durationSeconds, 7451);
      expect(info.containerExtension, 'mp4');
    });

    test('resolves TMDB hashes inside get_vod_info to TMDB image URLs', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_vod_info') {
          return {
            'info': {
              'name': 'Sample Movie',
              'cover_big': '/7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg',
              'backdrop_path': ['/8ZTVqvKDQ8emSGUEMjsS4yHAwrp.jpg'],
            },
          };
        }
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final service = XtreamVodInfoService(logger: LoggingService());
      final info = await service.fetch(
        baseUrl: server.baseUrl,
        username: 'demo',
        password: 'secret',
        vodId: '99',
      );

      expect(info.poster, 'https://image.tmdb.org/t/p/w500/7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg');
      expect(info.backdrop, 'https://image.tmdb.org/t/p/w500/8ZTVqvKDQ8emSGUEMjsS4yHAwrp.jpg');
    });

    test('fetchForMediaItem extracts metadata and fetches info', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_vod_info') {
          return {
            'info': {
              'name': 'Extracted Movie',
              'cover_big': 'http://cdn.example.com/cover.jpg',
            },
          };
        }
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final item = MediaItem(
        id: 'xtream-movie-555',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.movie,
        title: 'Extracted Movie',
        metadata: {
          'streamId': '555',
          'serverUrl': server.baseUrl,
          'username': 'demo',
          'password': 'secret',
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final service = XtreamVodInfoService(logger: LoggingService());
      final info = await service.fetchForMediaItem(item);

      expect(info, isNotNull);
      expect(info?.name, 'Extracted Movie');
      expect(info?.poster, 'http://cdn.example.com/cover.jpg');
    });

    test('fetchForMediaItem extracts credentials from streamUrl when not in metadata', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_vod_info') {
          return {
            'info': {
              'name': 'StreamUrl Movie',
              'cover_big': 'http://cdn.example.com/stream_cover.jpg',
            },
          };
        }
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final item = MediaItem(
        id: 'xtream-movie-603963',
        providerId: 'p1',
        providerType: MediaSourceType.xtream,
        mediaType: MediaType.movie,
        title: 'StreamUrl Movie',
        metadata: {
          'streamUrl': '${server.baseUrl}/movie/demo/secret/603963.avi',
          'streamId': '603963',
          'serverUrl': server.baseUrl,
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final service = XtreamVodInfoService(logger: LoggingService());
      final info = await service.fetchForMediaItem(item);

      expect(info, isNotNull);
      expect(info?.name, 'StreamUrl Movie');
      expect(info?.poster, 'http://cdn.example.com/stream_cover.jpg');
    });

    test('cleanMovieTitle strips language prefixes, quality tags, and years cleanly', () {
      expect(XtreamVodInfoService.cleanMovieTitle('|DE| A Pure Place'), 'A Pure Place');
      expect(XtreamVodInfoService.cleanMovieTitle('|CN| 14 Blades'), '14 Blades');
      expect(XtreamVodInfoService.cleanMovieTitle('|EN| The Night House '), 'The Night House');
      expect(XtreamVodInfoService.cleanMovieTitle('[FR] Avatar (2022) 4K UHD'), 'Avatar');
      expect(XtreamVodInfoService.cleanMovieTitle('EN : Fast X 1080p FHD HEVC'), 'Fast X');
    });

    test('throws StreamResolutionException on 404', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        return null;
      });
      addTearDown(server.close);

      final service = XtreamVodInfoService(logger: LoggingService());
      expect(
        () => service.fetch(
          baseUrl: server.baseUrl,
          username: 'demo',
          password: 'secret',
          vodId: 'unknown',
        ),
        throwsA(isA<StreamResolutionException>()),
      );
    });
  });
}
