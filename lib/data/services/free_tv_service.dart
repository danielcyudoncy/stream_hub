import 'dart:async';

import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/services/free_tv_catalog_builder.dart';
import 'package:stream_hub/data/sources/free_tv_sources.dart';

/// Service responsible for fetching, aggregating, deduplicating, and
/// quality-filtering the public IPTV-org Free Live TV catalog.
///
/// The catalog is built from multiple IPTV-org playlist sources (global,
/// country, region, and category) that are parsed, normalized, merged into a
/// single unified channel catalog, deduplicated by stable channel ID, and
/// filtered through the quality/eligibility layer. A single source failing
/// never takes down the whole catalog.
class FreeTvService {
  // Legacy JSON API endpoints retained for reference/fallback; the primary
  // ingestion path now runs on the curated IPTV-org M3U playlist sources.
  static const String kChannelsUrl =
      'https://iptv-org.github.io/api/channels.json';
  static const String kStreamsUrl =
      'https://iptv-org.github.io/api/streams.json';
  static const String kCountriesUrl =
      'https://iptv-org.github.io/api/countries.json';
  static const String kCategoriesUrl =
      'https://iptv-org.github.io/api/categories.json';

  final FreeTvCatalogBuilder _builder;
  final LoggingService _logger;

  FreeTvCatalogResult? _lastResult;

  FreeTvService({
    FreeTvCatalogBuilder? builder,
    LoggingService? logger,
  })  : _builder = builder ?? FreeTvCatalogBuilder(),
        _logger = logger ?? LoggingService();

  /// Runs the full ingestion pipeline and returns the complete result
  /// (all-valid catalog, recommended subset, and diagnostics).
  Future<FreeTvCatalogResult> buildCatalog({
    List<FreeTvSource> sources = FreeTvSources.all,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final result = await _builder.build(
      sources: sources,
      timeout: timeout,
    );
    _lastResult = result;
    return result;
  }

  /// Convenience: returns only the recommended (curated) channels.
  Future<List<FreeTvChannel>> fetchRecommended({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_lastResult != null) return _lastResult!.recommended;
    final result = await buildCatalog(timeout: timeout);
    return result.recommended;
  }

  /// Fetches, aggregates, and filters the full Free Live TV catalog.
  ///
  /// Returns the all-valid, quality-assigned channels sorted by quality score.
  /// The returned records carry `qualityTier`, so callers can build curated
  /// views without a second round-trip.
  Future<List<FreeTvChannel>> fetchCatalog({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _logger.info(
      'Building Free Live TV catalog from ${FreeTvSources.all.length} IPTV-org sources...',
      tag: 'FreeTvService',
    );
    final result = await buildCatalog(timeout: timeout);
    _logger.info(
      'Free TV catalog ready: ${result.allValid.length} valid, '
      '${result.recommended.length} recommended.',
      tag: 'FreeTvService',
    );
    return result.allValid;
  }
}