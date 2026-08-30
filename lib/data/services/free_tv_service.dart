import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';

/// Service responsible for fetching and aggregating the public IPTV-org catalog.
class FreeTvService {
  static const String kChannelsUrl =
      'https://iptv-org.github.io/api/channels.json';
  static const String kStreamsUrl =
      'https://iptv-org.github.io/api/streams.json';
  static const String kCountriesUrl =
      'https://iptv-org.github.io/api/countries.json';
  static const String kCategoriesUrl =
      'https://iptv-org.github.io/api/categories.json';

  final HttpClient _httpClient;
  final LoggingService _logger;

  FreeTvService({
    HttpClient? httpClient,
    LoggingService? logger,
  })  : _httpClient = httpClient ?? createDohAwareHttpClient(),
        _logger = logger ?? LoggingService();

  /// Fetches, matches, and normalizes the full Free Live TV catalog from IPTV-org.
  Future<List<FreeTvChannel>> fetchCatalog({
    Duration timeout = const Duration(seconds: 25),
  }) async {
    _logger.info('Starting Free Live TV catalog fetch from IPTV-org...',
        tag: 'FreeTvService');

    try {
      // 1. Fetch streams, countries, and channels concurrently
      final streamsFuture = _fetchJsonList(kStreamsUrl, timeout);
      final countriesFuture = _fetchJsonList(kCountriesUrl, timeout);
      final channelsFuture = _fetchJsonList(kChannelsUrl, timeout);

      final results = await Future.wait([
        streamsFuture,
        countriesFuture,
        channelsFuture,
      ]);

      final rawStreams = results[0];
      final rawCountries = results[1];
      final rawChannels = results[2];

      _logger.info(
        'Fetched raw IPTV-org data: ${rawChannels.length} channels, ${rawStreams.length} streams, ${rawCountries.length} countries.',
        tag: 'FreeTvService',
      );

      // 2. Map stream URLs by channel ID (deduplicating and grouping multiple streams)
      final Map<String, List<String>> streamsByChannel = {};
      for (final s in rawStreams) {
        if (s is! Map<String, dynamic>) continue;
        final channelId = (s['channel'] ?? '').toString().trim();
        final url = (s['url'] ?? '').toString().trim();

        if (channelId.isEmpty || url.isEmpty || !url.startsWith('http')) {
          continue;
        }

        final list = streamsByChannel.putIfAbsent(channelId, () => []);
        if (!list.contains(url)) {
          list.add(url);
        }
      }

      // 3. Map country code to Country name
      final Map<String, String> countryNameByCode = {};
      for (final c in rawCountries) {
        if (c is! Map<String, dynamic>) continue;
        final code = (c['code'] ?? '').toString().trim().toUpperCase();
        final name = (c['name'] ?? '').toString().trim();
        if (code.isNotEmpty && name.isNotEmpty) {
          countryNameByCode[code] = name;
        }
      }

      // 4. Build channels list with filtering pipeline
      int nsfwCount = 0;
      int noStreamCount = 0;
      int malformedCount = 0;
      final List<FreeTvChannel> validChannels = [];

      for (final ch in rawChannels) {
        if (ch is! Map<String, dynamic>) {
          malformedCount++;
          continue;
        }

        final id = (ch['id'] ?? '').toString().trim();
        final name = (ch['name'] ?? '').toString().trim();

        if (id.isEmpty || name.isEmpty) {
          malformedCount++;
          continue;
        }

        final isNsfw = ch['is_nsfw'] == true || ch['is_nsfw'] == 1;
        if (isNsfw) {
          nsfwCount++;
          continue;
        }

        final channelStreams = streamsByChannel[id];
        if (channelStreams == null || channelStreams.isEmpty) {
          noStreamCount++;
          continue;
        }

        final countryCode =
            (ch['country'] ?? '').toString().trim().toUpperCase();
        final countryName =
            countryNameByCode[countryCode] ?? (countryCode.isNotEmpty ? countryCode : 'Global');

        final channel = FreeTvChannel.fromJson(
          ch,
          streamUrls: channelStreams,
          countryName: countryName,
        );

        validChannels.add(channel);
      }

      _logger.info(
        'Free TV Catalog Summary: '
        'Channels fetched: ${rawChannels.length}, '
        'Streams fetched: ${rawStreams.length}, '
        'Channels with streams: ${validChannels.length}, '
        'NSFW excluded: $nsfwCount, '
        'No stream excluded: $noStreamCount, '
        'Malformed excluded: $malformedCount.',
        tag: 'FreeTvService',
      );

      return validChannels;
    } catch (e, stack) {
      _logger.error(
        'Failed to fetch and process IPTV-org catalog.',
        tag: 'FreeTvService',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<List<dynamic>> _fetchJsonList(String url, Duration timeout) async {
    try {
      final uri = Uri.parse(url);
      final request = await _httpClient.getUrl(uri).timeout(timeout);
      request.headers.set('User-Agent', 'StreamHubPro/1.0 (FreeLiveTV)');
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'HTTP ${response.statusCode} while fetching $url',
          uri: uri,
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final decoded = json.decode(body);
      if (decoded is List) {
        return decoded;
      }
      return const [];
    } catch (e) {
      _logger.warning('Failed to fetch endpoint: $url. Error: $e',
          tag: 'FreeTvService');
      return const [];
    }
  }
}
