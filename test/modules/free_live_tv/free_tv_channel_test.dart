import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';

void main() {
  group('FreeTvChannel Model Tests', () {
    test('parses from standard IPTV-org channel JSON correctly', () {
      final json = {
        'id': 'ChannelsTV.ng',
        'name': 'Channels Television',
        'native_name': 'Channels TV',
        'network': 'Channels Media Group',
        'country': 'NG',
        'subdivision': 'NG-LA',
        'city': 'Lagos',
        'broadcast_area': ['r/AFR', 'c/NG'],
        'languages': ['eng', 'yor'],
        'categories': ['news', 'general'],
        'is_nsfw': false,
        'website': 'https://www.channelstv.com',
        'logo': 'https://i.imgur.com/channels_logo.png',
      };

      final streamUrls = [
        'https://stream.channelstv.com/live/hls/live.m3u8',
        'https://backup.channelstv.com/live.m3u8',
      ];

      final channel = FreeTvChannel.fromJson(
        json,
        streamUrls: streamUrls,
        countryName: 'Nigeria',
      );

      expect(channel.id, 'ChannelsTV.ng');
      expect(channel.name, 'Channels Television');
      expect(channel.country, 'Nigeria');
      expect(channel.countryCode, 'NG');
      expect(channel.city, 'Lagos');
      expect(channel.languages, ['eng', 'yor']);
      expect(channel.categories, ['news', 'general']);
      expect(channel.isNsfw, isFalse);
      expect(channel.streamUrls.length, 2);
      expect(channel.primaryStreamUrl,
          'https://stream.channelstv.com/live/hls/live.m3u8');
      expect(channel.hasStream, isTrue);
    });

    test('safely handles missing or empty fields', () {
      final json = <String, dynamic>{
        'id': 'Minimal.us',
        'name': 'Minimal Channel',
      };

      final channel = FreeTvChannel.fromJson(json);

      expect(channel.id, 'Minimal.us');
      expect(channel.name, 'Minimal Channel');
      expect(channel.country, '');
      expect(channel.languages, isEmpty);
      expect(channel.categories, isEmpty);
      expect(channel.streamUrls, isEmpty);
      expect(channel.hasStream, isFalse);
      expect(channel.primaryStreamUrl, isNull);
      expect(channel.isFavorite, isFalse);
    });

    test('converts to canonical MediaItem properly for playback engine', () {
      const channel = FreeTvChannel(
        id: 'BBCNews.uk',
        name: 'BBC News',
        country: 'United Kingdom',
        countryCode: 'UK',
        network: 'BBC',
        languages: ['eng'],
        categories: ['news'],
        logo: 'https://logo.com/bbc.png',
        streamUrls: ['https://stream.bbc.com/hls.m3u8'],
        isFavorite: true,
      );

      final mediaItem = channel.toMediaItem();

      expect(mediaItem.id, 'free_tv_BBCNews.uk');
      expect(mediaItem.title, 'BBC News');
      expect(mediaItem.providerId, 'free_live_tv');
      expect(mediaItem.providerType, MediaSourceType.custom);
      expect(mediaItem.mediaType, MediaType.channel);
      expect(mediaItem.poster, 'https://logo.com/bbc.png');
      expect(mediaItem.country, 'United Kingdom');
      expect(mediaItem.favorite, isTrue);
      expect(mediaItem.metadata['streamUrl'],
          'https://stream.bbc.com/hls.m3u8');
      expect(mediaItem.metadata['isFreeTv'], isTrue);
      expect(mediaItem.metadata['channelId'], 'BBCNews.uk');
    });

    test('serializes to JSON and back faithfully', () {
      const original = FreeTvChannel(
        id: 'NTA.ng',
        name: 'NTA News 24',
        country: 'Nigeria',
        countryCode: 'NG',
        categories: ['news'],
        languages: ['eng'],
        streamUrls: ['https://nta.stream/live.m3u8'],
        isFavorite: true,
        isWorking: true,
      );

      final json = original.toJson();
      final reconstructed = FreeTvChannel.fromJson(json);

      expect(reconstructed.id, original.id);
      expect(reconstructed.name, original.name);
      expect(reconstructed.country, original.country);
      expect(reconstructed.countryCode, original.countryCode);
      expect(reconstructed.streamUrls, original.streamUrls);
      expect(reconstructed.isFavorite, isTrue);
      expect(reconstructed.isWorking, isTrue);
    });

    test('isWorking round-trips false and is null when absent', () {
      final falseJson = const FreeTvChannel(
        id: 'c', name: 'Chan', country: 'NG', countryCode: 'NG',
        streamUrls: ['https://a/live.m3u8'], isWorking: false,
      ).toJson();
      expect(FreeTvChannel.fromJson(falseJson).isWorking, isFalse);

      final absentJson = const FreeTvChannel(
        id: 'c', name: 'Chan', country: 'NG', countryCode: 'NG',
        streamUrls: ['https://a/live.m3u8'],
      ).toJson();
      expect(FreeTvChannel.fromJson(absentJson).isWorking, isNull);
    });
  });
}
