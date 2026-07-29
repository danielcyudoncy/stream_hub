import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/data/matchers/channel_matcher.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';

void main() {
  group('ChannelMatcher', () {
    late ChannelMatcher matcher;

    setUp(() {
      matcher = ChannelMatcher();
    });

    test('matches channel by tvg-id', () {
      final xmltvChannel = XMLTVChannel(
        id: 'tvg-123',
        displayName: 'News Channel',
      );
      final existingChannel = MediaItem(
        id: 'existing-1',
        providerId: 'provider-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News Channel',
        metadata: {'tvgId': 'tvg-123'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = matcher.matchChannelsToExisting(
        [xmltvChannel],
        [existingChannel],
      );

      expect(result.containsKey('tvg-123'), isTrue);
    });

    test('matches channel by display-name', () {
      final xmltvChannel = XMLTVChannel(
        id: 'ch1',
        displayName: 'Sports HD',
      );
      final existingChannel = MediaItem(
        id: 'existing-1',
        providerId: 'provider-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'Sports HD',
        metadata: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = matcher.matchChannelsToExisting(
        [xmltvChannel],
        [existingChannel],
      );

      expect(result.containsKey('ch1'), isTrue);
    });

    test('matches channel by alias', () {
      final xmltvChannel = XMLTVChannel(
        id: 'ch1',
        displayName: 'Main Name',
        aliases: ['Alias One', 'Alias Two'],
      );
      final existingChannel = MediaItem(
        id: 'existing-1',
        providerId: 'provider-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'Alias One',
        metadata: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = matcher.matchChannelsToExisting(
        [xmltvChannel],
        [existingChannel],
      );

      expect(result.containsKey('ch1'), isTrue);
    });

    test('matches channel by fuzzy name', () {
      final xmltvChannel = XMLTVChannel(
        id: 'ch1',
        displayName: 'News Channel',
      );
      final existingChannel = MediaItem(
        id: 'existing-1',
        providerId: 'provider-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'News',
        metadata: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = matcher.matchChannelsToExisting(
        [xmltvChannel],
        [existingChannel],
      );

      expect(result.containsKey('ch1'), isTrue);
    });

    test('returns empty map when no matches', () {
      final xmltvChannel = XMLTVChannel(
        id: 'ch1',
        displayName: 'Unknown Channel',
      );
      final existingChannel = MediaItem(
        id: 'existing-1',
        providerId: 'provider-1',
        providerType: MediaSourceType.m3u,
        mediaType: MediaType.channel,
        title: 'Completely Different',
        metadata: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = matcher.matchChannelsToExisting(
        [xmltvChannel],
        [existingChannel],
      );

      expect(result.isEmpty, isTrue);
    });

    test('matches multiple channels', () {
      final xmltvChannels = [
        XMLTVChannel(id: 'ch1', displayName: 'Channel One'),
        XMLTVChannel(id: 'ch2', displayName: 'Channel Two'),
        XMLTVChannel(id: 'ch3', displayName: 'Channel Three'),
      ];
      final existingChannels = [
        MediaItem(
          id: 'e1',
          providerId: 'p1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.channel,
          title: 'Channel One',
          metadata: {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        MediaItem(
          id: 'e2',
          providerId: 'p1',
          providerType: MediaSourceType.m3u,
          mediaType: MediaType.channel,
          title: 'Channel Two',
          metadata: {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = matcher.matchChannelsToExisting(
        xmltvChannels,
        existingChannels,
      );

      expect(result.length, 2);
      expect(result.containsKey('ch1'), isTrue);
      expect(result.containsKey('ch2'), isTrue);
      expect(result.containsKey('ch3'), isFalse);
    });

    test('adds and removes aliases', () {
      final mutableMatcher = ChannelMatcher(aliases: <String, String>{});
      mutableMatcher.addAlias('xmltv-ch1', 'existing-ch1');
      expect(mutableMatcher.aliases.containsKey('xmltv-ch1'), isTrue);

      mutableMatcher.removeAlias('xmltv-ch1');
      expect(mutableMatcher.aliases.containsKey('xmltv-ch1'), isFalse);
    });
  });
}