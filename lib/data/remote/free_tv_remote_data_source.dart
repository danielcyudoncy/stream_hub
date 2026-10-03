import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';
import 'package:stream_hub/data/models/dearbulut_dtos.dart';
import 'package:stream_hub/data/sources/free_tv_api_config.dart';

/// Abstract remote data source contract for Free Live TV catalogs.
///
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
    _logger.info('Fetching online channels (compressed)...', tag: 'DearbulutRemote');

    List<dynamic> jsonList;
    try {
      jsonList = await _fetchJsonList(
        FreeTvApiConfig.channelsOnlineGzUrl,
        effectiveTimeout,
      );
    } catch (e) {
      _logger.warning(
        'Failed to fetch compressed channels ($e), falling back to uncompressed: ${FreeTvApiConfig.channelsOnlineUrl}',
        tag: 'DearbulutRemote',
      );
      jsonList = await _fetchJsonList(
        FreeTvApiConfig.channelsOnlineUrl,
        effectiveTimeout,
      );
    }

    final channels = await Isolate.run(() {
      final List<DearbulutChannelDto> list = [];
      for (final item in jsonList) {
        if (item is Map) {
          list.add(DearbulutChannelDto.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      return list;
    });

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
    request.headers.set('Accept', 'application/json, application/gzip, */*');

    final response = await request.close().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'HTTP ${response.statusCode} while fetching $url',
        uri: uri,
      );
    }

    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    final rawBytes = builder.takeBytes();

    final isGz = url.endsWith('.gz') ||
        (rawBytes.length >= 2 && rawBytes[0] == 0x1f && rawBytes[1] == 0x8b);

    final decompressedBytes = isGz ? gzip.decode(rawBytes) : rawBytes;
    final decodedText = utf8.decode(decompressedBytes, allowMalformed: true);
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
