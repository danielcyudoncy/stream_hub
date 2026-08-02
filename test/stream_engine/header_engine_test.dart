import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/streaming/network/header_engine.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';

void main() {
  group('HeaderEngine', () {
    group('buildHeaders', () {
      test('includes default identity headers', () {
        final headers = HeaderEngine().buildHeaders();
        expect(headers['Accept'], '*/*');
        expect(headers['Accept-Language'], isNotNull);
        expect(headers['User-Agent'], HeaderEngine.kDefaultUserAgent);
      });

      test('applies user agent, referer, and origin', () {
        final headers = HeaderEngine().buildHeaders(
          userAgent: 'TestUA/2.0',
          referer: 'https://example.com',
          origin: 'https://example.com',
        );
        expect(headers['User-Agent'], 'TestUA/2.0');
        expect(headers['Referer'], 'https://example.com');
        expect(headers['Origin'], 'https://example.com');
      });

      test('adds bearer token and cookies', () {
        final headers = HeaderEngine().buildHeaders(
          bearerToken: 'secret-token',
          cookies: const {'session': 'abc123'},
        );
        expect(headers['Authorization'], 'Bearer secret-token');
        expect(headers['Cookie'], 'session=abc123');
      });

      test('custom headers override built-in values', () {
        final headers = HeaderEngine().buildHeaders(
          userAgent: 'Default',
          custom: const {'User-Agent': 'Override'},
        );
        expect(headers['User-Agent'], 'Override');
      });

      test('rejects header values with line breaks', () {
        expect(
          () => HeaderEngine().buildHeaders(
            custom: const {'X-Foo': 'bar\r\nInjected: 1'},
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('serializes and parses cookies', () {
        const cookies = {'a': '1', 'b': '2'};
        final serialized = HeaderEngine.serializeCookies(cookies);
        expect(serialized, 'a=1; b=2');
        expect(HeaderEngine.parseCookies(serialized), cookies);
      });

      test('basicAuth produces expected header', () {
        final expected = 'Basic ${base64Encode(utf8.encode('user:pass'))}';
        expect(HeaderEngine.basicAuth('user', 'pass'), expected);
      });

      test('redacted hides sensitive values', () {
        final redacted = HeaderEngine().redacted(const {
          'Authorization': 'Bearer token',
          'Cookie': 'session=abc',
          'User-Agent': 'UA',
        });
        expect(redacted['Authorization'], '[REDACTED]');
        expect(redacted['Cookie'], '[REDACTED]');
        expect(redacted['User-Agent'], 'UA');
      });
    });
  });

  group('CookieManager.serializeCookies', () {
    test('joins cookies with separator', () {
      expect(
        CookieManager.serializeCookies(const {'x': 'y', 'z': 'w'}),
        'x=y; z=w',
      );
    });
  });
}
