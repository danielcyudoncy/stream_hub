import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/iptv/models/stream_protocol.dart';
import 'package:stream_hub/core/iptv/negotiation/stream_negotiation_engine.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';

void main() {
  group('StreamNegotiationEngine', () {
    final engine = StreamNegotiationEngine();

    PlayableSession sessionFor(String url, {StreamType streamType = StreamType.unknown}) {
      return PlayableSession(
        sessionId: 's1',
        mediaItemId: 'ch-1',
        providerId: 'prov-1',
        providerType: MediaSourceType.m3u,
        streamUrl: url,
        streamType: streamType,
      );
    }

    test('negotiates HLS with a VLC-preferred player', () async {
      final negotiated = await engine.negotiate(
        session: sessionFor('https://example.com/live/ch1.m3u8'),
        withAnalysis: false,
      );
      expect(negotiated.protocol, StreamProtocol.hls);
      expect(negotiated.streamType, StreamType.hls);
      expect(negotiated.playerName, 'VLC');
      expect(negotiated.playerNegotiation.supportLevel, PlayerSupportLevel.supported);
      expect(negotiated.isPlayable, isTrue);
      expect(negotiated.isAdaptive, isTrue);
    });

    test('negotiates MPEG-TS over HTTP', () async {
      final negotiated = await engine.negotiate(
        session: sessionFor('https://example.com/live/ch1.ts'),
        withAnalysis: false,
      );
      expect(negotiated.protocol, StreamProtocol.mpegTs);
      expect(negotiated.isPlayable, isTrue);
    });

    test('negotiates progressive MP4', () async {
      final negotiated = await engine.negotiate(
        session: sessionFor('https://example.com/video.mp4'),
        withAnalysis: false,
      );
      expect(negotiated.protocol, StreamProtocol.mp4);
      expect(StreamProtocol.mp4.isSeekable, isTrue);
    });

    test('unknown protocol is not playable', () async {
      final negotiated = await engine.negotiate(
        session: sessionFor('garbage'),
        withAnalysis: false,
      );
      expect(negotiated.protocol, StreamProtocol.unknown);
      expect(negotiated.isPlayable, isFalse);
      expect(negotiated.playerNegotiation.engine, PlaybackEngineKind.fallback);
    });

    test('negotiates UDP multicast for VLC with fallbacks', () async {
      final negotiated = await engine.negotiate(
        session: sessionFor('udp://239.0.0.1:1234'),
        withAnalysis: false,
      );
      expect(negotiated.protocol, StreamProtocol.udp);
      expect(negotiated.playerNegotiation.supportLevel, PlayerSupportLevel.supported);
      expect(negotiated.playerNegotiation.fallbackEngines, isNotEmpty);
      expect(negotiated.isPlayable, isTrue);
    });

    test('merges explicit session capabilities into negotiation', () async {
      final negotiated = await engine.negotiate(
        session: sessionFor('https://example.com/video.mp4').copyWith(
          supportsPause: false,
          supportsDownload: true,
        ),
        withAnalysis: false,
      );
      expect(negotiated.capabilities.supportsPause, isFalse);
      expect(negotiated.capabilities.supportsDownload, isTrue);
      expect(negotiated.capabilities.supportsSeeking, isTrue);
    });

    test('extracts backup URLs from session metadata', () async {
      final negotiated = await engine.negotiate(
        session: sessionFor('https://example.com/primary.m3u8').copyWith(
          metadata: {
            'backupUrls': ['https://example.com/backup.m3u8'],
          },
        ),
        withAnalysis: false,
      );
      expect(negotiated.fallbackUrls, contains('https://example.com/backup.m3u8'));
    });
  });
}
