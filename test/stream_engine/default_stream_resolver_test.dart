import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';
import 'package:stream_hub/core/streaming/resolver/default_stream_resolver.dart';
import 'package:stream_hub/core/streaming/resolver/stream_resolver.dart';

import 'fakes/fake_http_probe.dart';

ProviderSession _session({String? baseUrl}) {
  return ProviderSession(
    providerId: 'p1',
    providerType: MediaSourceType.m3u,
    sessionId: 's1',
    baseUrl: baseUrl,
  );
}

void main() {
  group('DefaultStreamResolver', () {
    test('resolves relative URLs against the session base URL', () async {
      final resolver = DefaultStreamResolver(probe: FakeHttpProbe());
      final result = await resolver.resolve(
        StreamResolutionRequest(
          session: _session(baseUrl: 'https://example.com/playlists/'),
          sourceUrl: 'stream.ts',
          mediaItemId: 'ch-1',
        ),
      );
      expect(result.url, 'https://example.com/playlists/stream.ts');
    });

    test('keeps absolute URLs unchanged', () async {
      final resolver = DefaultStreamResolver(probe: FakeHttpProbe());
      final result = await resolver.resolve(
        StreamResolutionRequest(
          session: _session(),
          sourceUrl: 'https://cdn.example.com/stream.m3u8',
          mediaItemId: 'ch-1',
        ),
      );
      expect(result.url, 'https://cdn.example.com/stream.m3u8');
      expect(result.streamType, StreamType.httpsLive);
    });

    test('follows redirects to the final URI', () async {
      final probe = FakeHttpProbe(
        results: {
          'https://example.com/start.ts': HttpProbeResult(
            statusCode: 302,
            finalUri: Uri.parse('https://example.com/start.ts'),
            redirectUri: Uri.parse('https://cdn.example.com/final.ts'),
          ),
          'https://cdn.example.com/final.ts': HttpProbeResult(
            statusCode: 200,
            finalUri: Uri.parse('https://cdn.example.com/final.ts'),
          ),
        },
      );
      final resolver = DefaultStreamResolver(probe: probe);
      final result = await resolver.resolve(
        StreamResolutionRequest(
          session: _session(),
          sourceUrl: 'https://example.com/start.ts',
          mediaItemId: 'ch-1',
        ),
      );
      expect(result.url, 'https://cdn.example.com/final.ts');
    });

    test('detects a redirect loop', () async {
      final probe = FakeHttpProbe(
        results: {
          'https://example.com/a.ts': HttpProbeResult(
            statusCode: 302,
            finalUri: Uri.parse('https://example.com/a.ts'),
            redirectUri: Uri.parse('https://example.com/b.ts'),
          ),
          'https://example.com/b.ts': HttpProbeResult(
            statusCode: 302,
            finalUri: Uri.parse('https://example.com/b.ts'),
            redirectUri: Uri.parse('https://example.com/a.ts'),
          ),
        },
      );
      final resolver = DefaultStreamResolver(probe: probe);
      expect(
        () => resolver.resolve(
          StreamResolutionRequest(
            session: _session(),
            sourceUrl: 'https://example.com/a.ts',
            mediaItemId: 'ch-1',
          ),
        ),
        throwsA(isA<StreamRedirectLoopException>()),
      );
    });

    test('rejects unsupported protocols', () async {
      final resolver = DefaultStreamResolver(probe: FakeHttpProbe());
      expect(
        () => resolver.resolve(
          StreamResolutionRequest(
            session: _session(),
            sourceUrl: 'ftp://example.com/file',
            mediaItemId: 'ch-1',
          ),
        ),
        throwsA(isA<StreamUnsupportedProtocolException>()),
      );
    });

    test('propagates mime type, expiration, drm, and backups', () async {
      final resolver = DefaultStreamResolver(probe: FakeHttpProbe());
      final result = await resolver.resolve(
        StreamResolutionRequest(
          session: _session(),
          sourceUrl: 'https://example.com/video.mp4',
          mediaItemId: 'movie-1',
          itemMetadata: const {
            'mimeType': 'video/mp4',
            'drmScheme': 'widevine',
            'drmLicenseUrl': 'https://license.example.com',
            'backupUrls': ['https://backup.example.com/video.mp4'],
          },
        ),
      );
      expect(result.streamType, StreamType.mp4);
      expect(result.mimeType, 'video/mp4');
      expect(result.drmScheme, 'widevine');
      expect(result.drmLicenseUrl, 'https://license.example.com');
      expect(result.backupUrls, ['https://backup.example.com/video.mp4']);
    });

    test('sets supportsDownload for mp4 streams', () async {
      final resolver = DefaultStreamResolver(probe: FakeHttpProbe());
      final result = await resolver.resolve(
        StreamResolutionRequest(
          session: _session(),
          sourceUrl: 'https://example.com/video.mp4',
          mediaItemId: 'movie-1',
        ),
      );
      expect(result.capabilities.supportsDownload, isTrue);
    });

    test('enables catchup when metadata declares it', () async {
      final resolver = DefaultStreamResolver(probe: FakeHttpProbe());
      final result = await resolver.resolve(
        StreamResolutionRequest(
          session: _session(),
          sourceUrl: 'https://example.com/live/ch.m3u8',
          mediaItemId: 'ch-1',
          itemMetadata: const {
            'catchup': {'supported': true},
          },
        ),
      );
      expect(result.capabilities.supportsCatchup, isTrue);
      expect(result.capabilities.supportsTimeshift, isTrue);
    });
  });
}
