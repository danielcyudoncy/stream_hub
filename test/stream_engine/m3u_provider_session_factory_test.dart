import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/session/factories/m3u_provider_session_factory.dart';

void main() {
  group('M3UProviderSessionFactory', () {
    late M3UProviderSessionFactory factory;

    setUp(() {
      factory = M3UProviderSessionFactory();
    });

    test('exposes provider type', () {
      expect(factory.providerType, MediaSourceType.m3u);
    });

    test('creates a session with source base URL', () async {
      final session = await factory.createSession(
        mediaItemId: 'ch-1',
        itemMetadata: const {
          'streamUrl': 'https://cdn.example.com/live/ch1.ts',
        },
      );
      expect(session.providerType, MediaSourceType.m3u);
      expect(session.providerId, 'ch');
      expect(session.baseUrl, 'https://cdn.example.com/live/ch1.ts');
      expect(session.userAgent, isNotEmpty);
    });

    test('derives base URL from playlist URL', () async {
      final session = await factory.createSession(
        mediaItemId: 'ch-1',
        itemMetadata: const {},
        providerConfig: const {
          'sourceUrl': 'https://example.com/playlists/main.m3u8',
        },
      );
      expect(session.baseUrl, 'https://example.com/playlists/');
    });

    test('honors basic auth from config', () async {
      final session = await factory.createSession(
        mediaItemId: 'ch-1',
        itemMetadata: const {'streamUrl': 'https://example.com/stream.ts'},
        providerConfig: const {'username': 'user', 'password': 'pass'},
      );
      expect(session.username, 'user');
      expect(session.password, 'pass');
    });

    test('extracts credentials from the URL user info', () async {
      final session = await factory.createSession(
        mediaItemId: 'ch-1',
        itemMetadata: const {
          'streamUrl': 'https://user:pass@example.com/stream.ts',
        },
      );
      expect(session.username, 'user');
      expect(session.password, 'pass');
    });

    test('carries headers from config and item metadata', () async {
      final session = await factory.createSession(
        mediaItemId: 'ch-1',
        itemMetadata: const {
          'streamUrl': 'https://example.com/stream.ts',
          'attributes': {'X-Client': 'streamhub'},
        },
        providerConfig: const {
          'headers': {'X-Provider': 'custom'},
        },
      );
      expect(session.headers['X-Client'], 'streamhub');
      expect(session.headers['X-Provider'], 'custom');
    });

    test('reuses existing session id and provider id', () async {
      final existing = ProviderSession(
        providerId: 'kept-provider',
        providerType: MediaSourceType.m3u,
        sessionId: 'existing-session',
      );
      final session = await factory.createSession(
        mediaItemId: 'ch-1',
        itemMetadata: const {'streamUrl': 'https://example.com/stream.ts'},
        existing: existing,
      );
      expect(session.providerId, 'kept-provider');
      expect(session.sessionId, 'existing-session');
    });

    test('detects catchup capabilities', () async {
      final session = await factory.createSession(
        mediaItemId: 'ch-1',
        itemMetadata: const {
          'streamUrl': 'https://example.com/stream.ts',
          'catchup': {'supported': true},
        },
      );
      expect(session.capabilities.supportsCatchup, isTrue);
      expect(session.capabilities.supportsTimeshift, isTrue);
      expect(session.capabilities.supportsSeeking, isTrue);
    });
  });
}
