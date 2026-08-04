import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/iptv/models/provider_detection.dart';
import 'package:stream_hub/core/iptv/playlist/playlist_analyzer.dart';

const samplePlaylist = '''
#EXTM3U x-tvg-url="https://epg.example.com/guide.xml.gz" user-agent="TestAgent" referer="https://example.com"
#EXTINF:-1 tvg-id="cnn" group-title="News", CNN HD
http://example.com/cnn.ts
#EXTINF:-1 tvg-id="bbcmovie" group-title="Movies", BBC Movie
http://example.com/movie.mp4
#EXTINF:-1 group-title="Series", Stranger Things S1E1
http://example.com/series/stranger/1.ts
#EXTINF:-1 tvg-id="radio1" group-title="Music" radio="true", Radio One
http://example.com/radio.ts
''';

void main() {
  group('PlaylistAnalyzer', () {
    final analyzer = PlaylistAnalyzer();

    test('analyzes a playlist and classifies entries', () {
      final result = analyzer.analyze(samplePlaylist);
      expect(result.hasContent, isTrue);
      expect(result.items.length, 4);
      expect(result.channelCount, 1);
      expect(result.movieCount, 1);
      expect(result.seriesCount, 1);
      expect(result.radioCount, 1);
      expect(result.stats.totalEntries, 4);
      expect(result.stats.validEntries, 4);
      expect(result.stats.hasValidHeader, isTrue);
    });

    test('extracts header metadata', () {
      final result = analyzer.analyze(samplePlaylist);
      expect(result.epgSources, contains('https://epg.example.com/guide.xml.gz'));
      expect(result.userAgent, 'TestAgent');
      expect(result.referer, 'https://example.com');
      expect(result.headers['User-Agent'], 'TestAgent');
      expect(result.headers['Referer'], 'https://example.com');
    });

    test('extracts groups', () {
      final result = analyzer.analyze(samplePlaylist);
      expect(result.groups, containsAll(['News', 'Movies', 'Series', 'Music']));
    });

    test('computes protocol distribution', () {
      final result = analyzer.analyze(samplePlaylist);
      expect(result.protocolDistribution['MPEG-TS'], 3);
      expect(result.protocolDistribution['MP4'], 1);
    });

    test('reports empty content as an error', () {
      final result = analyzer.analyze('   ');
      expect(result.errors, isNotEmpty);
      expect(result.hasContent, isFalse);
      expect(result.stats.hasValidHeader, isFalse);
    });

    test('preserves the detected provider kind', () {
      final result = analyzer.analyze(
        samplePlaylist,
        providerKind: DetectedProviderKind.m3u,
      );
      expect(result.providerKind, DetectedProviderKind.m3u);
    });
  });
}
