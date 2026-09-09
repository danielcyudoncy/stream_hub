import 'dart:convert';
import 'dart:io';

import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';
import 'package:stream_hub/data/models/dearbulut_dtos.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/models/free_tv_stream.dart';
import 'package:stream_hub/data/parsers/m3u_parser.dart';
import 'package:stream_hub/data/services/free_tv_m3u_normalizer.dart';
import 'package:stream_hub/data/sources/free_tv_api_config.dart';
import 'package:stream_hub/data/sources/free_tv_sources.dart';

/// Remote data source implementation that fetches an M3U playlist from a remote URL,
/// Remote data source contract for M3U playlists in Free Live TV.
abstract class FreeTvM3uRemoteDataSource {
  Future<List<FreeTvChannel>> fetchOnlineChannels({Duration? timeout});
  Future<List<DearbulutCountryDto>> fetchCountries({Duration? timeout});
  Future<List<DearbulutCategoryDto>> fetchCategories({Duration? timeout});
  Future<List<FreeTvChannel>> fetchChannelsByCountry(String countryCode, {Duration? timeout});
  Future<List<FreeTvChannel>> fetchChannelsByCategory(String categoryId, {Duration? timeout});
}

/// Remote data source implementation that fetches an M3U playlist from a remote URL,
/// parses its content, and normalizes entries directly into canonical [FreeTvChannel] instances.
///
/// Credential handling: Provider URLs that contain embedded credentials (username/password query params)
/// are treated as user-supplied provider credentials, not application secrets. Full URLs are never logged;
/// only sanitized source IDs or hostnames are written to logs.
class CustomM3uFreeTvRemoteDataSource implements FreeTvM3uRemoteDataSource {
  final HttpClient _httpClient;
  final LoggingService _logger;
  final FreeTvSource source;
  final M3UParser _parser;
  final FreeTvM3uNormalizer _normalizer;

  CustomM3uFreeTvRemoteDataSource({
    HttpClient? httpClient,
    LoggingService? logger,
    M3UParser? parser,
    FreeTvM3uNormalizer? normalizer,
    required this.source,
  })  : _httpClient = httpClient ?? createDohAwareHttpClient(),
        _logger = logger ?? LoggingService(),
        _parser = parser ?? M3UParser(),
        _normalizer = normalizer ?? FreeTvM3uNormalizer();

  @override
  Future<List<FreeTvChannel>> fetchOnlineChannels({Duration? timeout}) async {
    final effectiveTimeout = timeout ?? FreeTvApiConfig.defaultTimeout;
    final sanitizedHost = _sanitizedHost(source.url);
    _logger.info(
      'Fetching M3U channels from source ${source.id} ($sanitizedHost)...',
      tag: 'CustomM3uRemote',
    );

    try {
      final uri = Uri.parse(source.url);
      final request = await _httpClient.getUrl(uri).timeout(effectiveTimeout);
      request.headers.set('User-Agent', 'StreamHubPro/1.0 (FreeLiveTV)');
      request.headers.set('Accept', 'text/plain, */*');

      final response = await request.close().timeout(effectiveTimeout);
      if (response.statusCode == HttpStatus.ok) {
        final bytes = await response.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
        final content = utf8.decode(bytes, allowMalformed: true);

        if (content.contains('#EXTM3U')) {
          final parseResult = _parser.parse(content);
          final channels = <FreeTvChannel>[];

          for (final m3uChannel in parseResult.channels) {
            final channel = _normalizer.toChannel(
              m3uChannel,
              sourceCountryCode: source.kind == FreeTvSourceKind.country ? source.countryCode : null,
              sourceCategory: source.kind == FreeTvSourceKind.category ? source.categoryName : null,
            );
            if (channel != null) {
              final enrichedCategories = <String>{...channel.categories};
              for (final cat in channel.categories) {
                enrichedCategories.addAll(_normalizeCategories(cat));
              }
              channels.add(channel.copyWith(
                categories: enrichedCategories.toList(),
                qualityScore: 100,
                qualityTier: FreeTvQualityTier.recommended,
              ));
            }
          }

          if (channels.isNotEmpty) {
            _logger.info(
              'Fetched and normalized ${channels.length} channels from source ${source.id} ($sanitizedHost).',
              tag: 'CustomM3uRemote',
            );
            return channels;
          }
        }
      }

      // Check for Xtream fallback if M3U endpoint returns non-OK or non-M3U content
      final username = uri.queryParameters['username'];
      final password = uri.queryParameters['password'];
      if (username != null && username.isNotEmpty && password != null && password.isNotEmpty) {
        _logger.info(
          'Attempting Xtream Codes API fallback for source ${source.id} ($sanitizedHost)...',
          tag: 'CustomM3uRemote',
        );
        final fallbackChannels = await _fetchFromXtreamApi(uri, username, password, effectiveTimeout);
        if (fallbackChannels.isNotEmpty) {
          _logger.info(
            'Fetched ${fallbackChannels.length} channels via Xtream API fallback for source ${source.id} ($sanitizedHost).',
            tag: 'CustomM3uRemote',
          );
          return fallbackChannels;
        }
      }

      _logger.warning(
        'HTTP ${response.statusCode} while fetching M3U playlist from source ${source.id} ($sanitizedHost)',
        tag: 'CustomM3uRemote',
      );
      return const [];
    } catch (e) {
      final uri = Uri.tryParse(source.url);
      final username = uri?.queryParameters['username'];
      final password = uri?.queryParameters['password'];
      if (uri != null && username != null && password != null) {
        try {
          final fallbackChannels = await _fetchFromXtreamApi(uri, username, password, effectiveTimeout);
          if (fallbackChannels.isNotEmpty) return fallbackChannels;
        } catch (_) {}
      }

      _logger.error(
        'Failed to fetch or parse M3U from source ${source.id} ($sanitizedHost): $e',
        tag: 'CustomM3uRemote',
      );
      return const [];
    }
  }

  Future<List<FreeTvChannel>> _fetchFromXtreamApi(
    Uri baseUri,
    String username,
    String password,
    Duration timeout,
  ) async {
    final catMap = <String, String>{};
    try {
      final catUri = baseUri.replace(
        path: '/player_api.php',
        queryParameters: {
          'username': username,
          'password': password,
          'action': 'get_live_categories',
        },
      );
      final catReq = await _httpClient.getUrl(catUri).timeout(timeout);
      catReq.headers.set('User-Agent', 'IPTVSmartersPro/1.0');
      final catRes = await catReq.close().timeout(timeout);
      if (catRes.statusCode == HttpStatus.ok) {
        final catBytes = await catRes.fold<List<int>>([], (p, c) => p..addAll(c));
        final catJson = jsonDecode(utf8.decode(catBytes, allowMalformed: true));
        if (catJson is List) {
          for (final item in catJson) {
            if (item is Map) {
              final id = item['category_id']?.toString();
              final name = item['category_name']?.toString();
              if (id != null && name != null) {
                catMap[id] = name;
              }
            }
          }
        }
      }
    } catch (e) {
      _logger.warning('Failed to fetch Xtream categories: $e', tag: 'CustomM3uRemote');
    }

    final streamsUri = baseUri.replace(
      path: '/player_api.php',
      queryParameters: {
        'username': username,
        'password': password,
        'action': 'get_live_streams',
      },
    );
    final streamReq = await _httpClient.getUrl(streamsUri).timeout(timeout);
    streamReq.headers.set('User-Agent', 'IPTVSmartersPro/1.0');
    final streamRes = await streamReq.close().timeout(timeout);
    if (streamRes.statusCode != HttpStatus.ok) {
      return const [];
    }

    final streamBytes = await streamRes.fold<List<int>>([], (p, c) => p..addAll(c));
    final streamJson = jsonDecode(utf8.decode(streamBytes, allowMalformed: true));
    if (streamJson is! List) return const [];

    final result = <FreeTvChannel>[];
    for (final item in streamJson) {
      if (item is! Map) continue;
      final streamId = item['stream_id']?.toString() ?? '';
      final rawName = (item['name']?.toString() ?? '').trim();
      if (streamId.isEmpty || rawName.isEmpty) continue;

      final catId = item['category_id']?.toString() ?? '';
      final rawCategory = catMap[catId] ?? source.categoryName ?? 'General';
      final logo = item['stream_icon']?.toString().trim();

      String country = 'United States';
      String countryCode = 'US';
      String region = 'North America';
      String lang = 'English';

      final catUpper = rawCategory.toUpperCase();
      if (catUpper.startsWith('UK - ') || catUpper.contains('UNITED KINGDOM')) {
        country = 'United Kingdom';
        countryCode = 'GB';
        region = 'Europe';
      } else if (catUpper.startsWith('CANADA') || catUpper.contains('CANADA')) {
        country = 'Canada';
        countryCode = 'CA';
        region = 'North America';
      } else if (catUpper.startsWith('LATINO') || catUpper.contains('DEPORTES')) {
        country = 'Latin America';
        countryCode = 'MX';
        region = 'Americas';
        lang = 'Spanish';
      } else if (catUpper.contains('BRAZIL')) {
        country = 'Brazil';
        countryCode = 'BR';
        region = 'South America';
        lang = 'Portuguese';
      } else if (catUpper.contains('PORTUGAL')) {
        country = 'Portugal';
        countryCode = 'PT';
        region = 'Europe';
        lang = 'Portuguese';
      }

      final streamUrl = '${baseUri.scheme}://${baseUri.host}:${baseUri.port}/live/$username/$password/$streamId.ts';

      final normalizedCategories = _normalizeCategories(rawCategory);

      result.add(FreeTvChannel(
        id: 'custom_portal5458_$streamId',
        name: rawName,
        logo: (logo != null && logo.isNotEmpty) ? logo : null,
        country: country,
        countryCode: countryCode,
        region: region,
        categories: normalizedCategories,
        languages: [lang, 'English'],
        qualityScore: 100,
        qualityTier: FreeTvQualityTier.recommended,
        streams: [
          FreeTvStream(
            url: streamUrl,
            isOnline: true,
            healthScore: 100.0,
            label: 'MPEG-TS',
          ),
        ],
      ));
    }

    return result;
  }

  /// Normalizes raw provider category strings (e.g. 'US - News', 'UK - Documentaries',
  /// 'Bein Sports', 'MLB.1') into standard canonical category tags.
  static List<String> _normalizeCategories(String rawCategory) {
    final result = <String>{rawCategory};
    final catLower = rawCategory.toLowerCase();

    // Sports
    if (catLower.contains('sport') ||
        catLower.contains('deporte') ||
        catLower.contains('mlb') ||
        catLower.contains('nba') ||
        catLower.contains('wnba') ||
        catLower.contains('nfl') ||
        catLower.contains('nhl') ||
        catLower.contains('ncaa') ||
        catLower.contains('bein') ||
        catLower.contains('espn') ||
        catLower.contains('fight') ||
        catLower.contains('ppv')) {
      result.add('Sports');
    }

    // News
    if (catLower.contains('news') ||
        catLower.contains('noticia') ||
        catLower.contains('locals') ||
        catLower.contains('local')) {
      result.add('News');
    }

    // Documentaries
    if (catLower.contains('doc') || catLower.contains('documentar')) {
      result.add('Documentaries');
      result.add('Documentary');
    }

    // Entertainment
    if (catLower.contains('entertainment') ||
        catLower.contains('local') ||
        catLower.contains('latino') ||
        catLower.contains('movie') ||
        catLower.contains('cinema') ||
        catLower.contains('film')) {
      result.add('Entertainment');
    }

    // Movies
    if (catLower.contains('movie') ||
        catLower.contains('cinema') ||
        catLower.contains('film')) {
      result.add('Movies');
    }

    // Kids
    if (catLower.contains('kid') ||
        catLower.contains('child') ||
        catLower.contains('animat') ||
        catLower.contains('cartoon') ||
        catLower.contains('toon')) {
      result.add('Kids');
      result.add('Animation');
    }

    // Music
    if (catLower.contains('music') || catLower.contains('musica')) {
      result.add('Music');
    }

    return result.toList();
  }

  @override
  Future<List<DearbulutCountryDto>> fetchCountries({Duration? timeout}) async {
    return const [];
  }

  @override
  Future<List<DearbulutCategoryDto>> fetchCategories({Duration? timeout}) async {
    return const [];
  }

  @override
  Future<List<FreeTvChannel>> fetchChannelsByCountry(
    String countryCode, {
    Duration? timeout,
  }) async {
    return const [];
  }

  @override
  Future<List<FreeTvChannel>> fetchChannelsByCategory(
    String categoryId, {
    Duration? timeout,
  }) async {
    return const [];
  }

  String _sanitizedHost(String url) {
    try {
      final uri = Uri.parse(url);
      final portPart = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.host}$portPart';
    } catch (_) {
      return 'unknown_host';
    }
  }
}
