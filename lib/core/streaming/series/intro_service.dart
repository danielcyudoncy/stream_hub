import 'package:stream_hub/data/models/intro_segment.dart';
import 'package:stream_hub/data/models/media_item.dart';

/// Service responsible for managing, storing, and discovering intro/outro segments for media episodes.
class IntroService {
  final Map<String, IntroSegment> _cache = {};

  IntroService();

  /// Retrieves an [IntroSegment] for a given [episode], first checking the cache, then
  /// extracting from [episode.metadata] if present.
  IntroSegment? getIntroSegment(MediaItem episode) {
    if (_cache.containsKey(episode.id)) {
      return _cache[episode.id];
    }

    final segment = _extractFromMetadata(episode);
    if (segment != null) {
      _cache[episode.id] = segment;
      return segment;
    }

    return null;
  }

  /// Manually registers or updates an [IntroSegment] for an episode.
  void registerIntroSegment(String episodeId, IntroSegment segment) {
    _cache[episodeId] = segment;
  }

  /// Clears the cached intro segments.
  void clear() {
    _cache.clear();
  }

  static IntroSegment? _extractFromMetadata(MediaItem item) {
    final meta = item.metadata;
    if (meta.isEmpty) return null;

    // Check for direct introSegment map
    if (meta['introSegment'] is Map) {
      return IntroSegment.fromMap(meta['introSegment'] as Map);
    }
    if (meta['intro_segment'] is Map) {
      return IntroSegment.fromMap(meta['intro_segment'] as Map);
    }

    // Check for start and end timestamp fields
    final startMs = meta['introStartMs'] ?? meta['intro_start_ms'] ?? meta['introStart'] ?? meta['intro_start'];
    final endMs = meta['introEndMs'] ?? meta['intro_end_ms'] ?? meta['introEnd'] ?? meta['intro_end'];

    if (startMs != null && endMs != null) {
      final start = _parseDuration(startMs);
      final end = _parseDuration(endMs);
      if (start != null && end != null && end > start) {
        return IntroSegment(
          start: start,
          end: end,
          source: meta['introSource']?.toString() ?? 'metadata',
          confidence: double.tryParse(meta['introConfidence']?.toString() ?? '1.0') ?? 1.0,
          episodeId: item.id,
        );
      }
    }

    return null;
  }

  static Duration? _parseDuration(dynamic value) {
    if (value == null) return null;
    if (value is Duration) return value;
    if (value is int) {
      // If value is small (< 1000), treat as seconds, otherwise as milliseconds
      if (value < 1000) {
        return Duration(seconds: value);
      }
      return Duration(milliseconds: value);
    }
    if (value is double) {
      return Duration(milliseconds: (value * 1000).round());
    }
    if (value is String) {
      final intVal = int.tryParse(value);
      if (intVal != null) {
        return intVal < 1000 ? Duration(seconds: intVal) : Duration(milliseconds: intVal);
      }
      final doubleVal = double.tryParse(value);
      if (doubleVal != null) {
        return Duration(milliseconds: (doubleVal * 1000).round());
      }
      // Try mm:ss format
      final parts = value.split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final s = int.tryParse(parts[1]) ?? 0;
        return Duration(minutes: m, seconds: s);
      }
    }
    return null;
  }
}
