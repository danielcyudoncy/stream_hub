import 'dart:async';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/streaming/auth/authentication_engine.dart';
import 'package:stream_hub/core/streaming/cache/session_cache.dart';
import 'package:stream_hub/core/streaming/cache/stream_cache.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';

/// Intervals for background Stream Engine tasks.
class StreamTaskConfig {
  final Duration sessionRefreshInterval;
  final Duration cookieCleanupInterval;
  final Duration cacheCleanupInterval;
  final Duration sessionExpiryGrace;

  const StreamTaskConfig({
    this.sessionRefreshInterval = const Duration(minutes: 5),
    this.cookieCleanupInterval = const Duration(hours: 1),
    this.cacheCleanupInterval = const Duration(minutes: 10),
    this.sessionExpiryGrace = const Duration(minutes: 5),
  });
}

/// Manages background maintenance for the Stream Engine: token/session refresh,
/// cookie cleanup, cache eviction, and session expiry handling.
///
/// Tasks are periodic, low-frequency, and never block application startup.
class StreamTaskManager {
  final SessionCache _sessionCache;
  final CookieManager _cookieManager;
  final StreamCache _streamCache;
  final AuthenticationEngine _authenticationEngine;
  final StreamTaskConfig _config;
  final LoggingService _logger;

  Timer? _sessionTimer;
  Timer? _cookieTimer;
  Timer? _cacheTimer;
  bool _running = false;

  StreamTaskManager({
    required SessionCache sessionCache,
    required CookieManager cookieManager,
    required StreamCache streamCache,
    required AuthenticationEngine authenticationEngine,
    StreamTaskConfig? config,
    LoggingService? logger,
  }) : _sessionCache = sessionCache,
       _cookieManager = cookieManager,
       _streamCache = streamCache,
       _authenticationEngine = authenticationEngine,
       _config = config ?? StreamTaskConfig(),
       _logger = logger ?? LoggingService();

  bool get isRunning => _running;

  void start() {
    if (_running) return;
    _running = true;

    _sessionTimer = Timer.periodic(
      _config.sessionRefreshInterval,
      (_) => _refreshSessions(),
    );
    _cookieTimer = Timer.periodic(
      _config.cookieCleanupInterval,
      (_) => _cleanupCookies(),
    );
    _cacheTimer = Timer.periodic(
      _config.cacheCleanupInterval,
      (_) => _cleanupCache(),
    );

    _logger.info('StreamTaskManager started', tag: 'StreamTaskManager');
  }

  void stop() {
    _sessionTimer?.cancel();
    _cookieTimer?.cancel();
    _cacheTimer?.cancel();
    _sessionTimer = null;
    _cookieTimer = null;
    _cacheTimer = null;
    _running = false;
    _logger.info('StreamTaskManager stopped', tag: 'StreamTaskManager');
  }

  /// Refreshes provider sessions that are close to expiry.
  Future<void> _refreshSessions() async {
    final sessions = await _sessionCache.getAllProviderSessions();
    for (final session in sessions) {
      final expiresAt = session.expiresAt;
      if (expiresAt == null) continue;
      final grace = _config.sessionExpiryGrace;
      if (DateTime.now().isAfter(expiresAt.subtract(grace))) {
        try {
          final refreshed = await _authenticationEngine.ensureValidSession(
            session,
          );
          await _sessionCache.saveProviderSession(refreshed);
        } catch (e) {
          _logger.warning(
            'Background session refresh failed for ${session.providerId}',
            tag: 'StreamTaskManager',
            error: e,
          );
        }
      }
    }
  }

  void _cleanupCookies() {
    _cookieManager.removeExpiredAll();
  }

  void _cleanupCache() {
    _streamCache.evictExpired();
  }
}
