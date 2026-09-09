import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/remote/free_tv_m3u_remote_data_source.dart';
import 'package:stream_hub/data/sources/free_tv_sources.dart';

class _RecordingLogger extends LoggingService {
  final List<String> logs = [];

  @override
  void info(String message, {String? tag}) {
    logs.add('INFO: $message');
  }

  @override
  void warning(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    logs.add('WARNING: $message');
  }

  @override
  void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    logs.add('ERROR: $message');
  }
}

void main() {
  group('CustomM3uFreeTvRemoteDataSource', () {
    late HttpServer server;
    late String fixtureContent;

    setUpAll(() {
      fixtureContent = File('test/fixtures/sample_portal5458.m3u').readAsStringSync();
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('successfully fetches and normalizes M3U channels', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) {
        request.response.headers.contentType = ContentType.text;
        request.response.write(fixtureContent);
        request.response.close();
      });

      final source = FreeTvSource(
        id: 'test_m3u',
        name: 'Test M3U',
        url: 'http://${server.address.host}:${server.port}/get.php?username=spehar6&password=2934778645&type=m3u_plus',
        kind: FreeTvSourceKind.global,
      );

      final dataSource = CustomM3uFreeTvRemoteDataSource(
        source: source,
        httpClient: HttpClient(),
      );

      final channels = await dataSource.fetchOnlineChannels();

      // In fixture: BBC.UK@HD, CNN.US@SD, ESPN.US@HD, and Unknown Channel (4 valid channels)
      expect(channels.length, 4);

      final bbc = channels.firstWhere((c) => c.id == 'BBC');
      expect(bbc.name, 'BBC One');
      expect(bbc.countryCode, 'UK');
      expect(bbc.categories, contains('News'));
      expect(bbc.streamUrls.first, 'http://portal5458.com:8080/live/bbc.m3u8');
      expect(bbc.streams.first.url, 'http://portal5458.com:8080/live/bbc.m3u8');
      expect(bbc.languages, contains('English'));

      final cnn = channels.firstWhere((c) => c.id == 'CNN');
      expect(cnn.name, 'CNN');
      expect(cnn.countryCode, 'US');

      final espn = channels.firstWhere((c) => c.id == 'ESPN');
      expect(espn.name, 'ESPN');
      expect(espn.countryCode, 'US');
      expect(espn.categories, contains('Sports'));

      final unknown = channels.firstWhere((c) => c.name == 'Unknown Channel');
      expect(unknown.id, isNotEmpty);
      expect(unknown.streamUrls.first, 'http://portal5458.com:8080/live/unknown.m3u8');
    });

    test('handles request timeout gracefully by returning empty list', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        // Intentionally delay longer than the timeout
        await Future.delayed(const Duration(milliseconds: 300));
        request.response.write(fixtureContent);
        request.response.close();
      });

      final source = FreeTvSource(
        id: 'timeout_test',
        name: 'Timeout Test',
        url: 'http://${server.address.host}:${server.port}/delayed.m3u',
        kind: FreeTvSourceKind.global,
      );

      final dataSource = CustomM3uFreeTvRemoteDataSource(
        source: source,
        httpClient: HttpClient(),
      );

      final channels = await dataSource.fetchOnlineChannels(
        timeout: const Duration(milliseconds: 50),
      );

      expect(channels, isEmpty);
    });

    test('handles HTTP 404 and 500 error responses gracefully', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) {
        if (request.uri.path.contains('not_found')) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.statusCode = HttpStatus.internalServerError;
        }
        request.response.close();
      });

      final source404 = FreeTvSource(
        id: '404_test',
        name: '404 Test',
        url: 'http://${server.address.host}:${server.port}/not_found.m3u',
        kind: FreeTvSourceKind.global,
      );

      final dataSource404 = CustomM3uFreeTvRemoteDataSource(
        source: source404,
        httpClient: HttpClient(),
      );

      final channels404 = await dataSource404.fetchOnlineChannels();
      expect(channels404, isEmpty);

      final source500 = FreeTvSource(
        id: '500_test',
        name: '500 Test',
        url: 'http://${server.address.host}:${server.port}/server_error.m3u',
        kind: FreeTvSourceKind.global,
      );

      final dataSource500 = CustomM3uFreeTvRemoteDataSource(
        source: source500,
        httpClient: HttpClient(),
      );

      final channels500 = await dataSource500.fetchOnlineChannels();
      expect(channels500, isEmpty);
    });

    test('handles malformed and empty M3U content gracefully', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) {
        request.response.write('Not a valid M3U\nRandom text here\nAnother line');
        request.response.close();
      });

      final source = FreeTvSource(
        id: 'malformed_test',
        name: 'Malformed Test',
        url: 'http://${server.address.host}:${server.port}/invalid.m3u',
        kind: FreeTvSourceKind.global,
      );

      final dataSource = CustomM3uFreeTvRemoteDataSource(
        source: source,
        httpClient: HttpClient(),
      );

      final channels = await dataSource.fetchOnlineChannels();
      expect(channels, isEmpty);
    });

    test('overrides country code when source is a country playlist', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) {
        request.response.write(fixtureContent);
        request.response.close();
      });

      final source = FreeTvSource(
        id: 'country_override_test',
        name: 'Country Override Test',
        url: 'http://${server.address.host}:${server.port}/override.m3u',
        kind: FreeTvSourceKind.country,
        countryCode: 'CA',
      );

      final dataSource = CustomM3uFreeTvRemoteDataSource(
        source: source,
        httpClient: HttpClient(),
      );

      final channels = await dataSource.fetchOnlineChannels();
      final unknown = channels.firstWhere((c) => c.name == 'Unknown Channel');
      // The unknown channel did not have a tvg-id country, so it picks up the source countryCode override
      expect(unknown.countryCode, 'CA');
    });

    test('never logs credentials embedded in provider URL', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.close();
      });

      final logger = _RecordingLogger();
      final source = FreeTvSource(
        id: 'safe_log_test',
        name: 'Safe Log Test',
        url: 'http://${server.address.host}:${server.port}/get.php?username=spehar6&password=2934778645&type=m3u_plus',
        kind: FreeTvSourceKind.global,
      );

      final dataSource = CustomM3uFreeTvRemoteDataSource(
        source: source,
        httpClient: HttpClient(),
        logger: logger,
      );

      await dataSource.fetchOnlineChannels();

      expect(logger.logs, isNotEmpty);
      for (final logMessage in logger.logs) {
        expect(logMessage, isNot(contains('spehar6')));
        expect(logMessage, isNot(contains('2934778645')));
        expect(logMessage, isNot(contains('password=')));
      }
    });

    test('Xtream fallback attaches portal headers and uses neutral labeling when categories are unknown',
        () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) {
        if (request.uri.path == '/get.php') {
          request.response.statusCode = HttpStatus.notFound;
        } else if (request.uri.path == '/player_api.php') {
          final action = request.uri.queryParameters['action'];
          if (action == 'get_live_categories') {
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              '[{"category_id":"1","category_name":"UK - Entertainment"},'
              '{"category_id":"2","category_name":"US - News"}]',
            );
          } else if (action == 'get_live_streams') {
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              '[{"stream_id":101,"name":"BBC One","category_id":"1","stream_icon":""},'
              '{"stream_id":202,"name":"Mystery Feed","category_id":"999","stream_icon":""}]',
            );
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        request.response.close();
      });

      final source = FreeTvSource(
        id: 'portal5458',
        name: 'Portal 5458',
        url:
            'http://${server.address.host}:${server.port}/get.php?username=spehar6&password=2934778645&type=m3u_plus',
        kind: FreeTvSourceKind.global,
      );

      final dataSource = CustomM3uFreeTvRemoteDataSource(
        source: source,
        httpClient: HttpClient(),
      );

      final channels = await dataSource.fetchOnlineChannels();
      expect(channels.length, 2);

      final origin = 'http://${server.address.host}:${server.port}';

      // Resolved category drives country/region labels.
      final bbc = channels.firstWhere((c) => c.id == 'portal5458_101');
      expect(bbc.name, 'BBC One');
      expect(bbc.country, 'United Kingdom');
      expect(bbc.countryCode, 'GB');
      expect(bbc.region, 'Europe');
      expect(
        bbc.streams.first.url,
        '$origin/live/spehar6/2934778645/101.ts',
      );
      // Header injection: portal origin Referer + portal-conformant User-Agent.
      expect(bbc.streams.first.referrer, origin);
      expect(bbc.streams.first.userAgent, 'IPTVSmartersPro/1.0');

      // Unresolvable category must fall into a neutral bucket, never a fabricated country.
      final mystery = channels.firstWhere((c) => c.id == 'portal5458_202');
      expect(mystery.country, 'International');
      expect(mystery.countryCode, 'ZZ');
      expect(mystery.region, 'Worldwide');
      expect(mystery.streams.first.referrer, origin);
    });

    test('unimplemented secondary methods return empty lists', () async {
      final source = const FreeTvSource(
        id: 'unimplemented_test',
        name: 'Unimplemented Test',
        url: 'http://127.0.0.1:8080/get.php',
        kind: FreeTvSourceKind.global,
      );
      final dataSource = CustomM3uFreeTvRemoteDataSource(source: source);

      expect(await dataSource.fetchCountries(), isEmpty);
      expect(await dataSource.fetchCategories(), isEmpty);
      expect(await dataSource.fetchChannelsByCountry('US'), isEmpty);
      expect(await dataSource.fetchChannelsByCategory('news'), isEmpty);
    });
  });
}
