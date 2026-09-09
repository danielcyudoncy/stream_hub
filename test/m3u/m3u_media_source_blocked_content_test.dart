import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:stream_hub/core/media/enums/media_source_state.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/m3u_models.dart';
import 'package:stream_hub/data/providers/m3u/m3u_media_source.dart';
import 'package:stream_hub/data/services/m3u_download_service.dart';
import 'package:stream_hub/data/services/playlist_cache_service.dart';
import 'package:stream_hub/data/services/playlist_statistics_service.dart';
import '../xtream/xtream_test_server.dart' show defaultHandler;

const _validPlaylist =
    '#EXTM3U\n'
    '#EXTINF:-1 tvg-logo="https://logo.example/one.png" '
    'group-title="News",Test One\n'
    'http://stream.example/one.m3u8\n';

void main() {
  // NOTE: intentionally no TestWidgetsFlutterBinding.ensureInitialized() -
  // the widget binding replaces HttpOverrides with a client that answers 400,
  // which would bypass the real (loopback) HTTP server used by these tests.

  late Directory tempDir;
  HttpServer? server;
  PlaylistCacheService? cache;
  HttpServer? panel;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('m3u_blocked_content_test');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  tearDown(() async {
    await server?.close(force: true);
    server = null;
    await panel?.close(force: true);
    panel = null;
  });

  Future<M3UMediaSource> buildSource(Future<String> Function() body) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server!.listen((req) async {
      req.response.write(await body());
      await req.response.close();
    });

    final logger = LoggingService();
    cache = PlaylistCacheService(logger);
    await cache!.init();
    return M3UMediaSource(
      id: 'provider_123',
      config: M3UConfig(
        sourceUrl:
            'http://${server!.address.host}:${server!.port}/playlist.m3u',
      ),
      downloadService: M3UDownloadService(logger),
      cacheService: cache!,
      statisticsService: PlaylistStatisticsService(logger),
      logger: logger,
    );
  }

  group('M3UMediaSource blocked content handling', () {
    test('surfaces a blocked response as a failed sync', () async {
      final source = await buildSource(() async => 'Access Denied.');

      final result = await source.sync();

      expect(result.success, isFalse);
      expect(result.error, contains('blocked the playlist request'));
      expect(result.error, contains('Access Denied.'));
      expect(source.state, MediaSourceState.error);
    });

    test('does not clobber a previously-good cached playlist', () async {
      var blocked = false;
      final source = await buildSource(
        () async => blocked ? 'Access Denied.' : _validPlaylist,
      );

      final good = await source.sync();
      expect(good.success, isTrue);
      expect(await source.getChannels(), hasLength(1));

      blocked = true;
      final failed = await source.sync();
      expect(failed.success, isFalse);

      final cached = await cache!.getCachedPlaylist('provider_123');
      expect(cached, isNotNull);
      expect(cached!.channels.single.title, 'Test One');
      expect(source.state, MediaSourceState.error);
    });

    test(
      'flags a non-M3U body without an explicit block keyword as invalid',
      () async {
        final source = await buildSource(
          () async => '404 page not found on this server',
        );

        final result = await source.sync();

        expect(result.success, isFalse);
        expect(result.error, contains('not an M3U playlist'));
      },
    );

    test('treats a header-only playlist as a valid empty playlist', () async {
      final source = await buildSource(() async => '#EXTM3U\n');

      final result = await source.sync();

      expect(result.success, isTrue);
      expect(result.added, 0);
      expect(source.state, MediaSourceState.connected);
    });
  });

  group('M3UMediaSource Xtream panel fallback', () {
    // A bare-host M3U provider whose download is blocked but whose host also
    // answers `player_api.php` (an Xtream panel) should sync via the JSON API.
    late PlaylistCacheService panelCache;

    Future<M3UMediaSource> startPanelAndBuildSource({
      required int auth,
      required String status,
    }) async {
      panel = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      panel!.listen((req) async {
        if (req.uri.path == '/player_api.php') {
          final params = req.uri.queryParameters;
          final action = params['action'] ?? '';
          if (action.isEmpty) {
            req.response.headers.contentType = ContentType.json;
            req.response.write(
              json.encode({
                'user_info': {
                  'username': params['username'] ?? '',
                  'password': params['password'] ?? '',
                  'auth': auth,
                  'status': status,
                  'exp_date': '9999999999',
                },
              }),
            );
          } else {
            req.response.headers.contentType = ContentType.json;
            req.response.write(json.encode(defaultHandler(action, params)));
          }
        } else {
          req.response.write('Access Denied.');
        }
        await req.response.close();
      });

      final logger = LoggingService();
      panelCache = PlaylistCacheService(logger);
      await panelCache.init();
      return M3UMediaSource(
        id: 'provider_panel',
        config: M3UConfig(
          sourceUrl: 'http://127.0.0.1:${panel!.port}',
          username: 'paneluser',
          password: 'panelpass',
        ),
        downloadService: M3UDownloadService(logger),
        cacheService: panelCache,
        statisticsService: PlaylistStatisticsService(logger),
        logger: logger,
      );
    }

    test(
      'rescues a blocked bare-host provider into an Xtream panel sync',
      () async {
        final source = await startPanelAndBuildSource(
          auth: 1,
          status: 'Active',
        );

        final result = await source.sync();

        expect(result.success, isTrue);
        expect(await source.getChannels(), hasLength(2));
        expect(source.state, MediaSourceState.connected);
      },
    );

    test('does not rescue when the panel rejects the credentials', () async {
      final source = await startPanelAndBuildSource(auth: 0, status: 'Expired');

      final result = await source.sync();

      expect(result.success, isFalse);
      expect(result.error, contains('blocked the playlist request'));
      expect(source.state, MediaSourceState.error);
    });
  });
}
