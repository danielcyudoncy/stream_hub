import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/data/models/dearbulut_dtos.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/models/free_tv_stream.dart';
import 'package:stream_hub/data/parsers/free_tv_mapper.dart';
import 'package:stream_hub/data/remote/free_tv_remote_data_source.dart';
import 'package:stream_hub/data/services/free_tv_catalog_builder.dart';
import 'package:stream_hub/data/services/free_tv_quality_service.dart';

class _FakeDearbulutRemoteDataSource implements FreeTvRemoteDataSource {
  final List<DearbulutChannelDto> channels;

  _FakeDearbulutRemoteDataSource({
    this.channels = const [],
  });

  @override
  Future<List<DearbulutChannelDto>> fetchOnlineChannels({Duration? timeout}) async => channels;

  @override
  Future<List<DearbulutCountryDto>> fetchCountries({Duration? timeout}) async => const [];

  @override
  Future<List<DearbulutCategoryDto>> fetchCategories({Duration? timeout}) async => const [];

  @override
  Future<List<DearbulutChannelDto>> fetchChannelsByCountry(String countryCode, {Duration? timeout}) async =>
      channels.where((c) => c.country?.toUpperCase() == countryCode.toUpperCase()).toList();

  @override
  Future<List<DearbulutChannelDto>> fetchChannelsByCategory(String categoryId, {Duration? timeout}) async =>
      channels.where((c) => c.categories.contains(categoryId)).toList();
}

void main() {
  group('FreeTvCatalogBuilder Dual-Source Tests', () {
    late FreeTvMapper mapper;
    late FreeTvQualityService qualityService;

    setUp(() {
      mapper = FreeTvMapper();
      qualityService = const FreeTvQualityService(englishOnly: false);
    });

    test('backward compatibility: operates identically when M3U source is absent', () async {
      final jsonSource = _FakeDearbulutRemoteDataSource(
        channels: [
          const DearbulutChannelDto(
            id: 'ChannelsTV.ng',
            name: 'Channels Television',
            country: 'NG',
            categories: ['news'],
            languages: ['eng'],
            logo: 'https://logo/ctv.png',
            score: 95,
            online: true,
            streams: [
              DearbulutStreamDto(
                url: 'https://stream.channelstv.com/live.m3u8',
                health: DearbulutHealthDto(status: 'online', score: 99),
              ),
            ],
          ),
        ],
      );

      final builder = FreeTvCatalogBuilder(
        remoteDataSource: jsonSource,
        m3uRemoteDataSource: null,
        mapper: mapper,
        quality: qualityService,
      );

      final result = await builder.build();

      expect(result.allValid.length, 1);
      expect(result.allValid.first.id, 'ChannelsTV.ng');
      expect(result.diagnostics.sources.length, 1);
      expect(result.diagnostics.sources.first.sourceName, 'dearbulut/channels.online');
      expect(result.diagnostics.rawRecords, 1);
      expect(result.diagnostics.duplicatesRemoved, 0);
    });

    test('dual-source aggregation merges JSON channels and M3U channels into unified catalog', () async {
      final jsonSource = _FakeDearbulutRemoteDataSource(
        channels: [
          const DearbulutChannelDto(
            id: 'BBCNews.uk',
            name: 'BBC News',
            country: 'UK',
            categories: ['news'],
            languages: ['eng'],
            logo: 'https://logo/bbc.png',
            score: 98,
            online: true,
            streams: [
              DearbulutStreamDto(
                url: 'https://bbc.stream/live.m3u8',
                health: DearbulutHealthDto(status: 'online', score: 98),
              ),
            ],
          ),
        ],
      );

      final m3uChannel = const FreeTvChannel(
        id: 'CNN.us',
        name: 'CNN International',
        country: 'United States',
        countryCode: 'US',
        region: 'Americas',
        categories: ['News', 'General'],
        languages: ['English'],
        logo: 'https://logo/cnn.png',
        streamUrls: ['http://portal5458.com:8080/live/cnn.m3u8'],
        streams: [
          FreeTvStream(
            url: 'http://portal5458.com:8080/live/cnn.m3u8',
            isOnline: true,
            healthScore: 100.0,
          ),
        ],
        source: 'm3u',
      );

      final builder = FreeTvCatalogBuilder(
        remoteDataSource: jsonSource,
        mapper: mapper,
        quality: qualityService,
      );

      final result = await builder.build(m3uChannels: [m3uChannel]);

      expect(result.allValid.length, 2);
      final channelIds = result.allValid.map((c) => c.id).toSet();
      expect(channelIds, containsAll(['BBCNews.uk', 'CNN.us']));

      // Verify diagnostics capture both sources
      expect(result.diagnostics.sources.length, 2);
      expect(result.diagnostics.sources.any((s) => s.sourceName == 'm3u/provided'), isTrue);
      expect(result.diagnostics.rawRecords, 2);
      expect(result.diagnostics.uniqueChannels, 2);
    });

    test('deduplicates channel variants across JSON and M3U sources by stable channel ID', () async {
      final jsonSource = _FakeDearbulutRemoteDataSource(
        channels: [
          const DearbulutChannelDto(
            id: 'BBC.UK',
            name: 'BBC One',
            country: 'UK',
            categories: ['news'],
            languages: ['eng'],
            logo: 'https://logo/bbc.png',
            score: 90,
            online: true,
            streams: [
              DearbulutStreamDto(
                url: 'https://stream.json.bbc/hls.m3u8',
                health: DearbulutHealthDto(status: 'online', score: 90),
              ),
            ],
          ),
        ],
      );

      // M3U source contains same channel ID 'BBC.UK' with a different stream URL
      final m3uChannel = const FreeTvChannel(
        id: 'BBC.UK',
        name: 'BBC One HD',
        country: 'United Kingdom',
        countryCode: 'UK',
        region: 'Europe',
        categories: ['News', 'General'],
        languages: ['English'],
        logo: 'https://logo/bbc.png',
        streamUrls: ['http://portal5458.com:8080/live/bbc.m3u8'],
        streams: [
          FreeTvStream(
            url: 'http://portal5458.com:8080/live/bbc.m3u8',
            isOnline: true,
            healthScore: 100.0,
          ),
        ],
        source: 'm3u',
      );

      final builder = FreeTvCatalogBuilder(
        remoteDataSource: jsonSource,
        mapper: mapper,
        quality: qualityService,
      );

      final result = await builder.build(m3uChannels: [m3uChannel]);

      // Deduplicated into a single channel with multiple streams
      expect(result.allValid.length, 1);
      final mergedChannel = result.allValid.first;
      expect(mergedChannel.id, 'BBC.UK');
      expect(mergedChannel.streamUrls.length, 2);
      expect(mergedChannel.streams.length, 2);
      expect(mergedChannel.streamUrls, contains('https://stream.json.bbc/hls.m3u8'));
      expect(mergedChannel.streamUrls, contains('http://portal5458.com:8080/live/bbc.m3u8'));
      expect(result.diagnostics.duplicatesRemoved, 1);
    });

    test('buildFromChannels directly processes pre-normalized channels with full quality scoring', () async {
      final channels = [
        const FreeTvChannel(
          id: 'ESPN.US',
          name: 'ESPN HD',
          country: 'United States',
          countryCode: 'US',
          region: 'Americas',
          categories: ['Sports'],
          languages: ['English'],
          streamUrls: ['http://portal5458.com:8080/live/espn.m3u8'],
          streams: [
            FreeTvStream(
              url: 'http://portal5458.com:8080/live/espn.m3u8',
              isOnline: true,
              healthScore: 100.0,
            ),
          ],
        ),
        const FreeTvChannel(
          id: 'Junk.US',
          name: 'Test Stream Demo Sample',
          country: 'United States',
          countryCode: 'US',
          languages: ['English'],
          streamUrls: ['http://portal5458.com:8080/live/junk.m3u8'],
        ),
      ];

      final builder = FreeTvCatalogBuilder(
        mapper: mapper,
        quality: const FreeTvQualityService(),
      );

      final result = await builder.buildFromChannels(channels);

      // ESPN passes; Junk is filtered out by FreeTvQualityService
      expect(result.allValid.length, 1);
      expect(result.allValid.first.id, 'ESPN.US');
      expect(result.allValid.first.qualityTier, FreeTvQualityTier.recommended);
      expect(result.diagnostics.invalidRecords, 1);
    });
  });
}
