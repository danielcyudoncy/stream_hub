import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/cache/stream_cache.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/stream_resolution.dart';

PlayableSession _session(
  String providerId,
  String mediaItemId, {
  DateTime? expiresAt,
}) {
  return PlayableSession(
    sessionId: 's_$providerId',
    mediaItemId: mediaItemId,
    providerId: providerId,
    providerType: MediaSourceType.m3u,
    streamUrl: 'https://example.com/$mediaItemId.m3u8',
    streamType: StreamType.httpLive,
    expiresAt: expiresAt,
  );
}

void main() {
  group('StreamCache', () {
    late StreamCache cache;

    setUp(() {
      cache = StreamCache();
    });

    test('stores and retrieves sessions', () {
      final session = _session('p1', 'item1');
      cache.putSession(session);
      expect(cache.getSession(session.cacheKey), session);
      expect(cache.sessionCount, 1);
    });

    test('drops expired sessions', () {
      final expired = _session(
        'p1',
        'item1',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      cache.putSession(expired);
      expect(cache.getSession(expired.cacheKey), isNull);
      expect(cache.sessionCount, 0);
    });

    test('invalidate removes a session', () {
      final session = _session('p1', 'item1');
      cache.putSession(session);
      cache.invalidate(session.cacheKey);
      expect(cache.getSession(session.cacheKey), isNull);
    });

    test('evictExpired removes only stale entries', () {
      final fresh = _session('p1', 'item1');
      final stale = _session(
        'p2',
        'item2',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      cache.putSession(fresh);
      cache.putSession(stale);
      cache.evictExpired();
      expect(cache.getSession(fresh.cacheKey), fresh);
      expect(cache.getSession(stale.cacheKey), isNull);
    });

    test('caches and retrieves resolutions', () {
      const resolution = StreamResolution(
        url: 'https://example.com/stream.m3u8',
        streamType: StreamType.httpLive,
      );
      cache.cacheResolution('source-url', resolution);
      expect(cache.getResolution('source-url'), resolution);
    });

    test('clear wipes everything', () {
      cache.putSession(_session('p1', 'item1'));
      cache.cacheResolution(
        'src',
        const StreamResolution(
          url: 'https://example.com/stream.m3u8',
          streamType: StreamType.httpLive,
        ),
      );
      cache.clear();
      expect(cache.isEmpty, isTrue);
    });

    test('evicts oldest entries when over capacity', () {
      final smallCache = StreamCache(maxEntries: 2);
      final first = _session('p1', 'item1');
      final second = _session('p1', 'item2');
      final third = _session('p1', 'item3');
      smallCache.putSession(first);
      smallCache.putSession(second);
      smallCache.putSession(third);
      expect(smallCache.sessionCount, 2);
      expect(smallCache.getSession(first.cacheKey), isNull);
      expect(smallCache.getSession(third.cacheKey), third);
    });
  });
}
