import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/data/models/dearbulut_dtos.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/parsers/free_tv_mapper.dart';
import 'package:stream_hub/data/remote/free_tv_remote_data_source.dart';
import 'package:stream_hub/data/services/free_tv_catalog_builder.dart';
import 'package:stream_hub/data/services/free_tv_service.dart';

class _FakeRemoteDataSource implements FreeTvRemoteDataSource {
  final List<DearbulutChannelDto> channels;
  final List<DearbulutCountryDto> countries;

  _FakeRemoteDataSource({
    this.channels = const [],
    this.countries = const [],
  });

  @override
  Future<List<DearbulutChannelDto>> fetchOnlineChannels({Duration? timeout}) async {
    return channels;
  }

  @override
  Future<List<DearbulutCountryDto>> fetchCountries({Duration? timeout}) async {
    return countries;
  }

  @override
  Future<List<DearbulutCategoryDto>> fetchCategories({Duration? timeout}) async {
    return const [];
  }

  @override
  Future<List<DearbulutChannelDto>> fetchChannelsByCountry(String countryCode, {Duration? timeout}) async {
    return channels.where((c) => c.country?.toUpperCase() == countryCode.toUpperCase()).toList();
  }

  @override
  Future<List<DearbulutChannelDto>> fetchChannelsByCategory(String categoryId, {Duration? timeout}) async {
    return channels.where((c) => c.categories.contains(categoryId)).toList();
  }
}

void main() {
  group('FreeTvService JSON pipeline', () {
    test('normalizer derives identity, country, category, and cleans names', () {
      final mapper = FreeTvMapper();
      const dto = DearbulutChannelDto(
        id: 'BBCNews.uk',
        name: 'BBC News',
        country: 'GB',
        categories: ['news', 'general'],
        languages: ['eng'],
        logo: 'https://logo.com/bbc.png',
        streams: [
          DearbulutStreamDto(
            url: 'https://bbc.stream/live.m3u8',
            quality: '1080p',
            health: DearbulutHealthDto(status: 'online', score: 100),
          )
        ],
      );

      final ch = mapper.fromDearbulutDto(dto, countryNameLookup: {'GB': 'United Kingdom'});
      expect(ch.id, 'BBCNews.uk');
      expect(ch.countryCode, 'GB');
      expect(ch.country, 'United Kingdom');
      expect(ch.region, 'Europe');
      expect(ch.name, 'BBC News');
      expect(ch.categories, containsAll(['News', 'General']));
      expect(ch.languages, contains('English'));
      expect(ch.streamUrls.single, 'https://bbc.stream/live.m3u8');
    });

    test('builds a unified deduplicated catalog across multiple channel records', () async {
      final fakeDs = _FakeRemoteDataSource(
        countries: const [
          DearbulutCountryDto(name: 'Nigeria', code: 'NG'),
          DearbulutCountryDto(name: 'India', code: 'IN'),
        ],
        channels: const [
          DearbulutChannelDto(
            id: 'ChannelsTV.ng',
            name: 'Channels TV',
            country: 'NG',
            categories: ['news'],
            languages: ['eng'],
            score: 95,
            online: true,
            streams: [
              DearbulutStreamDto(url: 'https://channelstv.stream/live.m3u8', quality: '720p')
            ],
          ),
          DearbulutChannelDto(
            id: 'ChannelsTV.ng',
            name: 'Channels TV HD',
            country: 'NG',
            categories: ['news', 'general'],
            languages: ['eng'],
            score: 98,
            online: true,
            streams: [
              DearbulutStreamDto(url: 'https://channelstv-hd.stream/live.m3u8', quality: '1080p')
            ],
          ),
          DearbulutChannelDto(
            id: 'TimesNow.in',
            name: 'Times Now HD',
            country: 'IN',
            categories: ['news'],
            languages: ['eng'],
            score: 92,
            online: true,
            streams: [
              DearbulutStreamDto(url: 'https://timesnow.stream/live.m3u8')
            ],
          ),
        ],
      );

      final builder = FreeTvCatalogBuilder(
        remoteDataSource: fakeDs,
      );

      final result = await builder.build();

      // Channels TV duplicate record is merged into 1 channel with 2 streams
      final channelsTv = result.allValid.where((c) => c.id == 'ChannelsTV.ng').toList();
      expect(channelsTv.length, 1);
      expect(channelsTv.single.countryCode, 'NG');
      expect(channelsTv.single.country, 'Nigeria');
      expect(channelsTv.single.streams.length, 2);
      expect(
        channelsTv.single.streamUrls,
        containsAll([
          'https://channelstv.stream/live.m3u8',
          'https://channelstv-hd.stream/live.m3u8',
        ]),
      );
      expect(channelsTv.single.categories, containsAll(['News', 'General']));

      // 2 unique channels total
      expect(result.allValid.length, 2);
      expect(result.diagnostics.duplicatesRemoved, 1);
    });

    test('filters out NSFW, invalid-URL, and junk-named entries', () async {
      final fakeDs = _FakeRemoteDataSource(
        channels: const [
          DearbulutChannelDto(
            id: 'NewsOK.us',
            name: 'News OK',
            country: 'US',
            categories: ['news'],
            languages: ['eng'],
            streams: [DearbulutStreamDto(url: 'https://ok.stream/live.m3u8')],
          ),
          // NSFW
          DearbulutChannelDto(
            id: 'Adult.us',
            name: 'Adult Channel',
            isNsfw: true,
            country: 'US',
            languages: ['eng'],
            streams: [DearbulutStreamDto(url: 'https://adult.stream/live.m3u8')],
          ),
          // Invalid URL scheme
          DearbulutChannelDto(
            id: 'Invalid.us',
            name: 'Invalid Url',
            country: 'US',
            languages: ['eng'],
            streams: [DearbulutStreamDto(url: 'ftp://bad.example/live')],
          ),
          // Junk token
          DearbulutChannelDto(
            id: 'TestChannel.us',
            name: 'Test Channel Demo',
            country: 'US',
            languages: ['eng'],
            streams: [DearbulutStreamDto(url: 'https://test.stream/live.m3u8')],
          ),
        ],
      );

      final builder = FreeTvCatalogBuilder(remoteDataSource: fakeDs);
      final result = await builder.build();

      final ids = result.allValid.map((c) => c.id).toList();
      expect(ids, contains('NewsOK.us'));
      expect(ids, isNot(contains('Adult.us')));
      expect(ids, isNot(contains('Invalid.us')));
      expect(ids, isNot(contains('TestChannel.us')));
      expect(result.diagnostics.nsfwRecords, 1);
    });

    test('assigns recommended tier to rich, preferred-category channels', () async {
      final fakeDs = _FakeRemoteDataSource(
        channels: const [
          DearbulutChannelDto(
            id: 'DocCh.de',
            name: 'Documentary Channel',
            country: 'DE',
            categories: ['documentary'],
            languages: ['eng'],
            logo: 'https://logo.com/doc.png',
            score: 95,
            online: true,
            streams: [
              DearbulutStreamDto(url: 'https://doc.stream/live1.m3u8', quality: '1080p')
            ],
          ),
          DearbulutChannelDto(
            id: 'MinCh.pl',
            name: 'Minimal Channel 2',
            country: '',
            categories: ['other'],
            languages: ['eng'],
            score: 10,
            online: false,
            streams: [
              DearbulutStreamDto(url: 'https://min.stream/live.m3u8')
            ],
          ),
        ],
      );

      final builder = FreeTvCatalogBuilder(remoteDataSource: fakeDs);
      final result = await builder.build();

      final docCh = result.allValid.firstWhere((c) => c.id == 'DocCh.de');
      expect(docCh.qualityTier, FreeTvQualityTier.recommended);
      expect(docCh.qualityScore, greaterThanOrEqualTo(55));

      final minCh = result.allValid.firstWhere((c) => c.id == 'MinCh.pl');
      expect(minCh.qualityTier, FreeTvQualityTier.valid);

      expect(result.recommended.map((c) => c.id), contains('DocCh.de'));
    });

    test('FreeTvService exposes curated recommended subset', () async {
      final fakeDs = _FakeRemoteDataSource(
        channels: const [
          DearbulutChannelDto(
            id: 'BigNews.us',
            name: 'Big News',
            country: 'US',
            categories: ['news'],
            languages: ['eng'],
            logo: 'https://logo.com/big.png',
            score: 95,
            online: true,
            streams: [
              DearbulutStreamDto(url: 'https://big.stream/live.m3u8', quality: '1080p')
            ],
          )
        ],
      );

      final service = FreeTvService(
        builder: FreeTvCatalogBuilder(remoteDataSource: fakeDs),
      );

      final catalog = await service.fetchCatalog();
      expect(catalog.length, 1);
      expect(catalog.single.id, 'BigNews.us');
      expect(catalog.single.qualityTier, FreeTvQualityTier.recommended);

      final recommended = await service.fetchRecommended();
      expect(recommended.map((c) => c.id), contains('BigNews.us'));
    });
  });
}
