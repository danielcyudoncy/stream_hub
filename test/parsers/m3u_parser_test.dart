import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/data/parsers/m3u_parser.dart';

void main() {
  group('M3UParser', () {
    late M3UParser parser;

    setUp(() {
      parser = M3UParser();
    });

    group('parse', () {
      test('parses a small valid playlist', () {
        final content = '''#EXTM3U
#EXTINF:-1 tvg-id="ch1" tvg-name="News" group-title="News",News Channel
http://example.com/stream1.m3u8
#EXTINF:-1 tvg-id="ch2" tvg-name="Sports" group-title="Sports",Sports HD
http://example.com/stream2.m3u8
''';

        final result = parser.parse(content);

        expect(result.hasValidHeader, isTrue);
        expect(result.channels.length, 2);
        expect(result.groups, contains('News'));
        expect(result.groups, contains('Sports'));
        expect(result.validEntries, 2);
        expect(result.invalidEntries, 0);
      });

      test('parses playlist with radio flag', () {
        final content = '''#EXTM3U
#EXTINF:-1 radio="true" group-title="Music",Radio One
http://example.com/radio1.m3u8
''';

        final result = parser.parse(content);

        expect(result.channels.length, 1);
        expect(result.channels.first.isRadio, isTrue);
        expect(result.channels.first.group, 'Music');
      });

      test('parses playlist with catchup attributes', () {
        final content = '''#EXTM3U
#EXTINF:-1 catchup="true" catchup-days="7" catchup-source="http://example.com/catchup/{timestamp}",Catchup Channel
http://example.com/stream.m3u8
''';

        final result = parser.parse(content);

        expect(result.channels.length, 1);
        expect(result.channels.first.catchup['days'], '7');
        expect(result.channels.first.catchup['source'], 'http://example.com/catchup/{timestamp}');
      });

      test('detects duplicate URLs', () {
        final content = '''#EXTM3U
#EXTINF:-1,Channel One
http://example.com/stream.m3u8
#EXTINF:-1,Channel Two
http://example.com/stream.m3u8
''';

        final result = parser.parse(content);

        expect(result.duplicateEntries, 1);
        expect(result.warnings.length, greaterThan(0));
      });

      test('flags malformed entries without metadata', () {
        final content = '''#EXTM3U
http://example.com/stream.m3u8
''';

        final result = parser.parse(content);

        expect(result.invalidEntries, 1);
        expect(result.warnings.any((w) => w.contains('missing required metadata')), isTrue);
      });

      test('ignores empty lines', () {
        final content = '''#EXTM3U

#EXTINF:-1,Channel One
http://example.com/stream.m3u8

''';

        final result = parser.parse(content);

        expect(result.channels.length, 1);
      });

      test('handles missing header gracefully', () {
        final content = '''#EXTINF:-1,Channel One
http://example.com/stream.m3u8
''';

        final result = parser.parse(content);

        expect(result.hasValidHeader, isFalse);
        expect(result.channels.length, 1);
      });

      test('parses language and country attributes', () {
        final content = '''#EXTM3U
#EXTINF:-1 language="en" country="US",English Channel
http://example.com/stream.m3u8
''';

        final result = parser.parse(content);

        expect(result.channels.first.language, 'en');
        expect(result.channels.first.country, 'US');
        expect(result.languages, contains('en'));
        expect(result.countries, contains('US'));
      });

      test('handles malformed EXTINF line', () {
        final content = '''#EXTM3U
#EXTINF:-1
http://example.com/stream.m3u8
''';

        final result = parser.parse(content);

        expect(result.warnings.length, greaterThan(0));
      });

      test('supports large playlist with many channels', () {
        final buffer = StringBuffer('#EXTM3U\n');
        for (int i = 0; i < 1000; i++) {
          buffer.write('#EXTINF:-1 group-title="Group $i",Channel $i\n');
          buffer.write('http://example.com/stream$i.m3u8\n');
        }

        final result = parser.parse(buffer.toString());

        expect(result.channels.length, 1000);
        expect(result.groups.length, 1000);
      });
    });

    group('validate', () {
      test('returns valid for correct playlist', () {
        final content = '''#EXTM3U
#EXTINF:-1,Channel One
http://example.com/stream.m3u8
''';

        final result = parser.validate(content);

        expect(result.isValid, isTrue);
        expect(result.hasValidHeader, isTrue);
      });

      test('returns invalid for empty content', () {
        final result = parser.validate('');

        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.contains('empty')), isTrue);
      });

      test('warns about missing header', () {
        final content = '''#EXTINF:-1,Channel One
http://example.com/stream.m3u8
''';

        final result = parser.validate(content);

        expect(result.hasValidHeader, isFalse);
        expect(result.warnings.any((w) => w.contains('Missing #EXTM3U header')), isTrue);
      });

      test('detects duplicate URLs', () {
        final content = '''#EXTM3U
#EXTINF:-1,Channel One
http://example.com/stream.m3u8
#EXTINF:-1,Channel Two
http://example.com/stream.m3u8
''';

        final result = parser.validate(content);

        expect(result.duplicateCount, 1);
      });
    });
  });
}
