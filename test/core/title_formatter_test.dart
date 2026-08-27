import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/utils/title_formatter.dart';

void main() {
  group('TitleFormatter Tests', () {
    test('strips LIVE prefixes with colon, hyphen, pipe, or bracket', () {
      expect(TitleFormatter.formatChannelTitle('LIVE: ESPN HD'), 'ESPN HD');
      expect(TitleFormatter.formatChannelTitle('LIVE | Sky Sports 1'), 'Sky Sports 1');
      expect(TitleFormatter.formatChannelTitle('[LIVE] CNN News'), 'CNN News');
      expect(TitleFormatter.formatChannelTitle('(LIVE) BBC One'), 'BBC One');
      expect(TitleFormatter.formatChannelTitle('LIVE - Animal Planet'), 'Animal Planet');
      expect(TitleFormatter.formatChannelTitle('live: Discovery Channel'), 'Discovery Channel');
      expect(TitleFormatter.formatChannelTitle('US: LIVE: HBO'), 'HBO');
      expect(TitleFormatter.formatChannelTitle('UK | LIVE - TNT Sports'), 'TNT Sports');
    });

    test('leaves non-live titles unchanged', () {
      expect(TitleFormatter.formatChannelTitle('Inception (2010)'), 'Inception (2010)');
      expect(TitleFormatter.formatChannelTitle('Breaking Bad'), 'Breaking Bad');
      expect(TitleFormatter.formatChannelTitle('Alive'), 'Alive');
    });
  });
}
