import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/m3u_models.dart';
import 'package:stream_hub/data/providers/m3u/m3u_content_classifier.dart';

M3UChannel _channel({
  String url = 'http://example.com/live/stream.m3u8',
  String? group,
  Map<String, String> attributes = const {},
}) {
  return M3UChannel(
    id: 'ch-1',
    title: 'Test',
    streamUrl: url,
    group: group,
    attributes: attributes,
  );
}

void main() {
  group('M3UContentClassifier', () {
    group('tvg-type attribute', () {
      test('classifies movie by tvg-type', () {
        final channel = _channel(
          attributes: const {'tvg-type': 'movie'},
        );
        expect(M3UContentClassifier.classify(channel), MediaType.movie);
      });

      test('classifies vod tvg-type as movie', () {
        final channel = _channel(
          attributes: const {'tvg-type': 'vod'},
        );
        expect(M3UContentClassifier.classify(channel), MediaType.movie);
      });

      test('classifies series by tvg-type', () {
        final channel = _channel(
          attributes: const {'tvg-type': 'series'},
        );
        expect(M3UContentClassifier.classify(channel), MediaType.series);
      });

      test('classifies tvshow tvg-type as series', () {
        final channel = _channel(
          attributes: const {'tvg-type': 'tvshow'},
        );
        expect(M3UContentClassifier.classify(channel), MediaType.series);
      });

      test('classifies live tvg-type as channel', () {
        final channel = _channel(
          attributes: const {'tvg-type': 'live'},
        );
        expect(M3UContentClassifier.classify(channel), MediaType.channel);
      });

      test('tvg-type overrides url and group signals', () {
        final channel = _channel(
          url: 'http://example.com/live/stream.m3u8',
          group: 'Movies',
          attributes: const {'tvg-type': 'live'},
        );
        expect(M3UContentClassifier.classify(channel), MediaType.channel);
      });
    });

    group('url path', () {
      test('classifies /movie/ url as movie', () {
        final channel = _channel(
          url: 'http://example.com/movie/user/pass/1234.mp4',
        );
        expect(M3UContentClassifier.classify(channel), MediaType.movie);
      });

      test('classifies /series/ url as series', () {
        final channel = _channel(
          url: 'http://example.com/series/user/pass/5678.mp4',
        );
        expect(M3UContentClassifier.classify(channel), MediaType.series);
      });

      test('classifies /live/ url as channel', () {
        final channel = _channel(
          url: 'http://example.com/live/user/pass/9012.ts',
        );
        expect(M3UContentClassifier.classify(channel), MediaType.channel);
      });
    });

    group('group-title keywords', () {
      test('classifies movie group as movie', () {
        final channel = _channel(group: 'Action Movies');
        expect(M3UContentClassifier.classify(channel), MediaType.movie);
      });

      test('classifies series group as series', () {
        final channel = _channel(group: 'TV Series');
        expect(M3UContentClassifier.classify(channel), MediaType.series);
      });

      test('classifies plain news group as channel', () {
        final channel = _channel(group: 'News');
        expect(M3UContentClassifier.classify(channel), MediaType.channel);
      });

      test('classifies live sports group as channel', () {
        final channel = _channel(group: 'Live Sports');
        expect(M3UContentClassifier.classify(channel), MediaType.channel);
      });
    });
  });
}
