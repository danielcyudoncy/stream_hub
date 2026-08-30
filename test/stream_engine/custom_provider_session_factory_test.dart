import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/session/factories/custom_provider_session_factory.dart';

void main() {
  group('CustomProviderSessionFactory', () {
    late CustomProviderSessionFactory factory;

    setUp(() {
      factory = CustomProviderSessionFactory();
    });

    test('exposes provider type', () {
      expect(factory.providerType, MediaSourceType.custom);
    });

    test('creates a session from metadata stream URL', () async {
      final session = await factory.createSession(
        mediaItemId: 'free_tv_PlusTV.by',
        itemMetadata: const {
          'streamUrl': 'https://cdn.example.com/live/ch1.m3u8',
          'providerId': 'free_live_tv',
        },
      );
      expect(session.providerType, MediaSourceType.custom);
      expect(session.providerId, 'free_live_tv');
      expect(session.sessionId, startsWith('custom_'));
      expect(
        session.baseUrl,
        'https://cdn.example.com/live/',
      );
      expect(session.userAgent, isNotEmpty);
    });

    test('defaults provider id when none supplied', () async {
      final session = await factory.createSession(
        mediaItemId: 'free_tv_ch',
        itemMetadata: const {'streamUrl': 'https://cd.example.com/live.m3u8'},
      );
      expect(session.providerId, 'custom');
    });

    test('derives base URL from an HLS playlist', () async {
      final session = await factory.createSession(
        mediaItemId: 'ch',
        itemMetadata: const {'streamUrl': 'https://cd.example.com/live/main.m3u8'},
      );
      expect(session.baseUrl, 'https://cd.example.com/live/');
    });

    test('keeps full URL as base for non-playlist streams', () async {
      final session = await factory.createSession(
        mediaItemId: 'ch',
        itemMetadata: const {'streamUrl': 'https://cd.example.com/live.mpd'},
      );
      expect(session.baseUrl, 'https://cd.example.com/');
    });

    test('sets live-appropriate capabilities', () async {
      final session = await factory.createSession(
        mediaItemId: 'ch',
        itemMetadata: const {'streamUrl': 'https://cd.example.com/live.m3u8'},
      );
      expect(session.capabilities.supportsPause, isTrue);
      expect(session.capabilities.supportsRecording, isTrue);
      expect(session.capabilities.supportsSeeking, isFalse);
      expect(session.capabilities.supportsDownload, isFalse);
    });

    test('carries headers and referer from metadata', () async {
      final session = await factory.createSession(
        mediaItemId: 'ch',
        itemMetadata: const {
          'streamUrl': 'https://cd.example.com/live.m3u8',
          'headers': {'X-Free-Tv': '1'},
          'referer': 'https://cd.example.com/',
        },
      );
      expect(session.headers['X-Free-Tv'], '1');
      expect(session.referer, 'https://cd.example.com/');
    });

    test('reuses existing session id and provider id', () async {
      final existing = ProviderSession(
        providerId: 'kept-provider',
        providerType: MediaSourceType.custom,
        sessionId: 'existing-session',
      );
      final session = await factory.createSession(
        mediaItemId: 'ch',
        itemMetadata: const {'streamUrl': 'https://cd.example.com/live.m3u8'},
        existing: existing,
      );
      expect(session.providerId, 'kept-provider');
      expect(session.sessionId, 'existing-session');
    });
  });
}
