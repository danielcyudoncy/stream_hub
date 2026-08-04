import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/data/providers/xtream/xtream_url_detector.dart';

void main() {
  group('XtreamUrlDetector', () {
    test('parses a get.php export link', () {
      final parts = XtreamUrlDetector.parse(
        'http://iptv.example:8080/get.php?username=HUCYOMZQTS&password=NBUU1YNM67&type=m3u_plus',
      );

      expect(parts, isNotNull);
      expect(parts!.serverUrl, 'http://iptv.example:8080');
      expect(parts.username, 'HUCYOMZQTS');
      expect(parts.password, 'NBUU1YNM67');
    });

    test('parses a schemeless get.php export link', () {
      final parts = XtreamUrlDetector.parse(
        'iptv.example:8080/get.php?username=user&password=pass&output=ts',
      );

      expect(parts, isNotNull);
      expect(parts!.serverUrl, 'http://iptv.example:8080');
      expect(parts.username, 'user');
      expect(parts.password, 'pass');
    });

    test('parses a player_api.php link with inline credentials', () {
      final parts = XtreamUrlDetector.parse(
        'https://iptv.example/player_api.php?username=u&password=p',
      );

      expect(parts, isNotNull);
      expect(parts!.serverUrl, 'https://iptv.example');
      expect(parts.username, 'u');
      expect(parts.password, 'p');
    });

    test('rejects a plain M3U playlist URL', () {
      expect(
        XtreamUrlDetector.parse('http://example.com/playlist.m3u'),
        isNull,
      );
      expect(XtreamUrlDetector.isXtreamExport('http://example.com/live.m3u8'),
          isFalse);
    });

    test('parses an API path URL even without inline credentials', () {
      final parts = XtreamUrlDetector.parse(
        'http://iptv.example:8080/get.php?output=ts',
      );

      expect(parts, isNotNull);
      expect(parts!.serverUrl, 'http://iptv.example:8080');
      expect(parts.username, isNull);
      expect(parts.password, isNull);
    });

    test('rejects empty and malformed input', () {
      expect(XtreamUrlDetector.parse(null), isNull);
      expect(XtreamUrlDetector.parse(''), isNull);
      expect(XtreamUrlDetector.parse('   '), isNull);
      expect(XtreamUrlDetector.parse('not a url'), isNull);
    });
  });
}
