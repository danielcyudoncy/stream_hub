import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';

void main() {
  group('CookieManager', () {
    late CookieManager manager;

    setUp(() {
      manager = CookieManager();
    });

    test('sets and gets cookies per provider', () {
      manager.setCookie('p1', 'session', 'abc');
      manager.setCookie('p1', 'theme', 'dark');
      manager.setCookie('p2', 'other', 'x');

      expect(manager.getCookie('p1', 'session'), 'abc');
      expect(manager.getCookie('p1', 'theme'), 'dark');
      expect(manager.getCookie('p2', 'other'), 'x');
      expect(manager.getCookie('p2', 'session'), isNull);
    });

    test('setCookies stores a whole map', () {
      manager.setCookies('p1', const {'a': '1', 'b': '2'});
      expect(manager.getCookies('p1'), {'a': '1', 'b': '2'});
    });

    test('expired cookies are dropped on read', () {
      manager.setCookie(
        'p1',
        'session',
        'abc',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(manager.getCookie('p1', 'session'), isNull);
      expect(manager.getCookies('p1'), isEmpty);
    });

    test('getCookies filters expired entries', () {
      manager.setCookie('p1', 'good', '1');
      manager.setCookie(
        'p1',
        'stale',
        '2',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(manager.getCookies('p1'), {'good': '1'});
    });

    test('updateCookie replaces the value', () {
      manager.setCookie('p1', 'session', 'old');
      manager.updateCookie('p1', 'session', 'new');
      expect(manager.getCookie('p1', 'session'), 'new');
    });

    test('restoreCookies replaces existing entries', () {
      manager.setCookie('p1', 'a', 'old');
      manager.restoreCookies('p1', const [
        CookieEntry(name: 'a', value: 'new'),
      ]);
      expect(manager.getCookie('p1', 'a'), 'new');
    });

    test('clearProvider removes only that provider', () {
      manager.setCookie('p1', 'a', '1');
      manager.setCookie('p2', 'b', '2');
      manager.clearProvider('p1');
      expect(manager.providers, ['p2']);
    });

    test('removeExpiredAll cleans all providers', () {
      manager.setCookie(
        'p1',
        'a',
        '1',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      manager.setCookie('p1', 'b', '2');
      manager.removeExpiredAll();
      expect(manager.getCookies('p1'), {'b': '2'});
    });

    test('serializeCookies formats the Cookie header', () {
      expect(
        CookieManager.serializeCookies(const {'session': 'abc', 'x': 'y'}),
        'session=abc; x=y',
      );
    });
  });
}
