import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/resolver/stalker_stream_resolver.dart';
import 'package:stream_hub/core/streaming/resolver/stream_resolver.dart';

import 'portal_test_server.dart';

void main() {
  ProviderSession session({String? portalToken}) {
    return ProviderSession(
      providerId: 'p1',
      providerType: MediaSourceType.stalker,
      sessionId: 's1',
      baseUrl: 'http://portal.example.com',
      macAddress: 'AA:BB:CC:DD:EE:FF',
      portalToken: portalToken,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  group('StalkerStreamResolver', () {
    test('uses a direct source URL without contacting the portal', () async {
      final resolver = StalkerStreamResolver(logger: LoggingService());

      final result = await resolver.resolve(
        StreamResolutionRequest(
          session: session(),
          sourceUrl: 'http://portal.example.com',
          mediaItemId: 'ch-102',
          itemMetadata: const {
            'type': 'live',
            'streamUrl': 'http://cdn.example.com/live/102.ts',
          },
        ),
      );

      expect(result.url, 'http://cdn.example.com/live/102.ts');
      expect(result.streamType, StreamType.mpegTs);
    });

    test('exchanges a cmd via create_link for live channels', () async {
      final server = await PortalTestServer.start(handler: defaultHandler);
      addTearDown(server.close);

      final resolver = StalkerStreamResolver(logger: LoggingService());
      final result = await resolver.resolve(
        StreamResolutionRequest(
          session: session(
            portalToken: 'tok-abc-123',
          ).copyWith(baseUrl: server.baseUrl),
          sourceUrl: 'stub-id',
          mediaItemId: 'ch-101',
          itemMetadata: const {
            'type': 'live',
            'cmd': '101',
            'genreId': '1',
          },
        ),
      );

      expect(result.url, 'http://cdn.example.com/stream/101.m3u8?token=tok-abc-123');
      expect(result.capabilities.supportsPause, isTrue);
    });

    test('resolves VOD items with vod capabilities', () async {
      final server = await PortalTestServer.start(handler: defaultHandler);
      addTearDown(server.close);

      final resolver = StalkerStreamResolver(logger: LoggingService());
      final result = await resolver.resolve(
        StreamResolutionRequest(
          session: session(portalToken: 'tok-abc-123')
              .copyWith(baseUrl: server.baseUrl),
          sourceUrl: 'stub-id',
          mediaItemId: 'vod-501',
          itemMetadata: const {
            'type': 'vod',
            'cmd': '501',
            'genreId': '2',
          },
        ),
      );

      expect(result.url, 'http://cdn.example.com/stream/501.m3u8?token=tok-abc-123');
      expect(result.capabilities.supportsDownload, isTrue);
      expect(result.capabilities.supportsSeeking, isTrue);
    });

    test('throws when the item has no cmd and no direct URL', () async {
      final resolver = StalkerStreamResolver(logger: LoggingService());

      expect(
        () => resolver.resolve(
          StreamResolutionRequest(
            session: session(),
            sourceUrl: 'stub-id',
            mediaItemId: 'ch-missing',
            itemMetadata: const <String, dynamic>{},
          ),
        ),
        throwsA(isA<StreamResolutionException>()),
      );
    });

    test('throws when the session lacks a MAC address', () async {
      final server = await PortalTestServer.start(handler: defaultHandler);
      addTearDown(server.close);

      final resolver = StalkerStreamResolver(logger: LoggingService());
      final noMac = ProviderSession(
        providerId: 'p1',
        providerType: MediaSourceType.stalker,
        sessionId: 's1',
        baseUrl: server.baseUrl,
      );

      expect(
        () => resolver.resolve(
          StreamResolutionRequest(
            session: noMac,
            sourceUrl: 'stub-id',
            mediaItemId: 'ch-101',
            itemMetadata: const {
              'type': 'live',
              'cmd': '101',
            },
          ),
        ),
        throwsA(isA<StreamResolutionException>()),
      );
    });
  });
}
