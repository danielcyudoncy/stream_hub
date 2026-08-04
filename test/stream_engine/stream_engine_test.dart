import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/auth/authentication_engine.dart';
import 'package:stream_hub/core/streaming/cache/session_cache.dart';
import 'package:stream_hub/core/streaming/cache/stream_cache.dart';
import 'package:stream_hub/core/streaming/download/download_preparation_service.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/events/stream_event_bus.dart';
import 'package:stream_hub/core/streaming/factory/playable_session_factory.dart';
import 'package:stream_hub/core/streaming/failover/failover_manager.dart';
import 'package:stream_hub/core/streaming/health/stream_health_monitor.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';
import 'package:stream_hub/core/streaming/models/stream_resolution.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';
import 'package:stream_hub/core/streaming/network/header_engine.dart';
import 'package:stream_hub/core/streaming/network/url_normalizer.dart';
import 'package:stream_hub/core/streaming/resolver/stream_resolver.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory_registry.dart';
import 'package:stream_hub/core/streaming/session/session_manager.dart';
import 'package:stream_hub/core/streaming/session/factories/m3u_provider_session_factory.dart';
import 'package:stream_hub/core/streaming/stream_engine.dart';
import 'package:stream_hub/core/streaming/validation/stream_validator.dart';

import 'fakes/fake_http_probe.dart';
import 'fakes/fake_local_service.dart';

/// Fake resolver that mimics URL-to-resolution behaviour for engine tests.
class _FakeResolver implements StreamResolver {
  final List<String> resolvedUrls = [];

  @override
  Future<StreamResolution> resolve(StreamResolutionRequest request) async {
    resolvedUrls.add(request.sourceUrl);
    if (request.sourceUrl.startsWith('ftp://')) {
      throw const StreamUnsupportedProtocolException();
    }
    final streamType = StreamType.fromUrl(request.sourceUrl);
    return StreamResolution(
      url: request.sourceUrl,
      streamType: streamType,
      capabilities: StreamCapabilities(
        supportsDownload: request.sourceUrl.contains('.mp4'),
        supportsSeeking: request.sourceUrl.contains('.mp4'),
      ),
    );
  }
}

void main() {
  group('StreamEngine', () {
    late FakeHttpProbe probe;
    late _FakeResolver resolver;
    late SessionManager sessionManager;
    late StreamEngine engine;
    late SessionCache sessionCache;

    setUp(() {
      probe = FakeHttpProbe();
      resolver = _FakeResolver();

      sessionCache = SessionCache(FakeLocalService());
      final registry = ProviderSessionFactoryRegistry()
        ..register(M3UProviderSessionFactory());
      final authEngine = AuthenticationEngine();
      sessionManager = SessionManager(
        sessionCache: sessionCache,
        authenticationEngine: authEngine,
        cookieManager: CookieManager(),
        registry: registry,
      );

      engine = StreamEngine(
        sessionManager: sessionManager,
        resolver: resolver,
        authenticationEngine: authEngine,
        headerEngine: HeaderEngine(),
        cookieManager: CookieManager(),
        urlNormalizer: UrlNormalizer(),
        streamValidator: StreamValidator(probe: probe),
        healthMonitor: StreamHealthMonitor(),
        streamCache: StreamCache(),
        playableSessionFactory: PlayableSessionFactory(),
        downloadPreparationService: DownloadPreparationService(),
        failoverManager: FailoverManager(),
        eventBus: StreamEventBus(),
      );
    });

    Map<String, dynamic> metadataFor(String url) => {'streamUrl': url};

    PlayableSession directSession(String url) {
      return PlayableSession(
        sessionId: 'ps-$url',
        mediaItemId: 'ch-1',
        providerId: 'ch',
        providerType: MediaSourceType.m3u,
        streamUrl: url,
        streamType: StreamType.fromUrl(url),
      );
    }

    test('resolves an m3u8 URL into a validated playable session', () async {
      final session = await engine.resolvePlayback(
        mediaItemId: 'ch-1',
        providerType: MediaSourceType.m3u,
        itemMetadata: metadataFor('https://example.com/live/ch1.m3u8'),
        providerId: 'ch',
      );

      expect(session.streamUrl, 'https://example.com/live/ch1.m3u8');
      expect(session.providerId, 'ch');
      expect(session.providerType, MediaSourceType.m3u);
      expect(session.streamType, StreamType.httpsLive);
      expect(session.isExpired, isFalse);
      expect(engine.cachedSession('ch', 'ch-1'), session);
    });

    test('reuses a cached session on the second resolve', () async {
      await engine.resolvePlayback(
        mediaItemId: 'ch-1',
        providerType: MediaSourceType.m3u,
        itemMetadata: metadataFor('https://example.com/live/ch1.m3u8'),
        providerId: 'ch',
      );
      final resolvedCount = resolver.resolvedUrls.length;

      final second = await engine.resolvePlayback(
        mediaItemId: 'ch-1',
        providerType: MediaSourceType.m3u,
        itemMetadata: metadataFor('https://example.com/live/ch1.m3u8'),
        providerId: 'ch',
      );

      expect(second.streamUrl, 'https://example.com/live/ch1.m3u8');
      expect(resolver.resolvedUrls.length, resolvedCount);
    });

    test('resolves a raw URL through resolveStream', () async {
      final providerSession = await sessionManager.getOrCreateSession(
        mediaItemId: 'ch-1',
        providerType: MediaSourceType.m3u,
        itemMetadata: metadataFor('https://example.com/live/ch1.m3u8'),
      );

      final session = await engine.resolveStream(
        mediaItemId: 'ch-1',
        url: 'https://cdn.example.com/direct/ch1.ts',
        providerSession: providerSession,
      );

      expect(session.streamUrl, 'https://cdn.example.com/direct/ch1.ts');
      expect(session.streamType, StreamType.mpegTs);
    });

    test(
      'skips the network probe for MPEG-TS live sessions (local checks only)',
      () async {
        // An unreachable probe would otherwise reject the session.
        probe.throwException = true;
        final session = await engine.resolvePlayback(
          mediaItemId: 'ch-1',
          providerType: MediaSourceType.m3u,
          itemMetadata: metadataFor('https://cdn.example.com/live/ch1.ts'),
          providerId: 'ch',
        );

        expect(session.streamUrl, 'https://cdn.example.com/live/ch1.ts');
        expect(session.streamType, StreamType.mpegTs);
        expect(probe.headProbes, 0);
      },
    );

    test('still probes finite content (m3u8) during validation', () async {
      probe.throwException = true;
      expect(
        () => engine.resolvePlayback(
          mediaItemId: 'ch-1',
          providerType: MediaSourceType.m3u,
          itemMetadata: metadataFor('https://example.com/live/ch1.m3u8'),
          providerId: 'ch',
        ),
        throwsA(isA<StreamValidationException>()),
      );
    });

    test(
      'throws StreamResolutionException when no source URL exists',
      () async {
        expect(
          () => engine.resolvePlayback(
            mediaItemId: 'ch-1',
            providerType: MediaSourceType.m3u,
            itemMetadata: const {},
            providerId: 'ch',
          ),
          throwsA(isA<StreamResolutionException>()),
        );
      },
    );

    test('throws when validation fails (network unreachable)', () async {
      probe.throwException = true;
      expect(
        () => engine.resolvePlayback(
          mediaItemId: 'ch-1',
          providerType: MediaSourceType.m3u,
          itemMetadata: metadataFor('https://example.com/live/ch1.m3u8'),
          providerId: 'ch',
        ),
        throwsA(isA<StreamValidationException>()),
      );
    });

    test('skips validation when validate is false', () async {
      probe.throwException = true;
      final session = await engine.resolvePlayback(
        mediaItemId: 'ch-1',
        providerType: MediaSourceType.m3u,
        itemMetadata: metadataFor('https://example.com/live/ch1.m3u8'),
        providerId: 'ch',
        validate: false,
      );
      expect(session.streamUrl, isNotEmpty);
    });

    test('prepareDownload marks downloadable mp4 streams', () async {
      final prepared = await engine.prepareDownload(
        mediaItemId: 'movie-1',
        providerType: MediaSourceType.m3u,
        itemMetadata: metadataFor('https://example.com/video.mp4'),
        providerId: 'movie',
      );

      expect(prepared.canDownload, isTrue);
      expect(prepared.fileExtension, 'mp4');
      expect(prepared.suggestedFileName, 'movie-1.mp4');
    });

    test('prepareDownload rejects non-downloadable streams', () async {
      final prepared = await engine.prepareDownload(
        mediaItemId: 'ch-1',
        providerType: MediaSourceType.m3u,
        itemMetadata: metadataFor('https://example.com/live/ch1.m3u8'),
        providerId: 'ch',
      );

      expect(prepared.canDownload, isFalse);
    });

    test('validateStream records health for valid streams', () async {
      final session = await engine.resolvePlayback(
        mediaItemId: 'ch-1',
        providerType: MediaSourceType.m3u,
        itemMetadata: metadataFor('https://example.com/live/ch1.m3u8'),
        providerId: 'ch',
      );
      final valid = await engine.validateStream(session);
      expect(valid, isTrue);
      final health = engine.healthFor(session.sessionId);
      expect(health, isNotNull);
      expect(health!.isAvailable, isTrue);
    });

    test('selectWorkingStream fails over to a working backup', () async {
      probe.results['https://example.com/primary.m3u8'] = HttpProbeResult(
        statusCode: 404,
        finalUri: Uri.parse('https://example.com/primary.m3u8'),
      );
      final session = directSession('https://example.com/primary.m3u8');

      final withBackup = session.copyWith(
        metadata: {
          ...session.metadata,
          'backupUrls': ['https://example.com/backup.m3u8'],
        },
      );

      final working = await engine.selectWorkingStream(withBackup);
      expect(working.streamUrl, 'https://example.com/backup.m3u8');
    });

    test('selectWorkingStream throws when all candidates fail', () async {
      probe.results['https://example.com/primary.m3u8'] = HttpProbeResult(
        statusCode: 404,
        finalUri: Uri.parse('https://example.com/primary.m3u8'),
      );
      probe.results['https://example.com/backup.m3u8'] = HttpProbeResult(
        statusCode: 404,
        finalUri: Uri.parse('https://example.com/backup.m3u8'),
      );
      final session = directSession('https://example.com/primary.m3u8');

      final withBackup = session.copyWith(
        metadata: {
          ...session.metadata,
          'backupUrls': ['https://example.com/backup.m3u8'],
        },
      );

      expect(
        () => engine.selectWorkingStream(withBackup),
        throwsA(isA<StreamNetworkException>()),
      );
    });

    test('providerConfigProvider is invoked during resolution', () async {
      Map<String, dynamic>? receivedConfig;
      engine.providerConfigProvider = (providerId) async {
        receivedConfig = {'providerId': providerId};
        return receivedConfig;
      };

      final session = await engine.resolvePlayback(
        mediaItemId: 'ch-1',
        providerType: MediaSourceType.m3u,
        itemMetadata: metadataFor('https://example.com/live/ch1.m3u8'),
        providerId: 'ch',
      );

      expect(receivedConfig, isNotNull);
      expect(session.providerId, 'ch');
    });
  });
}
