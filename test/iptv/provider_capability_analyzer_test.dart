import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/iptv/detection/provider_capability_analyzer.dart';
import 'package:stream_hub/core/iptv/models/provider_detection.dart';

void main() {
  group('ProviderCapabilityAnalyzer', () {
    const analyzer = ProviderCapabilityAnalyzer();

    ProviderDetectionResult resultOf(DetectedProviderKind kind) {
      return ProviderDetectionResult(
        providerKind: kind,
        transportKind: SourceTransportKind.remoteHttps,
        compressionKind: SourceCompressionKind.none,
        confidence: 1.0,
      );
    }

    test('M3U providers expose catalog content and streaming features', () {
      final caps = analyzer.analyze(resultOf(DetectedProviderKind.m3u));
      expect(caps.supportsLiveTv, isTrue);
      expect(caps.supportsMovies, isTrue);
      expect(caps.supportsSeries, isTrue);
      expect(caps.supportsCatchup, isTrue);
      expect(caps.supportsEpg, isTrue);
      expect(caps.supportsAnonymousAccess, isTrue);
    });

    test('Xtream providers require credentials', () {
      final caps = analyzer.analyze(resultOf(DetectedProviderKind.xtream));
      expect(caps.requiresCredentials, isTrue);
      expect(caps.supportsAnonymousAccess, isFalse);
      expect(caps.supportsCatalogContent, isTrue);
    });

    test('Stalker providers require credentials but no custom headers', () {
      final caps = analyzer.analyze(resultOf(DetectedProviderKind.stalker));
      expect(caps.requiresCredentials, isTrue);
      expect(caps.supportsCustomHeaders, isFalse);
      expect(caps.supportsLiveTv, isTrue);
    });

    test('XMLTV is EPG-only', () {
      final caps = analyzer.analyze(resultOf(DetectedProviderKind.xmltv));
      expect(caps.supportsEpg, isTrue);
      expect(caps.supportsLiveTv, isFalse);
      expect(caps.supportsCatalogContent, isFalse);
    });

    test('unknown providers expose empty capabilities', () {
      final caps = analyzer.analyze(resultOf(DetectedProviderKind.unknown));
      expect(caps.supportsLiveTv, isFalse);
      expect(caps.supportedProtocols, isEmpty);
      expect(caps.supportsAnonymousAccess, isTrue);
    });

    test('config can override capabilities', () {
      final caps = analyzer.analyze(
        resultOf(DetectedProviderKind.m3u),
        config: const {'timeshift': false, 'customHeaders': true},
      );
      expect(caps.supportsTimeshift, isFalse);
      expect(caps.supportsCustomHeaders, isTrue);
    });
  });
}
