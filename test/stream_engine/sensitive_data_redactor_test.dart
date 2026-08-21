import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/streaming/security/sensitive_data_redactor.dart';

void main() {
  group('SensitiveDataRedactor.redactUrl', () {
    test('masks Xtream live path credentials', () {
      final result = SensitiveDataRedactor.redactUrl(
        'http://host:8080/live/myuser/mypass/2539.ts',
      );
      expect(result, isNot(contains('myuser')));
      expect(result, isNot(contains('mypass')));
      expect(result, contains('2539.ts'));
    });

    test('masks Xtream movie and series path credentials', () {
      expect(
        SensitiveDataRedactor.redactUrl(
          'http://host:8080/movie/user1/pass1/4321.mkv',
        ),
        isNot(anyOf(contains('user1'), contains('pass1'))),
      );
      expect(
        SensitiveDataRedactor.redactUrl(
          'http://host:8080/series/u2/p2/99/ep.mkv',
        ),
        isNot(anyOf(contains('/u2/'), contains('/p2/'))),
      );
    });

    test('is case-insensitive on the path prefix', () {
      final result = SensitiveDataRedactor.redactUrl(
        'http://host/LIVE/user/pass/2539.m3u8',
      );
      expect(result, isNot(contains('user/pass')));
    });

    test('leaves non-credential paths untouched', () {
      const url = 'http://cdn.example.com/videos/2539/index.m3u8';
      expect(SensitiveDataRedactor.redactUrl(url), url);
    });

    test('masks userinfo credentials', () {
      final result = SensitiveDataRedactor.redactUrl(
        'rtsp://admin:s3cret@cam.example.com/stream',
      );
      expect(result, isNot(contains('s3cret')));
      expect(result, contains('cam.example.com'));
    });

    test('masks sensitive query parameters', () {
      final result = SensitiveDataRedactor.redactUrl(
        'http://host/get.php?username=u1&password=p1&type=m3u_plus',
      );
      expect(result, isNot(contains('=u1&')));
      expect(result, isNot(contains('=p1')));
      expect(result, contains('type=m3u_plus'));
    });
  });

  group('SensitiveDataRedactor.redactHeaders', () {
    test('masks sensitive header values only', () {
      final redacted = SensitiveDataRedactor.redactHeaders(const {
        'Authorization': 'Bearer abc',
        'Cookie': 'sid=1',
        'User-Agent': 'UA',
      });
      expect(redacted['Authorization'], '[REDACTED]');
      expect(redacted['Cookie'], '[REDACTED]');
      expect(redacted['User-Agent'], 'UA');
    });
  });
}
