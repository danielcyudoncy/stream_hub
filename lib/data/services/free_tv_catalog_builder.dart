import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/dearbulut_dtos.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/models/free_tv_stream.dart';
import 'package:stream_hub/data/parsers/free_tv_mapper.dart';
import 'package:stream_hub/data/remote/free_tv_m3u_remote_data_source.dart';
import 'package:stream_hub/data/remote/free_tv_remote_data_source.dart';
import 'package:stream_hub/data/services/free_tv_quality_service.dart';
import 'package:stream_hub/data/sources/free_tv_api_config.dart';

/// Per-source fetch/diagnostics result.
class FreeTvSourceFetchResult {
  final String sourceName;
  final bool succeeded;
  final int rawRecords;
  final String? error;

  const FreeTvSourceFetchResult({
    required this.sourceName,
    required this.succeeded,
    required this.rawRecords,
    this.error,
  });
}

/// Aggregate pipeline diagnostics.
class FreeTvCatalogDiagnostics {
  final List<FreeTvSourceFetchResult> sources;
  final int rawRecords;
  final int uniqueChannels;
  final int invalidRecords;
  final int junkRecords;
  final int noStreamRecords;
  final int nsfwRecords;
  final int nonEnglishRecords;
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
    this.nonEnglishRecords = 0,
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

/// Orchestrates the Free Live TV multi-source ingestion pipeline:
///
/// ```text
/// dearbulut/iptv JSON API + Custom M3U Sources
///   → fetch online channels & countries metadata
///   → parse DTOs / M3U playlists
///   → normalize into canonical FreeTvChannel models
///   → aggregate & deduplicate across all sources by stable channel ID
///   → merge multi-stream metadata
///   → hard eligibility filtering (FreeTvQualityService)
///   → quality scoring + tier assignment (Recommended vs Valid)
///   → unified catalog
/// ```
class FreeTvCatalogBuilder {
  final FreeTvRemoteDataSource _remoteDataSource;
  final CustomM3uFreeTvRemoteDataSource? _m3uRemoteDataSource;
  final FreeTvMapper _mapper;
  final FreeTvQualityService _quality;
  final LoggingService _logger;

  FreeTvCatalogBuilder({
    FreeTvRemoteDataSource? remoteDataSource,
    CustomM3uFreeTvRemoteDataSource? m3uRemoteDataSource,
    FreeTvMapper? mapper,
    FreeTvQualityService? quality,
    LoggingService? logger,
  })  : _remoteDataSource = remoteDataSource ?? DearbulutFreeTvRemoteDataSource(),
        _m3uRemoteDataSource = m3uRemoteDataSource,
        _mapper = mapper ?? FreeTvMapper(),
        _quality = quality ?? FreeTvQualityService(),
        _logger = logger ?? LoggingService();

  /// Fetches and processes channels from both JSON and M3U sources,
  /// merges them into a unified catalog, and applies quality filters.
  Future<FreeTvCatalogResult> build({
    Duration timeout = FreeTvApiConfig.defaultTimeout,
    List<FreeTvChannel>? m3uChannels,
  }) async {
    final sourcesResults = <FreeTvSourceFetchResult>[];
    List<DearbulutChannelDto> rawDtos = [];
    Map<String, String> countryNameLookup = {};

    // 1. Fetch countries metadata for accurate country naming
    try {
      final countries = await _remoteDataSource.fetchCountries(timeout: timeout);
      for (final c in countries) {
        if (c.code.isNotEmpty && c.name.isNotEmpty) {
          countryNameLookup[c.code] = c.name;
        }
      }
    } catch (e) {
      _logger.warning('Failed to fetch country metadata: $e', tag: 'FreeTvCatalogBuilder');
    }

    // 2. Fetch online channels from JSON API
    try {
      rawDtos = await _remoteDataSource.fetchOnlineChannels(timeout: timeout);
      sourcesResults.add(FreeTvSourceFetchResult(
        sourceName: 'dearbulut/channels.online',
        succeeded: true,
        rawRecords: rawDtos.length,
      ));
    } catch (e) {
      _logger.error('Failed to fetch online channels from dearbulut: $e',
          tag: 'FreeTvCatalogBuilder');
      sourcesResults.add(FreeTvSourceFetchResult(
        sourceName: 'dearbulut/channels.online',
        succeeded: false,
        rawRecords: 0,
        error: '$e',
      ));
      rethrow;
    }

    // 3. Ingest M3U channels (explicitly provided or from registered remote data source)
    List<FreeTvChannel> fetchedM3uChannels = [];
    if (m3uChannels != null) {
      fetchedM3uChannels = m3uChannels;
      sourcesResults.add(FreeTvSourceFetchResult(
        sourceName: 'm3u/provided',
        succeeded: true,
        rawRecords: m3uChannels.length,
      ));
    } else if (_m3uRemoteDataSource != null) {
      try {
        fetchedM3uChannels = await _m3uRemoteDataSource.fetchOnlineChannels(timeout: timeout);
        sourcesResults.add(FreeTvSourceFetchResult(
          sourceName: _m3uRemoteDataSource.source.id,
          succeeded: true,
          rawRecords: fetchedM3uChannels.length,
        ));
      } catch (e) {
        _logger.warning('Failed to fetch M3U channels: $e', tag: 'FreeTvCatalogBuilder');
        sourcesResults.add(FreeTvSourceFetchResult(
          sourceName: _m3uRemoteDataSource.source.id,
          succeeded: false,
          rawRecords: 0,
          error: '$e',
        ));
      }
    }

    // 4. Map JSON DTOs to canonical FreeTvChannel records
    final jsonChannels = <FreeTvChannel>[];
    var nsfwCount = 0;
    var invalidCount = 0;

    for (final dto in rawDtos) {
      if (dto.isNsfw) {
        nsfwCount++;
        continue;
      }
      if (dto.id.trim().isEmpty || dto.name.trim().isEmpty) {
        invalidCount++;
        continue;
      }
      jsonChannels.add(_mapper.fromDearbulutDto(
        dto,
        countryNameLookup: countryNameLookup,
      ));
    }

    final allRawChannels = <FreeTvChannel>[
      ...fetchedM3uChannels,
      ...jsonChannels,
    ];

    return _processChannels(
      allRawChannels,
      sourcesResults: sourcesResults,
      totalRawRecords: rawDtos.length + fetchedM3uChannels.length,
      initialNsfwCount: nsfwCount,
      initialInvalidCount: invalidCount,
    );
  }

  /// Directly builds a unified catalog from pre-normalized channels,
  /// applying aggregation, deduplication, quality filtering, and diagnostics.
  Future<FreeTvCatalogResult> buildFromChannels(
    List<FreeTvChannel> channels, {
    Duration timeout = FreeTvApiConfig.defaultTimeout,
    List<FreeTvSourceFetchResult>? sources,
  }) async {
    return _processChannels(
      channels,
      sourcesResults: sources ?? [
        FreeTvSourceFetchResult(
          sourceName: 'pre_normalized_channels',
          succeeded: true,
          rawRecords: channels.length,
        ),
      ],
      totalRawRecords: channels.length,
    );
  }

  FreeTvCatalogResult _processChannels(
    List<FreeTvChannel> channels, {
    required List<FreeTvSourceFetchResult> sourcesResults,
    required int totalRawRecords,
    int initialNsfwCount = 0,
    int initialInvalidCount = 0,
  }) {
    final aggregated = <String, FreeTvChannel>{};
    var nsfwCount = initialNsfwCount;
    var invalidCount = initialInvalidCount;
    var nonEnglishCount = 0;
    var duplicatesRemoved = 0;

    for (final ch in channels) {
      if (ch.isNsfw) {
        nsfwCount++;
        continue;
      }
      if (ch.id.trim().isEmpty || ch.name.trim().isEmpty) {
        invalidCount++;
        continue;
      }

      final existing = aggregated[ch.id];
      if (existing == null) {
        aggregated[ch.id] = ch;
      } else {
        duplicatesRemoved++;
        aggregated[ch.id] = _mergeChannels(existing, ch);
      }
    }

    final eligible = <FreeTvChannel>[];
    for (final ch in aggregated.values) {
      if (_quality.isEligible(ch)) {
        eligible.add(_quality.assignTier(ch));
      } else {
        final isEnglish = ch.languages.any((l) {
          final lower = l.trim().toLowerCase();
          return lower == 'english' || lower == 'eng' || lower == 'en';
        });
        if (!isEnglish) {
          nonEnglishCount++;
        } else {
          invalidCount++;
        }
      }
    }

    final recommended = eligible
        .where((c) => c.qualityTier == FreeTvQualityTier.recommended)
        .toList()
      ..sort(_compareByQualityThenName);
    final allValid = eligible.toList()..sort(_compareByQualityThenName);

    final diagnostics = FreeTvCatalogDiagnostics(
      sources: sourcesResults,
      rawRecords: totalRawRecords,
      uniqueChannels: aggregated.length,
      duplicatesRemoved: duplicatesRemoved,
      invalidRecords: invalidCount,
      nsfwRecords: nsfwCount,
      nonEnglishRecords: nonEnglishCount,
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

  FreeTvChannel _mergeChannels(FreeTvChannel a, FreeTvChannel b) {
    final mergedStreams = <FreeTvStream>[...a.streams];
    final existingUrls = a.streams.map((s) => s.url).toSet();

    for (final u in a.streamUrls) {
      if (!existingUrls.contains(u)) {
        mergedStreams.add(FreeTvStream(
          url: u,
          label: u.contains('.m3u8') ? 'm3u8' : 'ts',
          isOnline: true,
          healthScore: 100.0,
        ));
        existingUrls.add(u);
      }
    }

    for (final s in b.streams) {
      if (!existingUrls.contains(s.url)) {
        mergedStreams.add(s);
        existingUrls.add(s.url);
      }
    }

    for (final u in b.streamUrls) {
      if (!existingUrls.contains(u)) {
        mergedStreams.add(FreeTvStream(
          url: u,
          label: u.contains('.m3u8') ? 'm3u8' : 'ts',
          isOnline: true,
          healthScore: 100.0,
        ));
        existingUrls.add(u);
      }
    }

    mergedStreams.sort((s1, s2) {
      if (s1.isOnline != s2.isOnline) {
        return s1.isOnline ? -1 : 1;
      }
      final scoreA = s1.healthScore ?? (s1.isOnline ? 100.0 : 0.0);
      final scoreB = s2.healthScore ?? (s2.isOnline ? 100.0 : 0.0);
      return scoreB.compareTo(scoreA);
    });

    final streamUrls = mergedStreams.map((s) => s.url).toList();
    final categories = {...a.categories, ...b.categories}.toList();
    final languages = {...a.languages, ...b.languages}.toList();

    return a.copyWith(
      name: a.name.isNotEmpty ? a.name : b.name,
      logo: (a.logo?.isNotEmpty == true) ? a.logo : b.logo,
      country: (a.country.isNotEmpty && a.country != 'International' && a.country != 'Unknown')
          ? a.country
          : b.country,
      countryCode: a.countryCode.isNotEmpty ? a.countryCode : b.countryCode,
      region: a.region?.isNotEmpty == true ? a.region : b.region,
      network: a.network?.isNotEmpty == true ? a.network : b.network,
      website: a.website?.isNotEmpty == true ? a.website : b.website,
      categories: categories,
      languages: languages,
      streams: mergedStreams,
      streamUrls: streamUrls,
    );
  }

  static int _compareByQualityThenName(FreeTvChannel a, FreeTvChannel b) {
    final byScore = b.qualityScore.compareTo(a.qualityScore);
    if (byScore != 0) return byScore;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  void _logDiagnostics(FreeTvCatalogDiagnostics d) {
    final buffer = StringBuffer('Free TV Unified Catalog Summary\n');
    for (final s in d.sources) {
      buffer.writeln(
        '  ${s.sourceName}: ${s.rawRecords} records '
        '${s.succeeded ? '✓' : '(FAILED: ${s.error})'}',
      );
    }
    buffer.writeln('  Raw records: ${d.rawRecords}');
    buffer.writeln('  Unique channels: ${d.uniqueChannels}');
    buffer.writeln('  Recommended: ${d.recommendedCount}');
    buffer.writeln('  All valid: ${d.allValidCount}');
    buffer.writeln('  Duplicates merged: ${d.duplicatesRemoved}');
    buffer.writeln('  NSFW excluded: ${d.nsfwRecords}');
    buffer.writeln('  Non-English excluded: ${d.nonEnglishRecords}');
    buffer.writeln('  Invalid excluded: ${d.invalidRecords}');
    _logger.info(buffer.toString(), tag: 'FreeTvCatalogBuilder');
  }
}
