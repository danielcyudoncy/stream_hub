import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/auth/authentication_engine.dart';
import 'package:stream_hub/core/streaming/auth/authentication_result.dart';
import 'package:stream_hub/core/streaming/cache/session_cache.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory_registry.dart';
import 'package:stream_hub/core/streaming/session/session_manager.dart';

import 'fakes/fake_local_service.dart';

class _FakeFactory implements ProviderSessionFactory {
  final MediaSourceType type;
  _FakeFactory(this.type);

  @override
  MediaSourceType get providerType => type;

  @override
  Future<ProviderSession> createSession({
    required String mediaItemId,
    required Map<String, dynamic> itemMetadata,
    Map<String, dynamic>? providerConfig,
    ProviderSession? existing,
  }) async {
    final config = providerConfig ?? const <String, dynamic>{};
    final cookies = (itemMetadata['cookies'] is Map)
        ? (itemMetadata['cookies'] as Map).map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          )
        : const <String, String>{};
    final providerId =
        config['providerId']?.toString() ??
        itemMetadata['providerId']?.toString() ??
        'provider-1';
    return ProviderSession(
      providerId: providerId,
      providerType: type,
      sessionId: 'session-$mediaItemId',
      baseUrl: 'http://provider.example.com',
      cookies: cookies,
    );
  }
}

class _NoOpAuth implements AuthenticationProvider {
  @override
  MediaSourceType get providerType => MediaSourceType.xtream;

  @override
  bool get supportsRefresh => false;

  @override
  Future<AuthenticationResult> validate(ProviderSession session) async {
    return const AuthenticationResult.authenticated();
  }

  @override
  Future<ProviderSession> refresh(ProviderSession session) async {
    return session;
  }
}

void main() {
  group('SessionManager', () {
    late SessionCache sessionCache;
    late FakeLocalService localService;
    late SessionManager manager;
    late CookieManager cookieManager;
    late ProviderSessionFactoryRegistry registry;
    late AuthenticationEngine authEngine;

    setUp(() {
      localService = FakeLocalService();
      sessionCache = SessionCache(localService);
      cookieManager = CookieManager();
      registry = ProviderSessionFactoryRegistry()
        ..register(_FakeFactory(MediaSourceType.xtream));
      authEngine = AuthenticationEngine()..registerProvider(_NoOpAuth());
      manager = SessionManager(
        sessionCache: sessionCache,
        authenticationEngine: authEngine,
        cookieManager: cookieManager,
        registry: registry,
      );
    });

    test('creates, authenticates, and persists a session', () async {
      final session = await manager.getOrCreateSession(
        mediaItemId: 'movie-1',
        providerType: MediaSourceType.xtream,
        itemMetadata: const {
          'streamUrl': 'http://provider.example.com/movie.mkv',
        },
      );

      expect(session.providerId, 'provider-1');
      expect(session.sessionId, 'session-movie-1');

      final persisted = await manager.getSession('provider-1');
      expect(persisted, isNotNull);
      expect(persisted!.sessionId, 'session-movie-1');
    });

    test('resolves provider id from item metadata', () async {
      final session = await manager.getOrCreateSession(
        mediaItemId: 'movie-1',
        providerType: MediaSourceType.xtream,
        itemMetadata: const {
          'providerId': 'custom-provider',
          'streamUrl': 'http://provider.example.com/movie.mkv',
        },
      );
      expect(session.providerId, 'custom-provider');
    });

    test('reuses an existing persisted session', () async {
      await manager.getOrCreateSession(
        mediaItemId: 'movie-1',
        providerType: MediaSourceType.xtream,
        itemMetadata: const {
          'streamUrl': 'http://provider.example.com/movie.mkv',
        },
        providerId: 'provider-1',
      );

      final again = await manager.getOrCreateSession(
        mediaItemId: 'movie-2',
        providerType: MediaSourceType.xtream,
        itemMetadata: const {
          'streamUrl': 'http://provider.example.com/movie2.mkv',
        },
        providerId: 'provider-1',
      );

      expect(again.sessionId, 'session-movie-1');
    });

    test('stores session cookies into the cookie manager', () async {
      await manager.getOrCreateSession(
        mediaItemId: 'movie-1',
        providerType: MediaSourceType.xtream,
        itemMetadata: const {
          'cookies': {'session': 'abc'},
          'streamUrl': 'http://provider.example.com/movie.mkv',
        },
      );

      expect(cookieManager.getCookie('provider-1', 'session'), 'abc');
    });

    test('refreshSession throws when no session exists', () async {
      expect(
        () => manager.refreshSession('missing'),
        throwsA(isA<StateError>()),
      );
    });

    test('refreshSession renews the persisted session', () async {
      await manager.getOrCreateSession(
        mediaItemId: 'movie-1',
        providerType: MediaSourceType.xtream,
        itemMetadata: const {
          'streamUrl': 'http://provider.example.com/movie.mkv',
        },
      );

      final refreshed = await manager.refreshSession('provider-1');
      expect(refreshed.sessionId, 'session-movie-1');

      final persisted = await manager.getSession('provider-1');
      expect(persisted, isNotNull);
    });

    test('invalidate removes session and cookies', () async {
      cookieManager.setCookie('provider-1', 'a', '1');
      await manager.invalidate('provider-1');

      expect(await manager.getSession('provider-1'), isNull);
      expect(cookieManager.getCookies('provider-1'), isEmpty);
    });

    test('isAuthenticated returns false when no session exists', () async {
      expect(await manager.isAuthenticated('provider-1'), isFalse);
    });

    test('isAuthenticated returns true for a valid session', () async {
      await manager.getOrCreateSession(
        mediaItemId: 'movie-1',
        providerType: MediaSourceType.xtream,
        itemMetadata: const {
          'streamUrl': 'http://provider.example.com/movie.mkv',
        },
      );
      expect(await manager.isAuthenticated('provider-1'), isTrue);
    });
  });
}
