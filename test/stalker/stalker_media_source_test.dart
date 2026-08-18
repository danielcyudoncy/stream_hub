import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/providers/stalker/stalker_media_source.dart';

import 'portal_test_server.dart';

void main() {
  group('StalkerMediaSource', () {
    test('syncs channels, movies, series, and episodes', () async {
      final server = await PortalTestServer.start(handler: defaultHandler);
      addTearDown(server.close);

      final source = StalkerMediaSource(
        id: 'provider_test',
        config: {
          'portalUrl': server.baseUrl,
          'macAddress': 'AA:BB:CC:DD:EE:FF',
        },
        logger: LoggingService(),
      );

      final result = await source.sync();

      expect(result.success, isTrue);
      expect(result.added, greaterThan(0));

      final channels = await source.getChannels();
      expect(channels, hasLength(2));
      expect(channels[0].mediaType, MediaType.channel);
      expect(channels[0].title, 'BBC One');
      expect(channels[0].metadata['type'], 'live');
      expect(channels[0].metadata['cmd'], isNotEmpty);
      expect(channels[0].genres, contains('News'));
      expect(channels[1].metadata['streamUrl'],
          'http://cdn.example.com/live/102.ts');

      final movies = await source.getMovies();
      expect(movies, hasLength(1));
      expect(movies[0].mediaType, MediaType.movie);
      expect(movies[0].title, 'Inception');
      expect(movies[0].rating, 8.8);

      final series = await source.getSeries();
      final seriesItems = series
          .where((item) => item.mediaType == MediaType.series)
          .toList();
      final episodes = series
          .where((item) => item.mediaType == MediaType.episode)
          .toList();
      expect(seriesItems, hasLength(1));
      expect(seriesItems[0].title, 'Breaking Bad');
      expect(episodes, hasLength(1));
      expect(episodes[0].title, 'Pilot');
      expect(episodes[0].metadata['type'], 'series');
      expect(episodes[0].metadata['cmd'], isNotEmpty);

      final categories = await source.getCategories();
      expect(categories, isNotEmpty);

      expect(source.accountMetadata, isNotNull);
      expect(source.accountMetadata?.status, isNotNull);

      final stats = await source.statistics();
      expect(stats.channels, 2);
      expect(stats.movies, 1);
      expect(stats.series, 1);
      expect(stats.episodes, 1);
    });

    test('reports rejection when the portal denies the MAC address', () async {
      final server = await PortalTestServer.start(
        handler: (action, params) {
          if (action == 'get_profile') {
            return {
              'js': {
                'data': {'id': '1', 'name': 'Denied', 'auth_status': '0'},
              },
            };
          }
          return defaultHandler(action, params);
        },
      );
      addTearDown(server.close);

      final source = StalkerMediaSource(
        id: 'provider_test',
        config: {
          'portalUrl': server.baseUrl,
          'macAddress': 'AA:BB:CC:DD:EE:FF',
        },
        logger: LoggingService(),
      );

      final result = await source.sync();

      expect(result.success, isFalse);
      expect(result.error, contains('MAC address'));
      expect(await source.getChannels(), isEmpty);
    });

    test('fails sync when the portal is unreachable', () async {
      final source = StalkerMediaSource(
        id: 'provider_test',
        config: {
          'portalUrl': 'http://127.0.0.1:1',
          'macAddress': 'AA:BB:CC:DD:EE:FF',
          'maxRetries': 0,
          'retryDelay': 1,
        },
        logger: LoggingService(),
      );

      final result = await source.sync();

      expect(result.success, isFalse);
      expect(result.error, isNotEmpty);
    });
  });
}
