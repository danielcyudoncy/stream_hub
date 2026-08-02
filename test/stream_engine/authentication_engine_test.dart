import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/auth/authentication_engine.dart';
import 'package:stream_hub/core/streaming/auth/authentication_result.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';

class _FakeProvider implements AuthenticationProvider {
  final MediaSourceType type;
  final bool refreshable;
  bool validateCalled = false;
  bool refreshCalled = false;
  AuthenticationResult Function(ProviderSession session)? onValidate;
  ProviderSession Function(ProviderSession session)? onRefresh;

  _FakeProvider(
    this.type, {
    this.refreshable = true,
    this.onValidate,
    this.onRefresh,
  });

  @override
  MediaSourceType get providerType => type;

  @override
  bool get supportsRefresh => refreshable;

  @override
  Future<AuthenticationResult> validate(ProviderSession session) async {
    validateCalled = true;
    if (onValidate != null) return onValidate!(session);
    return AuthenticationResult.authenticated();
  }

  @override
  Future<ProviderSession> refresh(ProviderSession session) async {
    refreshCalled = true;
    if (onRefresh != null) return onRefresh!(session);
    return session.copyWith(
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }
}

ProviderSession _session({
  MediaSourceType type = MediaSourceType.xtream,
  DateTime? expiresAt,
  bool withAuth = true,
}) {
  return ProviderSession(
    providerId: 'provider-1',
    providerType: type,
    sessionId: 'session-1',
    username: withAuth ? 'user' : null,
    password: withAuth ? 'pass' : null,
    expiresAt: expiresAt,
  );
}

void main() {
  group('AuthenticationEngine', () {
    late AuthenticationEngine engine;

    setUp(() {
      engine = AuthenticationEngine();
    });

    group('ensureValidSession', () {
      test('valid session short-circuits without refresh', () async {
        final provider = _FakeProvider(MediaSourceType.xtream);
        engine.registerProvider(provider);
        final session = _session(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        final result = await engine.ensureValidSession(session);
        expect(result, same(session));
        expect(provider.validateCalled, isTrue);
        expect(provider.refreshCalled, isFalse);
      });

      test('refreshes an expired session', () async {
        final provider = _FakeProvider(MediaSourceType.xtream);
        engine.registerProvider(provider);
        final session = _session(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        );
        final result = await engine.ensureValidSession(session);
        expect(provider.refreshCalled, isTrue);
        expect(result.expiresAt!.isAfter(DateTime.now()), isTrue);
      });

      test('refreshes when validation fails', () async {
        final provider = _FakeProvider(
          MediaSourceType.xtream,
          onValidate: (_) => AuthenticationResult.failed('bad creds'),
        );
        engine.registerProvider(provider);
        final session = _session(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        final result = await engine.ensureValidSession(session);
        expect(provider.refreshCalled, isTrue);
        expect(result.expiresAt!.isAfter(DateTime.now()), isTrue);
      });

      test('throws StreamAuthException when refresh fails', () async {
        final provider = _FakeProvider(
          MediaSourceType.xtream,
          onRefresh: (_) => throw Exception('network down'),
        );
        engine.registerProvider(provider);
        final session = _session(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        );
        expect(
          () => engine.ensureValidSession(session),
          throwsA(isA<StreamAuthException>()),
        );
      });

      test('throws when validation fails and refresh is unsupported', () async {
        final provider = _FakeProvider(
          MediaSourceType.xtream,
          refreshable: false,
          onValidate: (_) => AuthenticationResult.failed('nope'),
        );
        engine.registerProvider(provider);
        final session = _session(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        expect(
          () => engine.ensureValidSession(session),
          throwsA(isA<StreamAuthException>()),
        );
      });

      test('session without auth passes through validation', () async {
        final session = _session(withAuth: false);
        final result = await engine.ensureValidSession(session);
        expect(result, same(session));
      });
    });

    group('validate', () {
      test('returns authenticated when no provider is registered', () async {
        final result = await engine.validate(_session());
        expect(result.isAuthenticated, isTrue);
      });

      test('delegates to the registered provider', () async {
        final provider = _FakeProvider(
          MediaSourceType.xtream,
          onValidate: (_) => AuthenticationResult.failed('blocked'),
        );
        engine.registerProvider(provider);
        final result = await engine.validate(_session());
        expect(result.isAuthenticated, isFalse);
        expect(provider.validateCalled, isTrue);
      });

      test('swallows provider errors into a failed result', () async {
        engine.registerProvider(
          _FakeProvider(
            MediaSourceType.xtream,
            onValidate: (_) => throw Exception('boom'),
          ),
        );
        final result = await engine.validate(_session());
        expect(result.isAuthenticated, isFalse);
      });
    });

    group('applyAuthenticationToUrl', () {
      test('appends token and username for portal sessions', () {
        final session = ProviderSession(
          providerId: 'p',
          providerType: MediaSourceType.stalker,
          sessionId: 's',
          portalToken: 'tok',
          username: 'me',
        );
        final url = engine.applyAuthenticationToUrl(
          session,
          'http://portal.example.com/stream',
        );
        final uri = Uri.parse(url);
        expect(uri.queryParameters['token'], 'tok');
        expect(uri.queryParameters['username'], 'me');
      });

      test('returns the URL unchanged for non-portal sessions', () {
        final url = engine.applyAuthenticationToUrl(
          _session(),
          'http://example.com/stream.ts',
        );
        expect(url, 'http://example.com/stream.ts');
      });
    });
  });
}
