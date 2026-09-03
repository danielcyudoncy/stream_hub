import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/auth/authentication_engine.dart';
import 'package:stream_hub/core/streaming/cache/session_cache.dart';
import 'package:stream_hub/core/streaming/cache/stream_cache.dart';
import 'package:stream_hub/core/streaming/download/download_preparation_service.dart';
import 'package:stream_hub/core/streaming/events/stream_event_bus.dart';
import 'package:stream_hub/core/streaming/factory/playable_session_factory.dart';
import 'package:stream_hub/core/streaming/failover/failover_manager.dart';
import 'package:stream_hub/core/streaming/health/stream_health_monitor.dart';
import 'package:stream_hub/core/streaming/models/stream_resolution.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';
import 'package:stream_hub/core/streaming/network/header_engine.dart';
import 'package:stream_hub/core/streaming/network/url_normalizer.dart';
import 'package:stream_hub/core/streaming/resolver/stream_resolver.dart';
import 'package:stream_hub/core/streaming/session/factories/custom_provider_session_factory.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory_registry.dart';
import 'package:stream_hub/core/streaming/session/session_manager.dart';
import 'package:stream_hub/core/streaming/stream_engine.dart';
import 'package:stream_hub/core/streaming/validation/stream_validator.dart';
import 'package:stream_hub/data/models/dearbulut_dtos.dart';
import 'package:stream_hub/data/parsers/free_tv_mapper.dart';

import '../../stream_engine/fakes/fake_http_probe.dart';
import '../../stream_engine/fakes/fake_local_service.dart';

class _DirectResolver implements StreamResolver {
  bool followRedirectsUsed = true;

  @override
  Future<StreamResolution> resolve(StreamResolutionRequest request) async {
    followRedirectsUsed = request.options.followRedirects;
    final streamType = StreamType.fromUrl(request.sourceUrl);
    return StreamResolution(
      url: request.sourceUrl,
      streamType: streamType,
    );
  }
}

void main() {
  group('Free TV Startup Latency & Optimization Tests', () {
    late FakeHttpProbe probe;
    late _DirectResolver resolver;
    late StreamEngine engine;

    setUp(() {
      probe = FakeHttpProbe();
      resolver = _DirectResolver();

      final sessionCache = SessionCache(FakeLocalService());
      final registry = ProviderSessionFactoryRegistry()
        ..register(CustomProviderSessionFactory());
      final authEngine = AuthenticationEngine();
      final sessionManager = SessionManager(
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

    test('FreeTvMapper places online streams with higher health score first', () {
      final mapper = FreeTvMapper();
      final dto = DearbulutChannelDto(
        id: 'test_ch',
        name: 'Test Channel',
        online: true,
        streams: [
          DearbulutStreamDto(
            url: 'http://dead.server/stream.m3u8',
            health: DearbulutHealthDto(status: 'offline', score: 0.0),
          ),
          DearbulutStreamDto(
            url: 'http://mediocre.server/stream.m3u8',
            health: DearbulutHealthDto(status: 'online', score: 65.0),
          ),
          DearbulutStreamDto(
            url: 'http://excellent.server/stream.m3u8',
            health: DearbulutHealthDto(status: 'online', score: 99.5),
          ),
        ],
      );

      final channel = mapper.fromDearbulutDto(dto);

      expect(channel.streams.length, 3);
      // Primary stream must be the online stream with highest score (99.5)
      expect(channel.streamUrls.first, 'http://excellent.server/stream.m3u8');
      expect(channel.streams[0].url, 'http://excellent.server/stream.m3u8');
      expect(channel.streams[0].isOnline, true);
      expect(channel.streams[0].healthScore, 99.5);
      // Second stream is the 65.0 online stream
      expect(channel.streams[1].url, 'http://mediocre.server/stream.m3u8');
      // Offline stream is relegated to the back
      expect(channel.streams[2].url, 'http://dead.server/stream.m3u8');
      expect(channel.streams[2].isOnline, false);
    });

    test('StreamEngine resolves Free TV session immediately without blocking network probe', () async {
      final sw = Stopwatch()..start();

      final session = await engine.resolvePlayback(
        mediaItemId: 'free_tv_ch_1',
        providerType: MediaSourceType.custom,
        itemMetadata: {
          'streamUrl': 'https://example.com/live/channel.m3u8',
          'isLive': true,
        },
      );
      sw.stop();

      expect(session.streamUrl, 'https://example.com/live/channel.m3u8');
      expect(session.streamType, StreamType.httpsLive);
      // Probe should NOT have been invoked because network probing is skipped for live Free TV
      expect(probe.probeCalls, 0);
      // Follow redirects should be disabled for direct Free TV live streams
      expect(resolver.followRedirectsUsed, false);
      // Resolution must finish immediately (< 500ms even under parallel suite load) without network roundtrips
      expect(sw.elapsedMilliseconds, lessThan(500));
    });

    test('StreamEngine resolution preserves live stream metadata and custom provider type', () async {
      final session = await engine.resolvePlayback(
        mediaItemId: 'free_tv_channel_band',
        providerType: MediaSourceType.custom,
        itemMetadata: {
          'streamUrl': 'http://45.190.28.50/BAND_HD/index.m3u8',
          'isLive': true,
          'name': 'Band HD',
        },
      );

      expect(session.providerType, MediaSourceType.custom);
      expect(session.streamUrl, 'http://45.190.28.50/BAND_HD/index.m3u8');
      expect(session.metadata['isLive'], true);
      expect(probe.probeCalls, 0);
    });
  });
}
