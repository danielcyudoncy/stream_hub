import 'dart:convert';
import 'dart:io';

import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';
import 'package:stream_hub/data/models/dearbulut_dtos.dart';
import 'package:stream_hub/data/sources/free_tv_api_config.dart';

/// Abstract remote data source contract for Free Live TV catalogs.
///
/// Designed to be multi-source extensible (e.g. Dearbulut, OfficialBroadcasters, etc.).
abstract class FreeTvRemoteDataSource {
  Future<List<DearbulutChannelDto>> fetchOnlineChannels({Duration? timeout});
  Future<List<DearbulutCountryDto>> fetchCountries({Duration? timeout});
  Future<List<DearbulutCategoryDto>> fetchCategories({Duration? timeout});
  Future<List<DearbulutChannelDto>> fetchChannelsByCountry(String countryCode, {Duration? timeout});
  Future<List<DearbulutChannelDto>> fetchChannelsByCategory(String categoryId, {Duration? timeout});
}

/// Primary remote data source implementation using the dearbulut/iptv (IPTV Nexus) JSON API.
class DearbulutFreeTvRemoteDataSource implements FreeTvRemoteDataSource {
  final HttpClient _httpClient;
  final LoggingService _logger;

  DearbulutFreeTvRemoteDataSource({
    HttpClient? httpClient,
    LoggingService? logger,
  })  : _httpClient = httpClient ?? createDohAwareHttpClient(),
        _logger = logger ?? LoggingService();

  @override
  Future<List<DearbulutChannelDto>> fetchOnlineChannels({Duration? timeout}) async {
    final effectiveTimeout = timeout ?? FreeTvApiConfig.defaultTimeout;
    _logger.info('Fetching online channels from ${FreeTvApiConfig.channelsOnlineUrl}...',
        tag: 'DearbulutRemote');

    final jsonList = await _fetchJsonList(FreeTvApiConfig.channelsOnlineUrl, effectiveTimeout);
    final List<DearbulutChannelDto> channels = [];
    for (final item in jsonList) {
      if (item is Map) {
        channels.add(DearbulutChannelDto.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    _logger.info('Fetched ${channels.length} online channels from dearbulut API.',
        tag: 'DearbulutRemote');
    return channels;
  }

  @override
  Future<List<DearbulutCountryDto>> fetchCountries({Duration? timeout}) async {
    final effectiveTimeout = timeout ?? FreeTvApiConfig.defaultTimeout;
    final jsonList = await _fetchJsonList(FreeTvApiConfig.countriesUrl, effectiveTimeout);
    final List<DearbulutCountryDto> countries = [];
    for (final item in jsonList) {
      if (item is Map) {
        countries.add(DearbulutCountryDto.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return countries;
  }

  @override
  Future<List<DearbulutCategoryDto>> fetchCategories({Duration? timeout}) async {
    final effectiveTimeout = timeout ?? FreeTvApiConfig.defaultTimeout;
    final jsonList = await _fetchJsonList(FreeTvApiConfig.categoriesUrl, effectiveTimeout);
    final List<DearbulutCategoryDto> categories = [];
    for (final item in jsonList) {
      if (item is Map) {
        categories.add(DearbulutCategoryDto.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return categories;
  }

  @override
  Future<List<DearbulutChannelDto>> fetchChannelsByCountry(
    String countryCode, {
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? FreeTvApiConfig.defaultTimeout;
    final url = FreeTvApiConfig.byCountryUrl(countryCode);
    final jsonList = await _fetchJsonList(url, effectiveTimeout);
    final List<DearbulutChannelDto> channels = [];
    for (final item in jsonList) {
      if (item is Map) {
        channels.add(DearbulutChannelDto.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return channels;
  }

  @override
  Future<List<DearbulutChannelDto>> fetchChannelsByCategory(
    String categoryId, {
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? FreeTvApiConfig.defaultTimeout;
    final url = FreeTvApiConfig.byCategoryUrl(categoryId);
    final jsonList = await _fetchJsonList(url, effectiveTimeout);
    final List<DearbulutChannelDto> channels = [];
    for (final item in jsonList) {
      if (item is Map) {
        channels.add(DearbulutChannelDto.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return channels;
  }

  Future<List<dynamic>> _fetchJsonList(String url, Duration timeout) async {
    final uri = Uri.parse(url);
    final request = await _httpClient.getUrl(uri).timeout(timeout);
    request.headers.set('User-Agent', 'StreamHubPro/1.0 (FreeLiveTV)');
    request.headers.set('Accept', 'application/json, */*');
    request.headers.set('Accept-Encoding', 'gzip, deflate');

    final response = await request.close().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'HTTP ${response.statusCode} while fetching $url',
        uri: uri,
      );
    }

    final isGzip = response.headers.value(HttpHeaders.contentEncodingHeader)?.contains('gzip') ?? false;
    Stream<List<int>> stream = response;
    if (isGzip) {
      stream = response.transform(gzip.decoder);
    }

    final bytes = await stream.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
    final decodedText = utf8.decode(bytes, allowMalformed: true);
    final dynamic parsed = jsonDecode(decodedText);
    if (parsed is List) {
      return parsed;
    }
    if (parsed is Map && parsed['channels'] is List) {
      return parsed['channels'] as List;
    }
    return const [];
  }
}
