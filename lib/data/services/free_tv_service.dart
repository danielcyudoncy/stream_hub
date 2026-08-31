import 'dart:async';

import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/services/free_tv_catalog_builder.dart';
import 'package:stream_hub/data/sources/free_tv_api_config.dart';

/// Service responsible for fetching, aggregating, deduplicating, and
/// quality-filtering the normalized Free Live TV catalog.
///
/// Ingests stream-health-aware JSON datasets from dearbulut/iptv (IPTV Nexus),
/// normalizes models, merges metadata, deduplicates by stable ID, and filters
/// through the quality layer.
class FreeTvService {
  final FreeTvCatalogBuilder _builder;
  final LoggingService _logger;

  FreeTvCatalogResult? _lastResult;

  FreeTvService({
    FreeTvCatalogBuilder? builder,
    LoggingService? logger,
  })  : _builder = builder ?? FreeTvCatalogBuilder(),
        _logger = logger ?? LoggingService();

  /// Runs the full JSON ingestion pipeline and returns the complete result
  /// (all-valid catalog, recommended subset, and diagnostics).
  Future<FreeTvCatalogResult> buildCatalog({
    Duration timeout = FreeTvApiConfig.defaultTimeout,
  }) async {
    final result = await _builder.build(timeout: timeout);
    _lastResult = result;
    return result;
  }

  /// Returns the latest diagnostics report or null if not yet fetched.
  FreeTvCatalogDiagnostics? get lastDiagnostics => _lastResult?.diagnostics;

  /// Convenience: returns only the recommended (curated) channels.
  Future<List<FreeTvChannel>> fetchRecommended({
    Duration timeout = FreeTvApiConfig.defaultTimeout,
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
    Duration timeout = FreeTvApiConfig.defaultTimeout,
  }) async {
    _logger.info(
      'Fetching Free Live TV JSON catalog from dearbulut/iptv...',
      tag: 'FreeTvService',
    );
    final result = await buildCatalog(timeout: timeout);
    _logger.info(
      'Free TV catalog ready: ${result.allValid.length} valid channels, '
      '${result.recommended.length} recommended.',
      tag: 'FreeTvService',
    );
    return result.allValid;
  }
}