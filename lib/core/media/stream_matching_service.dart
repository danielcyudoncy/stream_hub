import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';

class StreamMatchResult {
  final bool isAvailable;
  final MediaItem? matchedItem;
  final String? matchedProviderId;
  final String? matchedProviderName;
  final String? quality;

  const StreamMatchResult({
    required this.isAvailable,
    this.matchedItem,
    this.matchedProviderId,
    this.matchedProviderName,
    this.quality,
  });

  static const notAvailable = StreamMatchResult(isAvailable: false);
}

class StreamMatchingService {
  final CatalogRepository catalogRepository;
  final ProviderRepository? providerRepository;
  final MediaLibrary? mediaLibrary;
  final LoggingService logger;

  StreamMatchingService({
    required this.catalogRepository,
    this.providerRepository,
    this.mediaLibrary,
    LoggingService? logger,
  }) : logger = logger ?? LoggingService();

  static final RegExp _cleanNoisePattern = RegExp(
    r'(\b(4k|uhd|1080p|720p|fhd|hevc|h264|h265|x264|x265|aac|5\.1|7\.1|hdr|web-dl|bluray|dvdrip|remux)\b|^\|[a-z0-9]+\||\b[a-z]{2,3}\s*[-:|]\s*)',
    caseSensitive: false,
  );

  static final RegExp _yearPattern = RegExp(r'\(?([12][09]\d{2})\)?');

  Future<StreamMatchResult> matchMovie(MediaItem movie) => findMatch(movie);
  Future<StreamMatchResult> matchSeries(MediaItem series) => findMatch(series);

  Future<StreamMatchResult> findMatch(MediaItem target) async {
    // If it's already a native provider item, it's inherently available
    if (target.providerId.isNotEmpty && target.providerId != 'tmdb') {
      return StreamMatchResult(
        isAvailable: true,
        matchedItem: target,
        matchedProviderId: target.providerId,
        quality: _detectQuality(target.title),
      );
    }

    final targetTmdbId = target.metadata['tmdbId']?.toString();
    final targetYear = _resolveYear(target.metadata['year'], target.title);
    final targetCleanTitle = normalizeTitle(target.title);

    var providerCandidates = await catalogRepository.getByType(target.mediaType);
    if (providerCandidates.isEmpty && mediaLibrary != null) {
      if (target.mediaType == MediaType.movie) {
        providerCandidates = mediaLibrary!.getMovies();
      } else if (target.mediaType == MediaType.series) {
        providerCandidates = mediaLibrary!.getSeries();
      }
    }
    if (providerCandidates.isEmpty) {
      return StreamMatchResult.notAvailable;
    }

    // 1. Direct TMDB ID match
    if (targetTmdbId != null && targetTmdbId.isNotEmpty) {
      for (final candidate in providerCandidates) {
        if (candidate.providerId == 'tmdb') continue;
        final cTmdbId = candidate.metadata['tmdb_id']?.toString() ??
            candidate.metadata['tmdbId']?.toString();
        if (cTmdbId != null && cTmdbId == targetTmdbId) {
          final providerName = await _resolveProviderName(candidate.providerId);
          return StreamMatchResult(
            isAvailable: true,
            matchedItem: candidate,
            matchedProviderId: candidate.providerId,
            matchedProviderName: providerName,
            quality: _detectQuality(candidate.title),
          );
        }
      }
    }

    // 2. Fuzzy Title + Year match
    MediaItem? bestMatch;
    double bestScore = 0.0;

    for (final candidate in providerCandidates) {
      if (candidate.providerId == 'tmdb') continue;

      final candCleanTitle = normalizeTitle(candidate.title);
      if (candCleanTitle.isEmpty) continue;

      // Check year if both have it
      if (targetYear != null) {
        final candYear = _resolveYear(candidate.metadata['year'], candidate.title);
        if (candYear != null && (candYear - targetYear).abs() > 1) {
          continue; // Mismatched release year (more than 1 year difference)
        }
      }

      // Exact match after cleaning
      if (candCleanTitle == targetCleanTitle) {
        bestMatch = candidate;
        bestScore = 1.0;
        break;
      }

      // Substring match
      if (candCleanTitle.startsWith(targetCleanTitle) || targetCleanTitle.startsWith(candCleanTitle)) {
        final score = 0.9;
        if (score > bestScore) {
          bestScore = score;
          bestMatch = candidate;
        }
      }
    }

    if (bestMatch != null && bestScore >= 0.85) {
      final providerName = await _resolveProviderName(bestMatch.providerId);
      return StreamMatchResult(
        isAvailable: true,
        matchedItem: bestMatch,
        matchedProviderId: bestMatch.providerId,
        matchedProviderName: providerName,
        quality: _detectQuality(bestMatch.title),
      );
    }

    return StreamMatchResult.notAvailable;
  }

  static String normalizeTitle(String raw) {
    var s = raw.toLowerCase();
    s = s.replaceAll(_cleanNoisePattern, ' ');
    s = s.replaceAll(_yearPattern, ' ');
    s = s.replaceAll(RegExp(r'[^a-z0-9]'), ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static int? _resolveYear(dynamic raw, String title) {
    if (raw is int) return raw;
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null && parsed > 1800 && parsed < 2200) return parsed;
    }
    return _extractYear(title);
  }

  static int? _extractYear(String text) {
    final match = _yearPattern.firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  static String _detectQuality(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('4k') || lower.contains('uhd')) return '4K UHD';
    if (lower.contains('1080p') || lower.contains('fhd')) return '1080p FHD';
    if (lower.contains('720p') || lower.contains('hd')) return '720p HD';
    return 'HD';
  }

  Future<String?> _resolveProviderName(String providerId) async {
    final repo = providerRepository;
    if (repo == null) return null;
    try {
      final providers = await repo.getAllProviders();
      return providers.where((p) => p.id == providerId).firstOrNull?.name;
    } catch (_) {
      return null;
    }
  }
}
