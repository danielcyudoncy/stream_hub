import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/data/parsers/xmltv_parser.dart';

void main() {
  group('XMLTVParser', () {
    late XMLTVParser parser;

    setUp(() {
      parser = XMLTVParser();
    });

    group('parse', () {
      test('parses a small valid XMLTV guide', () {
        final content = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE tv SYSTEM "xmltv.dtd">
<tv generator-info-name="Test">
  <channel id="ch1">
    <display-name>News Channel</display-name>
    <icon src="http://example.com/news.png"/>
  </channel>
  <programme start="20260101120000 +0000" stop="20260101130000 +0000" channel="ch1">
    <title>News at Noon</title>
    <desc>Latest news updates</desc>
    <category>News</category>
  </programme>
</tv>''';

        final guide = parser.parse(content, sourceId: 'test-source');

        expect(guide.channels.length, 1);
        expect(guide.programs.length, 1);
        expect(guide.channels.first.displayName, 'News Channel');
        expect(guide.programs.first.title, 'News at Noon');
        expect(guide.programs.first.description, 'Latest news updates');
        expect(guide.programs.first.categories, contains('News'));
      });

      test('parses multiple channels and programmes', () {
        final content = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="ch1">
    <display-name>Channel 1</display-name>
  </channel>
  <channel id="ch2">
    <display-name>Channel 2</display-name>
  </channel>
  <programme start="20260101120000 +0000" stop="20260101130000 +0000" channel="ch1">
    <title>Program 1</title>
  </programme>
  <programme start="20260101130000 +0000" stop="20260101140000 +0000" channel="ch2">
    <title>Program 2</title>
  </programme>
</tv>''';

        final guide = parser.parse(content, sourceId: 'test-source');

        expect(guide.channels.length, 2);
        expect(guide.programs.length, 2);
      });

      test('parses programme metadata fields', () {
        final content = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="ch1">
    <display-name>Test Channel</display-name>
  </channel>
  <programme start="20260101120000 +0000" stop="20260101130000 +0000" channel="ch1">
    <title>Main Title</title>
    <sub-title>Sub Title</sub-title>
    <desc>Full description of the programme</desc>
    <category>Drama</category>
    <category>Thriller</category>
    <language>en</language>
    <country>US</country>
    <episode-num system="xmltv_ns">1.2.0</episode-num>
    <rating>
      <value>PG</value>
    </rating>
    <credits>
      <director>John Director</director>
      <actor>Jane Actor</actor>
      <writer>Bob Writer</writer>
    </credits>
    <icon src="http://example.com/poster.jpg"/>
    <new/>
    <premiere/>
    <video>
      <aspect>16:9</aspect>
      <quality>HD</quality>
      <codec>H.264</codec>
    </video>
    <audio>
      <stereo>true</stereo>
      <codec>AAC</codec>
      <channels>2</channels>
    </audio>
    <subtitles>
      <language>en</language>
      <format>SRT</format>
    </subtitles>
  </programme>
</tv>''';

        final guide = parser.parse(content, sourceId: 'test-source');
        final program = guide.programs.first;

        expect(program.title, 'Main Title');
        expect(program.subtitle, 'Sub Title');
        expect(program.description, 'Full description of the programme');
        expect(program.categories, contains('Drama'));
        expect(program.categories, contains('Thriller'));
        expect(program.language, 'en');
        expect(program.country, 'US');
        expect(program.episodeNum, '1.2.0');
        expect(program.rating, isNull);
        expect(program.directors, contains('John Director'));
        expect(program.cast, contains('Jane Actor'));
        expect(program.writers, contains('Bob Writer'));
        expect(program.poster, 'http://example.com/poster.jpg');
        expect(program.isNew, isTrue);
        expect(program.isPremiere, isTrue);
        expect(program.videoAspect, '16:9');
        expect(program.videoQuality, 'HD');
        expect(program.videoCodec, 'H.264');
        expect(program.audioStereo, 'true');
        expect(program.audioCodec, 'AAC');
        expect(program.audioChannels, 2);
        expect(program.subtitleLanguages, contains('en'));
      });

      test('handles malformed XML gracefully', () {
        final content = '''<?xml version="1.0"?>
<tv>
  <channel id="ch1">
    <display-name>Test</display-name>
  </channel>
  <programme start="invalid-date" stop="20260101130000 +0000" channel="ch1">
    <title>Program</title>
  </programme>
</tv>''';

        final guide = parser.parse(content, sourceId: 'test-source');

        expect(guide.channels.length, 1);
        expect(guide.programs.length, 1);
      });

      test('handles missing channel attribute', () {
        final content = '''<?xml version="1.0"?>
<tv>
  <programme start="20260101120000 +0000" stop="20260101130000 +0000">
    <title>Orphan Program</title>
  </programme>
</tv>''';

        final guide = parser.parse(content, sourceId: 'test-source');

        expect(guide.programs.length, 0);
      });

      test('handles programme without title', () {
        final content = '''<?xml version="1.0"?>
<tv>
  <channel id="ch1">
    <display-name>Test</display-name>
  </channel>
  <programme start="20260101120000 +0000" stop="20260101130000 +0000" channel="ch1">
    <desc>No title program</desc>
  </programme>
</tv>''';

        final guide = parser.parse(content, sourceId: 'test-source');

        expect(guide.programs.length, 0);
      });

      test('handles duplicate programmes', () {
        final content = '''<?xml version="1.0"?>
<tv>
  <channel id="ch1">
    <display-name>Test</display-name>
  </channel>
  <programme start="20260101120000 +0000" stop="20260101130000 +0000" channel="ch1">
    <title>Duplicate Program</title>
  </programme>
  <programme start="20260101120000 +0000" stop="20260101130000 +0000" channel="ch1">
    <title>Duplicate Program</title>
  </programme>
</tv>''';

        final guide = parser.parse(content, sourceId: 'test-source');

        expect(guide.programs.length, 2);
      });

      test('handles large XMLTV guide', () {
        final buffer = StringBuffer('<?xml version="1.0"?>\n<tv>\n');
        buffer.write('<channel id="ch1"><display-name>Test</display-name></channel>\n');

        for (int i = 0; i < 1000; i++) {
          buffer.write(
            '<programme start="20260101${i.toString().padLeft(2, '0')}0000 +0000" stop="20260101${i.toString().padLeft(2, '0')}5900 +0000" channel="ch1">\n',
          );
          buffer.write('<title>Program $i</title>\n');
          buffer.write('</programme>\n');
        }

        buffer.write('</tv>');

        final guide = parser.parse(buffer.toString(), sourceId: 'test-source');

        expect(guide.programs.length, 1000);
        expect(guide.channels.length, 1);
      });

      test('parses star-rating', () {
        final content = '''<?xml version="1.0"?>
<tv>
  <channel id="ch1">
    <display-name>Test</display-name>
  </channel>
  <programme start="20260101120000 +0000" stop="20260101130000 +0000" channel="ch1">
    <title>Rated Program</title>
    <star-rating>
      <value>4.5</value>
    </star-rating>
  </programme>
</tv>''';

        final guide = parser.parse(content, sourceId: 'test-source');
        final program = guide.programs.first;

        expect(program.rating, 4.5);
      });

      test('parses previously-shown flag', () {
        final content = '''<?xml version="1.0"?>
<tv>
  <channel id="ch1">
    <display-name>Test</display-name>
  </channel>
  <programme start="20260101120000 +0000" stop="20260101130000 +0000" channel="ch1">
    <title>Repeat Show</title>
    <previously-shown/>
  </programme>
</tv>''';

        final guide = parser.parse(content, sourceId: 'test-source');
        final program = guide.programs.first;

        expect(program.isPreviouslyShown, isTrue);
      });

      test('parses channel aliases', () {
        final content = '''<?xml version="1.0"?>
<tv>
  <channel id="ch1">
    <display-name>Main Name</display-name>
    <alias name="Alias 1"/>
    <alias name="Alias 2"/>
  </channel>
  <programme start="20260101120000 +0000" stop="20260101130000 +0000" channel="ch1">
    <title>Test Program</title>
  </programme>
</tv>''';

        final guide = parser.parse(content, sourceId: 'test-source');
        final channel = guide.channels.first;

        expect(channel.aliases, contains('Alias 1'));
        expect(channel.aliases, contains('Alias 2'));
      });
    });
  });
}