import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/network/url_normalizer.dart';

void main() {
  group('UrlNormalizer', () {
    late UrlNormalizer normalizer;

    setUp(() {
      normalizer = UrlNormalizer();
    });

    group('parse', () {
      test('accepts supported schemes', () {
        expect(
          normalizer.isSupported('https://example.com/stream.m3u8'),
          isTrue,
        );
        expect(normalizer.isSupported('http://example.com/stream.ts'), isTrue);
        expect(normalizer.isSupported('rtsp://example.com/live'), isTrue);
      });

      test('rejects malformed URLs', () {
        expect(
          () => normalizer.parse('not a url'),
          throwsA(isA<StreamMalformedUrlException>()),
        );
      });

      test('rejects unsupported protocols', () {
        expect(
          () => normalizer.parse('ftp://example.com/file'),
          throwsA(isA<StreamUnsupportedProtocolException>()),
        );
      });
    });

    group('canonicalize', () {
      test('lowercases scheme and host, drops fragment', () {
        expect(
          normalizer.canonicalize('HTTP://EXAMPLE.com/Stream.M3U8#frag'),
          'http://example.com/Stream.M3U8',
        );
      });

      test('strips empty query parameters', () {
        expect(
          normalizer.canonicalize('https://example.com/stream?keep=1&empty='),
          'https://example.com/stream?keep=1',
        );
      });
    });

    group('resolveRelative', () {
      test('returns absolute URLs unchanged', () {
        expect(
          normalizer.resolveRelative(
            'https://cdn.example.com/stream.ts',
            'https://example.com/playlist.m3u8',
          ),
          'https://cdn.example.com/stream.ts',
        );
      });

      test('resolves relative URLs against the base', () {
        expect(
          normalizer.resolveRelative(
            'stream.ts',
            'https://example.com/playlist.m3u8',
          ),
          'https://example.com/stream.ts',
        );
      });

      test('returns relative URL when no valid base exists', () {
        expect(normalizer.resolveRelative('stream.ts', ''), 'stream.ts');
      });
    });

    group('removeDuplicateParameters', () {
      test('keeps the last value for duplicate parameters', () {
        expect(
          normalizer.removeDuplicateParameters(
            'https://example.com/stream?token=a&token=b',
          ),
          'https://example.com/stream?token=b',
        );
      });
    });

    group('stripUserInfo', () {
      test('extracts embedded credentials', () {
        final result = normalizer.stripUserInfo(
          'https://user:pass@example.com/stream',
        );
        expect(result.url, 'https://example.com/stream');
        expect(result.userInfo, 'user:pass');
      });

      test('returns url unchanged when no user info present', () {
        final result = normalizer.stripUserInfo('https://example.com/stream');
        expect(result.url, 'https://example.com/stream');
        expect(result.userInfo, isNull);
      });
    });
  });
}
