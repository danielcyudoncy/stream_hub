import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';

void main() {
  group('DohResolver', () {
    late HttpServer dohServer;
    late int dohPort;
    int aQueries = 0;
    int aaaaQueries = 0;

    setUp(() async {
      aQueries = 0;
      aaaaQueries = 0;
      dohServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      dohPort = dohServer.port;
      dohServer.listen((request) async {
        final params = request.uri.queryParameters;
        final name = params['name'] ?? '';
        final type = params['type'] ?? '';
        final response = request.response;
        response.headers.contentType = ContentType.json;
        if (type == '1') {
          aQueries++;
          final nx = name.startsWith('nx.');
          response.write(
            json.encode({
              'Status': nx ? 3 : 0,
              'Answer': nx
                  ? []
                  : [
                      {'type': 1, 'data': '127.0.0.1'},
                    ],
            }),
          );
        } else {
          aaaaQueries++;
          response.write(
            json.encode({
              'Status': 0,
              'Answer': [
                {'type': 28, 'data': '::1'},
              ],
            }),
          );
        }
        await response.close();
      });
    });

    tearDown(() async {
      await dohServer.close(force: true);
    });

    DohResolver resolver() => DohResolver(
          endpoints: [
            'http://127.0.0.1:$dohPort/dns-query?name={host}&type={type}',
          ],
        );

    test('parses A records into addresses', () async {
      final addresses = await resolver().resolve('example.test');
      expect(addresses.map((a) => a.address), contains('127.0.0.1'));
    });

    test('caches results and skips duplicate queries', () async {
      final r = resolver();
      final first = await r.resolve('example.test');
      final second = await r.resolve('example.test');
      expect(first, hasLength(1));
      expect(second, hasLength(1));
      expect(aQueries, 1);
      expect(aaaaQueries, 0);
    });

    test('falls back to AAAA when no A record exists', () async {
      final addresses = await resolver().resolve('nx.example.test');
      expect(addresses.map((a) => a.address), contains('::1'));
    });

    test('returns empty list when every endpoint is unreachable', () async {
      final closed = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = closed.port;
      await closed.close(force: true);

      final r = DohResolver(
        endpoints: [
          'http://127.0.0.1:$deadPort/dns-query?name={host}&type={type}',
        ],
      );
      expect(await r.resolve('example.test'), isEmpty);
    });
  });

  group('createDohAwareHttpClient', () {
    late HttpServer dohServer;
    late HttpServer origin;
    late int dohPort;
    late int originPort;

    setUp(() async {
      dohServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      dohPort = dohServer.port;
      dohServer.listen((request) async {
        final response = request.response;
        response.headers.contentType = ContentType.json;
        response.write(
          json.encode({
            'Status': 0,
            'Answer': [
              {'type': 1, 'data': '127.0.0.1'},
            ],
          }),
        );
        await response.close();
      });

      origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      originPort = origin.port;
      origin.listen((request) async {
        final response = request.response;
        response.write('hello');
        await response.close();
      });
    });

    tearDown(() async {
      await dohServer.close(force: true);
      await origin.close(force: true);
    });

    test('reaches a hostname that fails the platform resolver via DoH', () async {
      final resolver = DohResolver(
        endpoints: [
          'http://127.0.0.1:$dohPort/dns-query?name={host}&type={type}',
        ],
      );
      final client = createDohAwareHttpClient(resolver: resolver)
        ..findProxy = (_) => 'DIRECT';

      try {
        final request =
            await client.getUrl(Uri.parse('http://doesnotexist.invalid:$originPort/'));
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);
        final body = await response.transform(utf8.decoder).join();
        expect(body, 'hello');
      } finally {
        client.close(force: true);
      }
    });
  });
}
