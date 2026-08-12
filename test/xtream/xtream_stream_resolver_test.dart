import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/resolver/stream_resolver.dart';
import 'package:stream_hub/core/streaming/resolver/xtream_stream_resolver.dart';

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

  group('XtreamStreamResolver', () {
    test('resolves a live channel from its direct streamUrl', () async {
      final resolver = XtreamStreamResolver(logger: LoggingService());

      final result = await resolver.resolve(
        StreamResolutionRequest(
          session: session(),
          sourceUrl: 'http://panel.example.com',
          mediaItemId: 'xtream-live-101',
          itemMetadata: const {
            'streamUrl': 'http://panel.example.com/live/demo/secret/101.ts',
            'isLive': true,
          },
        ),
      );

      expect(result.url, 'http://panel.example.com/live/demo/secret/101.ts');
      expect(result.streamType, StreamType.mpegTs);
      expect(result.capabilities.supportsPause, isTrue);
    });

    test('resolves a VOD movie with VOD capabilities', () async {
      final resolver = XtreamStreamResolver(logger: LoggingService());

      final result = await resolver.resolve(
        StreamResolutionRequest(
          session: session(),
          sourceUrl: 'http://panel.example.com',
          mediaItemId: 'xtream-movie-501',
          itemMetadata: const {
            'streamUrl': 'http://panel.example.com/movie/demo/secret/501.mp4',
            'isVod': true,
          },
        ),
      );

      expect(result.url, 'http://panel.example.com/movie/demo/secret/501.mp4');
      expect(result.streamType, StreamType.mp4);
      expect(result.capabilities.supportsPause, isTrue);
      expect(result.capabilities.supportsSeeking, isTrue);
      expect(result.capabilities.supportsDownload, isTrue);
    });

    test('resolves a series through get_series_info and picks the first episode',
        () async {
      final server = await XtreamTestServer.start();
      addTearDown(server.close);

      final resolver = XtreamStreamResolver(logger: LoggingService());
      final result = await resolver.resolve(
        StreamResolutionRequest(
          session: session(baseUrl: server.baseUrl),
          sourceUrl: server.baseUrl,
          mediaItemId: 'xtream-series-601',
          itemMetadata: const {
            'seriesId': '601',
            'isSeries': true,
          },
        ),
      );

      expect(
        result.url,
        '${server.baseUrl}/series/demo/secret/7001.mp4',
      );
      expect(result.metadata['episodeId'], '7001');
      expect(result.metadata['episodeTitle'], 'Pilot');
      expect(result.capabilities.supportsPause, isTrue);
    });

    test('supports the episodes map layout from get_series_info', () async {
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

      final resolver = XtreamStreamResolver(logger: LoggingService());
      final result = await resolver.resolve(
        StreamResolutionRequest(
          session: session(baseUrl: server.baseUrl),
          sourceUrl: server.baseUrl,
          mediaItemId: 'xtream-series-700',
          itemMetadata: const {'seriesId': '700'},
        ),
      );

      expect(result.url, '${server.baseUrl}/series/demo/secret/8200.mp4');
      expect(result.metadata['episodeId'], '8200');
    });

    test('resolves a specific episode when episodeId is provided', () async {
      final server = await XtreamTestServer.start();
      addTearDown(server.close);

      final resolver = XtreamStreamResolver(logger: LoggingService());
      final result = await resolver.resolve(
        StreamResolutionRequest(
          session: session(baseUrl: server.baseUrl),
          sourceUrl: server.baseUrl,
          mediaItemId: 'xtream-episode-7101',
          itemMetadata: const {
            'seriesId': '601',
            'episodeId': '7101',
          },
        ),
      );

      expect(
        result.url,
        '${server.baseUrl}/series/demo/secret/7101.mkv',
      );
      expect(result.metadata['episodeId'], '7101');
      expect(result.metadata['episodeTitle'], 'Seven Thirty-Seven');
    });

    test('falls back to the first episode when episodeId is unknown', () async {
      final server = await XtreamTestServer.start();
      addTearDown(server.close);

      final resolver = XtreamStreamResolver(logger: LoggingService());
      final result = await resolver.resolve(
        StreamResolutionRequest(
          session: session(baseUrl: server.baseUrl),
          sourceUrl: server.baseUrl,
          mediaItemId: 'xtream-episode-9999',
          itemMetadata: const {
            'seriesId': '601',
            'episodeId': '9999',
          },
        ),
      );

      expect(result.url, '${server.baseUrl}/series/demo/secret/7001.mp4');
      expect(result.metadata['episodeId'], '7001');
    });

    test('resolves via the stream ID when the series ID 404s', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_series_info') {
          if (params['series_id'] == '601') return {'__status__': 404};
          return {
            'seasons': [
              {
                'id': '1',
                'name': 'Season 1',
                'episodes': [
                  {
                    'id': '9300',
                    'title': 'Stream ID Episode',
                    'container_extension': 'mp4',
                    'season': 1,
                    'episode_num': 1,
                  },
                ],
              },
            ],
          };
        }
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final resolver = XtreamStreamResolver(logger: LoggingService());
      final result = await resolver.resolve(
        StreamResolutionRequest(
          session: session(baseUrl: server.baseUrl),
          sourceUrl: server.baseUrl,
          mediaItemId: 'xtream-series-601',
          itemMetadata: const {
            'seriesId': '601',
            'streamId': '606',
            'isSeries': true,
          },
        ),
      );

      expect(result.url, '${server.baseUrl}/series/demo/secret/9300.mp4');
      expect(result.metadata['episodeId'], '9300');
    });

    test('throws when series info is unavailable for every candidate ID',
        () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_series_info') return {'__status__': 404};
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final resolver = XtreamStreamResolver(logger: LoggingService());

      await expectLater(
        resolver.resolve(
          StreamResolutionRequest(
            session: session(baseUrl: server.baseUrl),
            sourceUrl: server.baseUrl,
            mediaItemId: 'xtream-series-999',
            itemMetadata: const {
              'seriesId': '999',
              'streamId': '998',
            },
          ),
        ),
        throwsA(isA<StreamSeriesInfoUnavailableException>()),
      );
    });

    test('throws when no streamUrl or seriesId is present', () async {
      final resolver = XtreamStreamResolver(logger: LoggingService());

      expect(
        () => resolver.resolve(
          StreamResolutionRequest(
            session: session(),
            sourceUrl: 'http://panel.example.com',
            mediaItemId: 'xtream-live-999',
            itemMetadata: const <String, dynamic>{},
          ),
        ),
        throwsA(isA<StreamResolutionException>()),
      );
    });

    test('throws when there are no playable episodes', () async {
      final server = await XtreamTestServer.start(handler: (action, params) {
        if (action == 'get_series_info') {
          return {
            'seasons': <dynamic>[],
            'episodes': <String, dynamic>{},
          };
        }
        return defaultHandler(action, params);
      });
      addTearDown(server.close);

      final resolver = XtreamStreamResolver(logger: LoggingService());

      await expectLater(
        resolver.resolve(
          StreamResolutionRequest(
            session: session(baseUrl: server.baseUrl),
            sourceUrl: server.baseUrl,
            mediaItemId: 'xtream-series-999',
            itemMetadata: const {'seriesId': '999'},
          ),
        ),
        throwsA(isA<StreamResolutionException>()),
      );
    });

    test('throws for an unsupported protocol', () async {
      final resolver = XtreamStreamResolver(logger: LoggingService());

      expect(
        () => resolver.resolve(
          StreamResolutionRequest(
            session: session(),
            sourceUrl: 'http://panel.example.com',
            mediaItemId: 'xtream-live-101',
            itemMetadata: const {
              'streamUrl': 'ftp://panel.example.com/file.ts',
            },
          ),
        ),
        throwsA(isA<StreamUnsupportedProtocolException>()),
      );
    });
  });
}
