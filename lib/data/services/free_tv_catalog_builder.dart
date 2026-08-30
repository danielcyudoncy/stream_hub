import 'dart:convert';
import 'dart:io';

import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/models/m3u_models.dart';
import 'package:stream_hub/data/parsers/m3u_parser.dart';
import 'package:stream_hub/data/services/free_tv_m3u_normalizer.dart';
import 'package:stream_hub/data/services/free_tv_quality_service.dart';
import 'package:stream_hub/data/sources/free_tv_sources.dart';

/// Per-source fetch/diagnostics.
class FreeTvSourceFetchResult {
  final FreeTvSource source;
  final bool succeeded;
  final int rawRecords;
  final String? error;

  const FreeTvSourceFetchResult({
    required this.source,
    required this.succeeded,
    required this.rawRecords,
    this.error,
  });
}

/// Aggregate pipeline diagnostics (used during development / admin review).
class FreeTvCatalogDiagnostics {
  final List<FreeTvSourceFetchResult> sources;
  final int rawRecords;
  final int uniqueChannels;
  final int invalidRecords;
  final int junkRecords;
  final int noStreamRecords;
  final int nsfwRecords;
  final int duplicatesRemoved;
  final int recommendedCount;
  final int allValidCount;

  const FreeTvCatalogDiagnostics({
    this.sources = const [],
    this.rawRecords = 0,
    this.uniqueChannels = 0,
    this.invalidRecords = 0,
    this.junkRecords = 0,
    this.noStreamRecords = 0,
    this.nsfwRecords = 0,
    this.duplicatesRemoved = 0,
    this.recommendedCount = 0,
    this.allValidCount = 0,
  });
}

/// Result of building the unified Free TV catalog.
class FreeTvCatalogResult {
  /// Channels that passed hard eligibility, deduplicated across all sources.
  final List<FreeTvChannel> allValid;

  /// Subset of [allValid] that meets the curation quality bar.
  final List<FreeTvChannel> recommended;

  final FreeTvCatalogDiagnostics diagnostics;

  const FreeTvCatalogResult({
    required this.allValid,
    required this.recommended,
    required this.diagnostics,
  });
}

/// Orchestrates the Free Live TV ingestion pipeline:
///
/// ```text
/// IPTV-org sources (global, countries, regions, categories)
///   → parallel fetch
///   → M3U parse
///   → normalize
///   → aggregate (merge same channel across sources)
///   → dedupe streams
///   → hard eligibility filtering
///   → quality scoring + tier assignment
///   → unified catalog
/// ```
class FreeTvCatalogBuilder {
  final HttpClient _httpClient;
  final LoggingService _logger;
  final M3UParser _m3uParser;
  final FreeTvM3uNormalizer _normalizer;
  final FreeTvQualityService _quality;

  FreeTvCatalogBuilder({
    HttpClient? httpClient,
    LoggingService? logger,
    M3UParser? parser,
    FreeTvM3uNormalizer? normalizer,
    FreeTvQualityService? quality,
  })  : _httpClient = httpClient ?? createDohAwareHttpClient(),
        _logger = logger ?? LoggingService(),
        _m3uParser = parser ?? M3UParser(),
        _normalizer = normalizer ?? FreeTvM3uNormalizer(),
        _quality = quality ?? FreeTvQualityService();

  /// Fetches and processes every configured source. A single source failure is
  /// isolated so the rest of the catalog still builds.
  Future<FreeTvCatalogResult> build({
    List<FreeTvSource> sources = FreeTvSources.all,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final sourceResults = await Future.wait(
      sources.map(
        (s) => _fetchAndParseSource(s, timeout).then<_FreeSourceResult>(
          (r) => r,
          onError: (Object e) => _FreeSourceResult(error: '$e'),
        ),
      ),
    );

    final fetchResults = <FreeTvSourceFetchResult>[];
    final aggregated = <String, FreeTvChannel>{};

    var rawTotal = 0;
    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      final raw = sourceResults[i];
      fetchResults.add(FreeTvSourceFetchResult(
        source: source,
        succeeded: raw.channels != null && raw.error == null,
        rawRecords: raw.channels?.length ?? 0,
        error: raw.error,
      ));
      rawTotal += raw.channels?.length ?? 0;
      if (raw.channels == null) continue;
      for (final m3u in raw.channels!) {
        final normalized = _normalizer.toChannel(
          m3u,
          sourceCountryCode: source.countryCode,
          sourceCategory: source.kind == FreeTvSourceKind.category
              ? source.categoryName
              : null,
        );
        if (normalized == null) continue;
        _mergeInto(aggregated, normalized);
      }
    }

    // Apply eligibility + scoring + tiering.
    final eligible = <FreeTvChannel>[];
    final invalid = <FreeTvChannel>[];
    for (final ch in aggregated.values) {
      if (_quality.isEligible(ch)) {
        eligible.add(_quality.assignTier(ch));
      } else {
        invalid.add(ch);
      }
    }

    final recommended = eligible
        .where((c) => c.qualityTier == FreeTvQualityTier.recommended)
        .toList()
      ..sort(_compareByQualityThenName);
    final allValid = eligible.toList()..sort(_compareByQualityThenName);

    final diagnostics = FreeTvCatalogDiagnostics(
      sources: fetchResults,
      rawRecords: rawTotal,
      uniqueChannels: aggregated.length,
      duplicatesRemoved:
          rawTotal - aggregated.length - invalid.length,
      invalidRecords: invalid.length,
      recommendedCount: recommended.length,
      allValidCount: allValid.length,
    );

    _logDiagnostics(diagnostics);
    return FreeTvCatalogResult(
      allValid: allValid,
      recommended: recommended,
      diagnostics: diagnostics,
    );
  }

  Future<_FreeSourceResult> _fetchAndParseSource(
    FreeTvSource source,
    Duration timeout,
  ) async {
    try {
      final text = await _downloadText(source.url, timeout);
      final parsed = _m3uParser.parse(text);
      _logger.info(
        'Free TV source "${source.name}": ${parsed.channels.length} records '
        '(${parsed.invalidEntries} invalid).',
        tag: 'FreeTvCatalogBuilder',
      );
      return _FreeSourceResult(channels: parsed.channels);
    } catch (e) {
      _logger.warning(
        'Free TV source "${source.name}" failed: $e',
        tag: 'FreeTvCatalogBuilder',
      );
      return _FreeSourceResult(error: '$e');
    }
  }

  Future<String> _downloadText(String url, Duration timeout) async {
    final uri = Uri.parse(url);
    final request = await _httpClient.getUrl(uri).timeout(timeout);
    request.headers.set('User-Agent', 'StreamHubPro/1.0 (FreeLiveTV)');
    request.headers.set('Accept', '*/*');
    final response = await request.close().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'HTTP ${response.statusCode} while fetching $url',
        uri: uri,
      );
    }
    final bytes = await response
        .fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Merges [incoming] into [map] under its stable channel ID, unioning
  /// metadata and deduplicating stream URLs.
  void _mergeInto(Map<String, FreeTvChannel> map, FreeTvChannel incoming) {
    final existing = map[incoming.id];
    if (existing == null) {
      map[incoming.id] = incoming;
      return;
    }

    final merged = _mergeChannels(existing, incoming);
    map[incoming.id] = merged;
  }

  FreeTvChannel _mergeChannels(FreeTvChannel a, FreeTvChannel b) {
    final streamUrls = <String>[
      ...a.streamUrls,
      ...b.streamUrls.where((u) => !a.streamUrls.contains(u)),
    ];

    final categories = {...a.categories, ...b.categories}.toList();
    final languages = {...a.languages, ...b.languages}.toList();

    return a.copyWith(
      name: _preferName(a.name, b.name),
      logo: a.logo?.isNotEmpty == true ? a.logo : b.logo,
      country: _preferKnownCountry(a.country, b.country),
      countryCode: a.countryCode.isNotEmpty ? a.countryCode : b.countryCode,
      region: a.region?.isNotEmpty == true ? a.region : b.region,
      network: a.network?.isNotEmpty == true ? a.network : b.network,
      website: a.website?.isNotEmpty == true ? a.website : b.website,
      categories: categories,
      languages: languages,
      streamUrls: streamUrls,
    );
  }

  static String _preferName(String a, String b) {
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return a.toLowerCase() == b.toLowerCase() ? a : a;
  }

  static String _preferKnownCountry(String a, String b) {
    if (a.isEmpty || a == 'Unknown') return b;
    if (b.isEmpty || b == 'Unknown') return a;
    return a;
  }

  static int _compareByQualityThenName(FreeTvChannel a, FreeTvChannel b) {
    final byScore = b.qualityScore.compareTo(a.qualityScore);
    if (byScore != 0) return byScore;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  void _logDiagnostics(FreeTvCatalogDiagnostics d) {
    final buffer = StringBuffer('Free TV Catalog Summary\n');
    for (final s in d.sources) {
      buffer.writeln(
        '  ${s.source.name}: ${s.rawRecords} raw '
        '${s.succeeded ? '' : '(FAILED: ${s.error})'}',
      );
    }
    buffer.writeln('  Raw records: ${d.rawRecords}');
    buffer.writeln('  Unique channels: ${d.uniqueChannels}');
    buffer.writeln('  Recommended: ${d.recommendedCount}');
    buffer.writeln('  All valid: ${d.allValidCount}');
    buffer.writeln('  Excluded/duplicates: ${d.duplicatesRemoved + d.invalidRecords}');
    _logger.info(buffer.toString(), tag: 'FreeTvCatalogBuilder');
  }
}

class _FreeSourceResult {
  final List<M3UChannel>? channels;
  final String? error;

  _FreeSourceResult({this.channels, this.error});
}
