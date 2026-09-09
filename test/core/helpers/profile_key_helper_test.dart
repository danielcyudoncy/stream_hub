import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/helpers/profile_key_helper.dart';

void main() {
  group('ProfileKeyHelper — Favorites', () {
    test('bare key when profileId is empty', () {
      expect(ProfileKeyHelper.favKey('', 'item1'), 'item1');
    });

    test('prefixed key when profileId is set', () {
      expect(
        ProfileKeyHelper.favKey('abc123', 'item1'),
        'p_abc123:item1',
      );
    });

    test('isFavKeyForProfile — empty profile matches bare key', () {
      expect(ProfileKeyHelper.isFavKeyForProfile('item1', ''), isTrue);
    });

    test('isFavKeyForProfile — empty profile rejects prefixed key', () {
      expect(ProfileKeyHelper.isFavKeyForProfile('p_abc:item1', ''), isFalse);
    });

    test('isFavKeyForProfile — profile matches its own prefix', () {
      expect(
        ProfileKeyHelper.isFavKeyForProfile('p_abc123:item1', 'abc123'),
        isTrue,
      );
    });

    test('isFavKeyForProfile — profile rejects other profile key', () {
      expect(
        ProfileKeyHelper.isFavKeyForProfile('p_OTHER:item1', 'abc123'),
        isFalse,
      );
    });

    test('extractFavItemId — empty profile returns key as-is', () {
      expect(ProfileKeyHelper.extractFavItemId('item1', ''), 'item1');
    });

    test('extractFavItemId — strips prefix correctly', () {
      expect(ProfileKeyHelper.extractFavItemId('p_abc123:item1', 'abc123'), 'item1');
    });

    test('extractFavItemId — unknown prefix returned unchanged', () {
      expect(ProfileKeyHelper.extractFavItemId('p_OTHER:item1', 'abc123'), 'p_OTHER:item1');
    });
  });

  group('ProfileKeyHelper — Watch Progress', () {
    test('bare key when profileId is empty', () {
      expect(ProfileKeyHelper.watchKey('', 'movie1'), 'movie1');
    });

    test('prefixed key when profileId is set', () {
      expect(
        ProfileKeyHelper.watchKey('profile_99', 'movie1'),
        'p_profile_99/movie1',
      );
    });

    test('isWatchKeyForProfile — empty profile matches bare key', () {
      expect(ProfileKeyHelper.isWatchKeyForProfile('movie1', ''), isTrue);
    });

    test('isWatchKeyForProfile — profile matches own prefix', () {
      expect(
        ProfileKeyHelper.isWatchKeyForProfile('p_profile_99/movie1', 'profile_99'),
        isTrue,
      );
    });

    test('isWatchKeyForProfile — profile rejects other profile', () {
      expect(
        ProfileKeyHelper.isWatchKeyForProfile('p_OTHER/movie1', 'profile_99'),
        isFalse,
      );
    });

    test('extractWatchItemId — strips prefix correctly', () {
      expect(
        ProfileKeyHelper.extractWatchItemId('p_profile_99/movie1', 'profile_99'),
        'movie1',
      );
    });
  });

  group('ProfileKeyHelper — History', () {
    test('bare key when profileId is empty', () {
      expect(ProfileKeyHelper.histKey('', 'ch1'), 'ch1');
    });

    test('prefixed key when profileId is set', () {
      expect(
        ProfileKeyHelper.histKey('p1', 'ch1'),
        'ph_p1/ch1',
      );
    });

    test('isHistKeyForProfile — empty profile matches bare key', () {
      expect(ProfileKeyHelper.isHistKeyForProfile('ch1', ''), isTrue);
    });

    test('isHistKeyForProfile — empty profile rejects hist prefix', () {
      expect(ProfileKeyHelper.isHistKeyForProfile('ph_p1/ch1', ''), isFalse);
    });

    test('isHistKeyForProfile — profile matches own prefix', () {
      expect(ProfileKeyHelper.isHistKeyForProfile('ph_p1/ch1', 'p1'), isTrue);
    });

    test('extractHistItemId — strips prefix correctly', () {
      expect(ProfileKeyHelper.extractHistItemId('ph_p1/ch1', 'p1'), 'ch1');
    });
  });

  group('ProfileKeyHelper — no collisions', () {
    test('fav key and watch key for same profile+item are different', () {
      final fav = ProfileKeyHelper.favKey('p1', 'item1');
      final watch = ProfileKeyHelper.watchKey('p1', 'item1');
      final hist = ProfileKeyHelper.histKey('p1', 'item1');
      expect(fav, isNot(watch));
      expect(fav, isNot(hist));
      expect(watch, isNot(hist));
    });

    test('keys for different profiles do not collide', () {
      expect(
        ProfileKeyHelper.favKey('profile_A', 'item1'),
        isNot(ProfileKeyHelper.favKey('profile_B', 'item1')),
      );
    });
  });
}
