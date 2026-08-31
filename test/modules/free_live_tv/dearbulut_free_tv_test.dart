import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/data/models/dearbulut_dtos.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/models/free_tv_stream.dart';
import 'package:stream_hub/data/parsers/free_tv_mapper.dart';
import 'package:stream_hub/data/remote/free_tv_remote_data_source.dart';
import 'package:stream_hub/data/services/free_tv_catalog_builder.dart';
import 'package:stream_hub/data/services/free_tv_quality_service.dart';
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
  group('dearbulut/iptv Free TV JSON Integration', () {
    late FreeTvMapper mapper;
    late FreeTvQualityService qualityService;

    setUp(() {
      mapper = FreeTvMapper();
      qualityService = FreeTvQualityService();
    });

    test('DearbulutChannelDto parses json correctly', () {
      final json = {
        'id': 'BBCNews.uk',
        'name': 'BBC News',
        'alt_names': ['BBC News HD'],
        'network': 'BBC',
        'country': 'GB',
        'subdivision': 'ENG',
        'categories': ['news', 'general'],
        'languages': ['eng'],
        'is_nsfw': false,
        'website': 'https://bbc.com/news',
        'logo': 'https://i.imgur.com/bbc.png',
        'score': 95.5,
        'online': true,
        'stream_count': 1,
        'best_quality': '1080p',
        'streams': [
          {
            'channel': 'BBCNews.uk',
            'feed': 'NorthAmerica',
            'title': 'BBC News NA',
            'url': 'https://stream.bbc/live.m3u8',
            'quality': '1080p',
            'health': {
              'status': 'online',
              'score': 100,
              'uptime': 99.8,
              'latency_ms': 120,
              'media': {
                'resolution': '1080p',
                'bitrate': 3200000,
                'height': 1080,
              }
            }
          }
        ]
      };

      final dto = DearbulutChannelDto.fromJson(json);
      expect(dto.id, 'BBCNews.uk');
      expect(dto.name, 'BBC News');
      expect(dto.score, 95.5);
      expect(dto.online, isTrue);
      expect(dto.streams.length, 1);
      expect(dto.streams.first.health?.status, 'online');
      expect(dto.streams.first.health?.media?.height, 1080);
    });

    test('FreeTvMapper normalizes dto into domain model', () {
      final dto = DearbulutChannelDto(
        id: 'AriseNews.ng',
        name: 'Arise News',
        altNames: const ['Arise News HD'],
        network: 'Arise Media',
        country: 'NG',
        categories: const ['news'],
        languages: const ['eng'],
        isNsfw: false,
        website: 'https://arise.tv',
        logo: 'https://i.imgur.com/arise.png',
        score: 98.0,
        online: true,
        bestQuality: '1080p',
        streams: const [
          DearbulutStreamDto(
            url: 'https://arise.stream/live.m3u8',
            quality: '1080p',
            title: 'Main Stream',
            health: DearbulutHealthDto(
              status: 'online',
              score: 99.0,
              uptime: 100.0,
              latencyMs: 85,
              media: DearbulutMediaDto(
                height: 1080,
                bitrate: 2500000,
                resolution: '1080p',
              ),
            ),
          )
        ],
      );

      final channel = mapper.fromDearbulutDto(
        dto,
        countryNameLookup: {'NG': 'Nigeria'},
      );

      expect(channel.id, 'AriseNews.ng');
      expect(channel.name, 'Arise News');
      expect(channel.country, 'Nigeria');
      expect(channel.countryCode, 'NG');
      expect(channel.region, 'Africa');
      expect(channel.categories, contains('News'));
      expect(channel.languages, contains('English'));
      expect(channel.source, 'dearbulut');
      expect(channel.isWorking, isTrue);
      expect(channel.hasStream, isTrue);
      expect(channel.primaryStreamUrl, 'https://arise.stream/live.m3u8');
      expect(channel.streams.length, 1);
      expect(channel.streams.first.height, 1080);
    });

    test('FreeTvQualityService scores and assigns recommended tier to rich channels', () {
      const richChannel = FreeTvChannel(
        id: 'CNN.us',
        name: 'CNN International',
        country: 'United States',
        countryCode: 'US',
        region: 'Americas',
        categories: ['News', 'General'],
        languages: ['English'],
        logo: 'https://cdn.logo/cnn.png',
        isWorking: true,
        streams: [
          FreeTvStream(
            url: 'https://cnn.stream/live.m3u8',
            quality: '1080p',
            height: 1080,
            isOnline: true,
            healthScore: 98.0,
          ),
          FreeTvStream(
            url: 'https://cnn.backup/live.m3u8',
            quality: '720p',
            height: 720,
            isOnline: true,
            healthScore: 95.0,
          )
        ],
        streamUrls: [
          'https://cnn.stream/live.m3u8',
          'https://cnn.backup/live.m3u8',
        ],
      );

      expect(qualityService.isEligible(richChannel), isTrue);
      final tiered = qualityService.assignTier(richChannel);
      expect(tiered.qualityTier, FreeTvQualityTier.recommended);
      expect(tiered.qualityScore, greaterThanOrEqualTo(55));
    });

    test('FreeTvQualityService excludes NSFW, test, and missing stream channels', () {
      const nsfwChannel = FreeTvChannel(
        id: 'nsfw-1',
        name: 'Adult Channel',
        country: 'US',
        countryCode: 'US',
        isNsfw: true,
        streamUrls: ['https://stream.example/live.m3u8'],
      );
      expect(qualityService.isEligible(nsfwChannel), isFalse);

      const testChannel = FreeTvChannel(
        id: 'test-1',
        name: 'Test Stream Live Demo',
        country: 'US',
        countryCode: 'US',
        streamUrls: ['https://stream.example/live.m3u8'],
      );
      expect(qualityService.isEligible(testChannel), isFalse);

      const noStreamChannel = FreeTvChannel(
        id: 'no-stream',
        name: 'Dead Channel',
        country: 'US',
        countryCode: 'US',
        streamUrls: [],
      );
      expect(qualityService.isEligible(noStreamChannel), isFalse);
    });

    test('FreeTvCatalogBuilder builds deduplicated catalog and provides diagnostics', () async {
      final fakeDataSource = _FakeRemoteDataSource(
        countries: const [
          DearbulutCountryDto(name: 'Nigeria', code: 'NG'),
          DearbulutCountryDto(name: 'United Kingdom', code: 'GB'),
        ],
        channels: const [
          DearbulutChannelDto(
            id: 'ChannelsTV.ng',
            name: 'Channels TV',
            country: 'NG',
            categories: ['news'],
            languages: ['eng'],
            logo: 'https://logo/channels.png',
            score: 96,
            online: true,
            streams: [
              DearbulutStreamDto(
                url: 'https://channelstv.stream/live1.m3u8',
                quality: '1080p',
                health: DearbulutHealthDto(status: 'online', score: 100),
              )
            ],
          ),
          // Duplicate channel ID with backup stream
          DearbulutChannelDto(
            id: 'ChannelsTV.ng',
            name: 'Channels TV Backup',
            country: 'NG',
            categories: ['news', 'general'],
            languages: ['eng'],
            logo: 'https://logo/channels.png',
            score: 90,
            online: true,
            streams: [
              DearbulutStreamDto(
                url: 'https://channelstv.stream/live2.m3u8',
                quality: '720p',
                health: DearbulutHealthDto(status: 'online', score: 95),
              )
            ],
          ),
          // Non-English channel (Spanish)
          DearbulutChannelDto(
            id: 'Telemundo.es',
            name: 'Telemundo España',
            country: 'ES',
            categories: ['entertainment'],
            languages: ['spa'],
            logo: 'https://logo/telemundo.png',
            score: 90,
            online: true,
            streams: [
              DearbulutStreamDto(url: 'https://telemundo/live.m3u8'),
            ],
          ),
          // Obvious Test Channel
          DearbulutChannelDto(
            id: 'Test.ng',
            name: 'Test Feed Demo',
            country: 'NG',
            languages: ['eng'],
            streams: [
              DearbulutStreamDto(url: 'https://test/live.m3u8'),
            ],
          ),
        ],
      );

      final builder = FreeTvCatalogBuilder(
        remoteDataSource: fakeDataSource,
        mapper: mapper,
        quality: qualityService,
      );

      final result = await builder.build();

      expect(result.allValid.length, 1);
      final channel = result.allValid.single;
      expect(channel.id, 'ChannelsTV.ng');
      expect(channel.streams.length, 2);
      expect(result.diagnostics.duplicatesRemoved, 1);
      expect(result.diagnostics.invalidRecords, 1);
      expect(result.diagnostics.nonEnglishRecords, 1);
      expect(result.recommended.length, 1);
    });

    test('FreeTvService wraps catalog builder and returns recommended list', () async {
      final fakeDataSource = _FakeRemoteDataSource(
        countries: const [DearbulutCountryDto(name: 'Nigeria', code: 'NG')],
        channels: const [
          DearbulutChannelDto(
            id: 'NTA.ng',
            name: 'NTA News 24',
            country: 'NG',
            categories: ['news'],
            languages: ['eng'],
            logo: 'https://logo/nta.png',
            score: 92,
            online: true,
            streams: [
              DearbulutStreamDto(
                url: 'https://nta.stream/live.m3u8',
                quality: '720p',
                health: DearbulutHealthDto(status: 'online', score: 95),
              )
            ],
          )
        ],
      );

      final service = FreeTvService(
        builder: FreeTvCatalogBuilder(
          remoteDataSource: fakeDataSource,
          mapper: mapper,
          quality: qualityService,
        ),
      );

      final catalog = await service.fetchCatalog();
      expect(catalog.length, 1);
      expect(catalog.first.name, 'NTA News 24');

      final recommended = await service.fetchRecommended();
      expect(recommended.length, 1);
      expect(service.lastDiagnostics, isNotNull);
    });
  });
}
