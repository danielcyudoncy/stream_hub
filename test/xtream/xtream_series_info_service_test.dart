import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/series/xtream_series_info_service.dart';

import 'xtream_test_server.dart';

void main() {
  ProviderSession session({String? baseUrl}) {
    return ProviderSession(
      providerId: 'p1',
      providerType: MediaSourceType.xtream,
      sessionId: 's1',
      baseUrl: baseUrl ?? 'http://panel.example.com',
      username: 'demo',
      password: 'secret',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  group('XtreamSeriesInfoService', () {
    test('parses the seasons layout into ordered seasons and episodes', () async {
      final server = await XtreamTestServer.start();
      addTearDown(server.close);

      final service = XtreamSeriesInfoService(logger: LoggingService());
      final info = await service.fetch(
        session: session(baseUrl: server.baseUrl),
        seriesId: '601',
      );

      expect(info.seasonCount, 2);
      expect(info.totalEpisodes, 3);
      expect(info.seasons[0].number, 1);
      expect(info.seasons[0].name, 'Season 1');
      expect(info.seasons[0].episodes.length, 2);
      expect(info.seasons[0].episodes[0].title, 'Pilot');
      expect(info.seasons[0].episodes[0].seasonNum, 1);
      expect(info.seasons[0].episodes[0].episodeNum, 1);
      expect(info.seasons[1].episodes[0].extension, 'mkv');
    });

    test('supports the episodes map layout', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_series_info') {
          return {
            'episodes': {
              '1': [
                {
                  'id': '8200',
                  'title': 'Early Season Episode',
                  'container_extension': 'mp4',
                  'season': 1,
                  'episode_num': 1,
                },
              ],
            },
          };
        }
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final service = XtreamSeriesInfoService(logger: LoggingService());
      final info = await service.fetch(
        session: session(baseUrl: server.baseUrl),
        seriesId: '700',
      );

      expect(info.seasonCount, 1);
      expect(info.seasons[0].number, 1);
      expect(info.seasons[0].episodes.single.id, '8200');
    });

    test('parses plot, cover, and duration from episode info objects', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_series_info') {
          return {
            'seasons': [
              {
                'id': 1,
                'name': 'Season 1',
                'episodes': [
                  {
                    'id': '7001',
                    'title': 'Pilot',
                    'container_extension': 'mp4',
                    'season': 1,
                    'episode_num': 1,
                    'duration': '00:42:00',
                    'info': {
                      'plot': 'A deep plot summary.',
                      'movie_image': 'http://cdn.example.com/ep1.jpg',
                    },
                  },
                ],
              },
            ],
          };
        }
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final service = XtreamSeriesInfoService(logger: LoggingService());
      final info = await service.fetch(
        session: session(baseUrl: server.baseUrl),
        seriesId: '601',
      );

      final episode = info.seasons[0].episodes.single;
      expect(episode.plot, 'A deep plot summary.');
      expect(episode.cover, 'http://cdn.example.com/ep1.jpg');
      expect(episode.durationSeconds, 42 * 60);
    });

    test('builds authenticated stream URLs from session credentials', () {
      final episode = const XtreamSeriesEpisode(
        id: '7001',
        title: 'Pilot',
        extension: 'mp4',
        seasonNum: 1,
        episodeNum: 1,
      );

      final url = episode.streamUrl(
        baseUrl: 'http://panel.example.com',
        username: 'demo',
        password: 'secret',
      );

      expect(url, 'http://panel.example.com/series/demo/secret/7001.mp4');
    });

    test('falls back to an alternative ID when the series ID 404s', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_series_info') {
          if (params['series_id'] == '900') return {'__status__': 404};
          if (params['series_id'] == '905') {
            return {
              'seasons': [
                {
                  'id': '1',
                  'name': 'Season 1',
                  'episodes': [
                    {
                      'id': '9001',
                      'title': 'Resolved via stream ID',
                      'container_extension': 'mp4',
                      'season': 1,
                      'episode_num': 1,
                    },
                  ],
                },
              ],
            };
          }
        }
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final service = XtreamSeriesInfoService(logger: LoggingService());
      final info = await service.fetch(
        session: session(baseUrl: server.baseUrl),
        seriesId: '900',
        alternativeIds: const ['905'],
      );

      expect(info.seasonCount, 1);
      expect(info.seasons[0].episodes.single.id, '9001');
    });

    test('throws StreamSeriesInfoUnavailableException when every ID 404s',
        () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_series_info') return {'__status__': 404};
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final service = XtreamSeriesInfoService(logger: LoggingService());

      await expectLater(
        service.fetch(
          session: session(baseUrl: server.baseUrl),
          seriesId: '900',
          alternativeIds: const ['905'],
        ),
        throwsA(isA<StreamSeriesInfoUnavailableException>()),
      );
    });

    test('unwraps a data-wrapped get_series_info payload', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_series_info') {
          return {
            'data': {
              'seasons': [
                {
                  'id': '1',
                  'name': 'Season 1',
                  'episodes': [
                    {
                      'id': '9100',
                      'title': 'Wrapped Episode',
                      'container_extension': 'mkv',
                      'season': 1,
                      'episode_num': 1,
                    },
                  ],
                },
              ],
            },
          };
        }
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final service = XtreamSeriesInfoService(logger: LoggingService());
      final info = await service.fetch(
        session: session(baseUrl: server.baseUrl),
        seriesId: '601',
      );

      expect(info.seasonCount, 1);
      expect(info.seasons[0].episodes.single.id, '9100');
    });

    test('throws when the session has no server URL', () async {
      final service = XtreamSeriesInfoService(logger: LoggingService());

      await expectLater(
        service.fetch(
          session: ProviderSession(
            providerId: 'p1',
            providerType: MediaSourceType.xtream,
            sessionId: 's1',
            username: 'demo',
            password: 'secret',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
          seriesId: '601',
        ),
        throwsA(isA<StreamResolutionException>()),
      );
    });

    test('throws StreamNetworkException on connection failure', () async {
      final service = XtreamSeriesInfoService(logger: LoggingService());

      await expectLater(
        service.fetch(
          session: session(baseUrl: 'http://127.0.0.1:1'),
          seriesId: '601',
        ),
        throwsA(isA<StreamNetworkException>()),
      );
    });

    test('parses a seasons map keyed by season number without inner ids',
        () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_series_info') {
          return {
            'seasons': {
              '1': {
                'name': 'Season 1',
                'episodes': [
                  {
                    'id': '8301',
                    'title': 'Keyed Season Episode',
                    'container_extension': 'mp4',
                    'season': 1,
                    'episode_num': 1,
                  },
                ],
              },
            },
          };
        }
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final service = XtreamSeriesInfoService(logger: LoggingService());
      final info = await service.fetch(
        session: session(baseUrl: server.baseUrl),
        seriesId: '601',
      );

      expect(info.seasonCount, 1);
      expect(info.seasons[0].number, 1);
      expect(info.seasons[0].name, 'Season 1');
      expect(info.seasons[0].episodes.single.id, '8301');
    });

    test('parses episodes emitted as a map keyed by episode number', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_series_info') {
          return {
            'seasons': [
              {
                'id': '1',
                'name': 'Season 1',
                'episodes': {
                  '1': {
                    'id': '8401',
                    'title': 'Mapped Episode',
                    'container_extension': 'mp4',
                    'season': 1,
                    'episode_num': 1,
                  },
                },
              },
            ],
          };
        }
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final service = XtreamSeriesInfoService(logger: LoggingService());
      final info = await service.fetch(
        session: session(baseUrl: server.baseUrl),
        seriesId: '601',
      );

      expect(info.seasonCount, 1);
      expect(info.seasons[0].episodes.single.id, '8401');
    });

    test('parses a flat top-level episodes list with per-episode seasons',
        () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_series_info') {
          return {
            'episodes': [
              {
                'id': '8502',
                'title': 'Flat Season Two',
                'container_extension': 'mkv',
                'season': 2,
                'episode_num': 1,
              },
              {
                'id': '8501',
                'title': 'Flat Season One',
                'container_extension': 'mp4',
                'season': 1,
                'episode_num': 1,
              },
            ],
          };
        }
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final service = XtreamSeriesInfoService(logger: LoggingService());
      final info = await service.fetch(
        session: session(baseUrl: server.baseUrl),
        seriesId: '601',
      );

      expect(info.seasonCount, 2);
      expect(info.seasons[0].number, 1);
      expect(info.seasons[0].episodes.single.id, '8501');
      expect(info.seasons[1].number, 2);
      expect(info.seasons[1].episodes.single.id, '8502');
    });

    test('falls back to a numeric-only id when the raw id 404s', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_series_info') {
          if (params['series_id'] == 'S-601') return {'__status__': 404};
          if (params['series_id'] == '601') {
            return {
              'seasons': [
                {
                  'id': '1',
                  'name': 'Season 1',
                  'episodes': [
                    {
                      'id': '8601',
                      'title': 'Resolved via numeric id',
                      'container_extension': 'mp4',
                      'season': 1,
                      'episode_num': 1,
                    },
                  ],
                },
              ],
            };
          }
        }
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final service = XtreamSeriesInfoService(logger: LoggingService());
      final info = await service.fetch(
        session: session(baseUrl: server.baseUrl),
        seriesId: 'S-601',
      );

      expect(info.seasonCount, 1);
      expect(info.seasons[0].episodes.single.id, '8601');
    });

    test('treats an empty 200 body as unavailable and continues to the next '
        'candidate', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_series_info') {
          if (params['series_id'] == '900') return {'__empty__': true};
          if (params['series_id'] == '905') {
            return {
              'seasons': [
                {
                  'id': '1',
                  'name': 'Season 1',
                  'episodes': [
                    {
                      'id': '8701',
                      'title': 'Resolved after empty body',
                      'container_extension': 'mp4',
                      'season': 1,
                      'episode_num': 1,
                    },
                  ],
                },
              ],
            };
          }
        }
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final service = XtreamSeriesInfoService(logger: LoggingService());
      final info = await service.fetch(
        session: session(baseUrl: server.baseUrl),
        seriesId: '900',
        alternativeIds: const ['905'],
      );

      expect(info.seasonCount, 1);
      expect(info.seasons[0].episodes.single.id, '8701');
    });

    test('throws StreamSeriesInfoUnavailableException when every candidate '
        'answers with an empty body', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_series_info') return {'__empty__': true};
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final service = XtreamSeriesInfoService(logger: LoggingService());

      await expectLater(
        service.fetch(
          session: session(baseUrl: server.baseUrl),
          seriesId: '900',
          alternativeIds: const ['905'],
        ),
        throwsA(isA<StreamSeriesInfoUnavailableException>()),
      );
    });
  });
}
