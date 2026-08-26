import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_state.dart';
import 'package:stream_hub/data/models/m3u_models.dart';
import 'package:stream_hub/data/providers/m3u/m3u_media_source.dart';
import 'package:stream_hub/data/services/m3u_download_service.dart';
import 'package:stream_hub/data/services/playlist_cache_service.dart';
import 'package:stream_hub/data/services/playlist_statistics_service.dart';
import '../xtream/xtream_test_server.dart';

void main() {
  M3UMediaSource buildSource(String url) {
    final logger = LoggingService();
    return M3UMediaSource(
      id: 'p1',
      config: M3UConfig(sourceUrl: url),
      downloadService: M3UDownloadService(logger),
      cacheService: PlaylistCacheService(logger),
      statisticsService: PlaylistStatisticsService(logger),
      logger: logger,
    );
  }

  group('M3UMediaSource (Xtream export delegation)', () {
    test('syncs through the Xtream JSON API for get.php export links', () async {
      final server = await XtreamTestServer.start();
      addTearDown(server.close);

      final source = buildSource(
        '${server.baseUrl}/get.php?username=demo&password=secret&type=m3u_plus',
      );

      final result = await source.sync();

      expect(result.success, isTrue);
      expect(source.state, MediaSourceState.connected);

      expect(server.lastUsername, 'demo');
      expect(server.lastPassword, 'secret');

      final channels = await source.getChannels();
      expect(channels, hasLength(2));
      expect(channels.first.id, 'xtream-live-101');

      final movies = await source.getMovies();
      expect(movies, hasLength(1));

      final series = await source.getSeries();
      expect(series, hasLength(1));

      final stats = await source.statistics();
      expect(stats.channels, 2);
      expect(stats.movies, 1);

      final meta = source.accountMetadata;
      expect(meta, isNotNull);
      expect(meta!.status, 'Active');
    });

    test('falls back to config credentials when the URL has none', () async {
      final server = await XtreamTestServer.start();
      addTearDown(server.close);

      final logger = LoggingService();
      final source = M3UMediaSource(
        id: 'p1',
        config: M3UConfig(
          sourceUrl: '${server.baseUrl}/get.php?type=m3u_plus',
          username: 'alice',
          password: 'hunter2',
        ),
        downloadService: M3UDownloadService(logger),
        cacheService: PlaylistCacheService(logger),
        statisticsService: PlaylistStatisticsService(logger),
        logger: logger,
      );

      await source.sync();

      expect(server.lastUsername, 'alice');
      expect(server.lastPassword, 'hunter2');
    });
  });
}
