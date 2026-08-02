import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/stream_resolution.dart';

/// In-memory, TTL-based cache for resolved streams.
///
/// Caches playable sessions, resolved URLs, headers, authentication, and
/// validation results so repeated playback/download requests resolve instantly.
class StreamCache {
  final Duration ttl;
  final int maxEntries;

  final Map<String, _SessionEntry> _sessions = {};
  final Map<String, _ResolutionEntry> _resolutions = {};

  StreamCache({this.ttl = const Duration(minutes: 30), this.maxEntries = 256});

  bool get isEmpty => _sessions.isEmpty && _resolutions.isEmpty;

  /// Caches a playable session keyed by its [PlayableSession.cacheKey].
  void putSession(PlayableSession session) {
    evictExpired();
    if (_sessions.length >= maxEntries) {
      _evictOldest();
    }
    final sessionExpiry = session.expiresAt ?? DateTime.now().add(ttl);
    _sessions[session.cacheKey] = _SessionEntry(
      session: session,
      cachedAt: DateTime.now(),
      expiresAt: sessionExpiry,
    );
  }

  /// Returns a cached session that is neither expired nor evicted.
  PlayableSession? getSession(String cacheKey) {
    final entry = _sessions[cacheKey];
    if (entry == null) return null;
    if (entry.isExpired) {
      _sessions.remove(cacheKey);
      return null;
    }
    return entry.session;
  }

  /// Caches a resolution keyed by the source URL.
  void cacheResolution(String sourceUrl, StreamResolution resolution) {
    _resolutions[sourceUrl] = _ResolutionEntry(
      resolution: resolution,
      cachedAt: DateTime.now(),
      expiresAt: resolution.expiresAt ?? DateTime.now().add(ttl),
    );
  }

  StreamResolution? getResolution(String sourceUrl) {
    final entry = _resolutions[sourceUrl];
    if (entry == null) return null;
    if (entry.isExpired) {
      _resolutions.remove(sourceUrl);
      return null;
    }
    return entry.resolution;
  }

  void invalidate(String cacheKey) {
    _sessions.remove(cacheKey);
  }

  void invalidateResolution(String sourceUrl) {
    _resolutions.remove(sourceUrl);
  }

  void clear() {
    _sessions.clear();
    _resolutions.clear();
  }

  void evictExpired() {
    final now = DateTime.now();
    _sessions.removeWhere((_, e) => e.expiresAt.isBefore(now));
    _resolutions.removeWhere((_, e) => e.expiresAt.isBefore(now));
  }

  void _evictOldest() {
    if (_sessions.isEmpty) return;
    String? oldestKey;
    DateTime? oldestAt;
    for (final entry in _sessions.entries) {
      if (oldestAt == null || entry.value.cachedAt.isBefore(oldestAt)) {
        oldestAt = entry.value.cachedAt;
        oldestKey = entry.key;
      }
    }
    if (oldestKey != null) {
      _sessions.remove(oldestKey);
    }
  }

  int get sessionCount => _sessions.length;
  int get resolutionCount => _resolutions.length;
}

class _SessionEntry {
  final PlayableSession session;
  final DateTime cachedAt;
  final DateTime expiresAt;

  _SessionEntry({
    required this.session,
    required this.cachedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class _ResolutionEntry {
  final StreamResolution resolution;
  final DateTime cachedAt;
  final DateTime expiresAt;

  _ResolutionEntry({
    required this.resolution,
    required this.cachedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
