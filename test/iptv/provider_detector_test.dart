import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/iptv/detection/provider_detector.dart';
import 'package:stream_hub/core/iptv/models/provider_detection.dart';

void main() {
  group('ProviderDetector', () {
    final detector = ProviderDetector();

    test('detects an M3U playlist header', () {
      final result = detector.detect(
        const ProviderInput(content: '#EXTM3U\n#EXTINF:-1,CNN\nhttp://x/1.ts'),
      );
      expect(result.providerKind, DetectedProviderKind.m3u);
      expect(result.confidence, 1.0);
      expect(result.transportKind, SourceTransportKind.inlineContent);
      expect(result.compressionKind, SourceCompressionKind.none);
      expect(result.matchedSignals, isNotEmpty);
    });

    test('detects an M3U8 URL', () {
      final result = detector.detect(
        const ProviderInput(url: 'https://example.com/list.m3u8'),
      );
      expect(result.providerKind, DetectedProviderKind.m3u);
      expect(result.transportKind, SourceTransportKind.remoteHttps);
    });

    test('detects an Xtream API endpoint', () {
      final result = detector.detect(
        const ProviderInput(
          url: 'https://example.com/get.php?username=user&password=pass',
        ),
      );
      expect(result.providerKind, DetectedProviderKind.xtream);
      expect(result.confidence, 1.0);
    });

    test('detects an Xtream server layout', () {
      final result = detector.detect(
        const ProviderInput(url: 'http://example.com:8080/user/pass'),
      );
      expect(result.providerKind, DetectedProviderKind.xtream);
      expect(result.confidence, 0.9);
    });

    test('detects a Stalker portal', () {
      final result = detector.detect(
        const ProviderInput(
          url: 'http://portal.example.com/stalker_portal/server/load.php?mac=00:11:22:33:44:55',
        ),
      );
      expect(result.providerKind, DetectedProviderKind.stalker);
      expect(result.confidence, 1.0);
    });

    test('detects XMLTV from content', () {
      final result = detector.detect(
        const ProviderInput(
          content: '<?xml version="1.0"?><tv><channel id="x"/></tv>',
        ),
      );
      expect(result.providerKind, DetectedProviderKind.xmltv);
      expect(result.confidence, 0.95);
    });

    test('detects a local file path', () {
      final result = detector.detect(
        const ProviderInput(url: '/home/user/playlist.txt'),
      );
      expect(result.providerKind, DetectedProviderKind.local);
      expect(result.transportKind, SourceTransportKind.localFile);
    });

    test('detects gzip compression from URL suffix', () {
      final result = detector.detect(
        const ProviderInput(url: 'https://example.com/guide.xml.gz'),
      );
      expect(result.compressionKind, SourceCompressionKind.gzip);
      expect(result.providerKind, DetectedProviderKind.xmltv);
    });

    test('returns unknown for unrecognized input', () {
      final result = detector.detect(
        const ProviderInput(content: 'definitely not a playlist'),
      );
      expect(result.providerKind, DetectedProviderKind.unknown);
      expect(result.isKnown, isFalse);
      expect(result.warnings, isNotEmpty);
    });
  });
}
