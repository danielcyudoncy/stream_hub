/// Centralized API configuration and endpoints for Free Live TV datasets.
abstract final class FreeTvApiConfig {
  static const String baseUrl = 'https://dearbulut.github.io/iptv';

  // --- API v1 Static Endpoints ---
  static const String manifestUrl = '$baseUrl/api/v1/index.json';
  static const String channelsOnlineUrl = '$baseUrl/api/v1/channels.online.json';
  static const String channelsOnlineGzUrl = '$baseUrl/api/v1/channels.online.json.gz';
  static const String channelsAllUrl = '$baseUrl/api/v1/channels.json';
  static const String countriesUrl = '$baseUrl/api/v1/countries.json';
  static const String categoriesUrl = '$baseUrl/api/v1/categories.json';
  static const String languagesUrl = '$baseUrl/api/v1/languages.json';
  static const String healthUrl = '$baseUrl/api/v1/health.json';
  static const String searchUrl = '$baseUrl/api/v1/search.json';

  // --- Parameterized Endpoints ---
  static String channelDetailUrl(String channelId) =>
      '$baseUrl/api/v1/channels/$channelId.json';

  static String byCountryUrl(String countryCode) =>
      '$baseUrl/api/v1/by-country/${countryCode.toLowerCase()}.json';

  static String byCategoryUrl(String categoryId) =>
      '$baseUrl/api/v1/by-category/${categoryId.toLowerCase()}.json';

  static String byLanguageUrl(String languageCode) =>
      '$baseUrl/api/v1/by-language/${languageCode.toLowerCase()}.json';

  // --- Timeouts & TTL ---
  static const Duration defaultTimeout = Duration(seconds: 25);
  static const Duration cacheTtl = Duration(hours: 12);
  static const Duration reachabilityTtl = Duration(hours: 24);
}
