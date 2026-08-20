import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/auth/authentication_engine.dart';
import 'package:stream_hub/core/streaming/background/stream_task_manager.dart';
import 'package:stream_hub/core/streaming/cache/stream_cache.dart';
import 'package:stream_hub/core/streaming/download/download_preparation_service.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/events/stream_event_bus.dart';
import 'package:stream_hub/core/streaming/events/stream_events.dart';
import 'package:stream_hub/core/streaming/failover/failover_manager.dart';
import 'package:stream_hub/core/streaming/factory/playable_session_factory.dart';
import 'package:stream_hub/core/streaming/health/stream_health_monitor.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/prepared_download.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/models/stream_health_snapshot.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';
import 'package:stream_hub/core/streaming/network/header_engine.dart';
import 'package:stream_hub/core/streaming/network/url_normalizer.dart';
import 'package:stream_hub/core/streaming/resolver/stream_resolver.dart';
import 'package:stream_hub/core/streaming/security/sensitive_data_redactor.dart';
import 'package:stream_hub/core/streaming/session/session_manager.dart';
import 'package:stream_hub/core/streaming/validation/stream_validator.dart';

/// Looks up provider configuration (credentials, headers, server URL, ...) for
/// a provider id. Returns `null` when no config is stored.
typedef ProviderConfigProvider =
    Future<Map<String, dynamic>?> Function(String providerId);

/// The single source of truth for preparing all playback and download sessions.
///
/// Every media item passes through the same pipeline:
///
/// Provider Session → Resolver → Authentication → Headers → Cookies →
/// URL Normalization → Validation → PlayableSession
///
/// The player and download engine only ever receive [PlayableSession]s.
class StreamEngine {
  final SessionManager sessionManager;
  final StreamResolver resolver;
  final AuthenticationEngine authenticationEngine;
  final HeaderEngine headerEngine;
  final CookieManager cookieManager;
  final UrlNormalizer urlNormalizer;
  final StreamValidator streamValidator;
  final StreamHealthMonitor healthMonitor;
  final StreamCache streamCache;
  final PlayableSessionFactory playableSessionFactory;
  final DownloadPreparationService downloadPreparationService;
  final FailoverManager failoverManager;
  final StreamEventBus eventBus;
  final LoggingService logger;
  final StreamTaskManager? taskManager;

  ProviderConfigProvider? providerConfigProvider;

  StreamEngine({
    required this.sessionManager,
    required this.resolver,
    required this.authenticationEngine,
    required this.headerEngine,
    required this.cookieManager,
    required this.urlNormalizer,
    required this.streamValidator,
    required this.healthMonitor,
    required this.streamCache,
    required this.playableSessionFactory,
    required this.downloadPreparationService,
    required this.failoverManager,
    required this.eventBus,
    LoggingService? logger,
    this.taskManager,
    this.providerConfigProvider,
  }) : logger = logger ?? LoggingService();

  /// Resolves a media item into a playable, validated session.
  Future<PlayableSession> resolvePlayback({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
    bool useCache = true,
    bool validate = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    final cacheKey =
        '${providerId ?? _resolveProviderId(itemMetadata)}:$mediaItemId';
    if (useCache) {
      final cached = streamCache.getSession(cacheKey);
      if (cached != null && !cached.isExpired && validate) {
        final validation = await streamValidator.validate(
          cached,
          probeNetwork: _shouldProbeNetwork(cached),
        );
        if (validation.isValid) {
          logger.debug(
            'Stream cache hit for $mediaItemId',
            tag: 'StreamEngine',
          );
          return cached;
        }
        streamCache.invalidate(cacheKey);
      } else if (cached != null && !validate) {
        return cached;
      }
    }

    final providerConfig = await providerConfigProvider?.call(
      providerId ?? _resolveProviderId(itemMetadata),
    );

    final providerSession = await sessionManager.getOrCreateSession(
      mediaItemId: mediaItemId,
      providerType: providerType,
      itemMetadata: itemMetadata,
      providerConfig: providerConfig,
      providerId: providerId,
    );

    final playable = await _buildPlayableSession(
      mediaItemId: mediaItemId,
      providerSession: providerSession,
      itemMetadata: itemMetadata,
      fallbackUrl: fallbackUrl,
    );

    streamCache.putSession(playable);

    if (validate) {
      final validation = await streamValidator.validate(
        playable,
        probeNetwork: _shouldProbeNetwork(playable),
      );
      if (!validation.isValid) {
        throw StreamValidationException(
          message: validation.errors.isNotEmpty
              ? validation.errors.first
              : 'Stream validation failed.',
        );
      }
    }

    stopwatch.stop();
    logger.debug(
      'Resolved playable session for $mediaItemId in ${stopwatch.elapsedMilliseconds}ms',
      tag: 'StreamEngine',
    );
    return playable;
  }

  /// Resolves a raw source URL using an existing provider session. Used when a
  /// media item has no metadata (e.g. arbitrary URLs passed to the player).
  Future<PlayableSession> resolveStream({
    required String mediaItemId,
    required String url,
    required ProviderSession providerSession,
    Map<String, dynamic> itemMetadata = const {},
  }) async {
    final playable = await _buildPlayableSession(
      mediaItemId: mediaItemId,
      providerSession: providerSession,
      itemMetadata: itemMetadata,
      fallbackUrl: url,
    );
    streamCache.putSession(playable);
    return playable;
  }

  /// Builds a [PlayableSession] through the full pipeline: resolution,
  /// authentication, header injection, cookie attachment, URL normalization,
  /// and validation.
  Future<PlayableSession> _buildPlayableSession({
    required String mediaItemId,
    required ProviderSession providerSession,
    required Map<String, dynamic> itemMetadata,
    String? fallbackUrl,
  }) async {
    final sourceUrl = _extractSourceUrl(
      itemMetadata,
      fallbackUrl,
      providerSession: providerSession,
    );
    if (sourceUrl == null || sourceUrl.isEmpty) {
      throw const StreamResolutionException(
        message: 'Media item has no resolvable stream URL.',
      );
    }

    final resolution = await resolver.resolve(
      StreamResolutionRequest(
        session: providerSession,
        sourceUrl: sourceUrl,
        mediaItemId: mediaItemId,
        itemMetadata: itemMetadata,
      ),
    );

    eventBus.publish(
      StreamResolvedEvent(
        sessionId: providerSession.sessionId,
        providerId: providerSession.providerId,
        mediaItemId: mediaItemId,
        resolvedUrl: SensitiveDataRedactor.redactUrl(resolution.url),
        resolutionTime: Duration.zero,
        occurredAt: DateTime.now(),
      ),
    );

    final authenticatedUrl = authenticationEngine.applyAuthenticationToUrl(
      providerSession,
      resolution.url,
    );

    final normalizedUrl = urlNormalizer.canonicalize(authenticatedUrl);

    var cookies = cookieManager.getCookies(providerSession.providerId);
    if (cookies.isEmpty) {
      cookies = providerSession.cookies;
    }

    final headers = headerEngine.fromSession(
      providerSession,
      custom: {
        if (itemMetadata['referer'] != null)
          'Referer': itemMetadata['referer'].toString(),
        if (itemMetadata['origin'] != null)
          'Origin': itemMetadata['origin'].toString(),
      },
    );

    final playable = playableSessionFactory.create(
      mediaItemId: mediaItemId,
      providerSession: providerSession,
      resolution: resolution.copyWith(url: normalizedUrl),
      headers: headers,
      cookies: cookies,
      userAgent: providerSession.userAgent,
    );

    healthMonitor.startSession(playable.sessionId);

    eventBus.publish(
      PlaybackReadyEvent(
        sessionId: providerSession.sessionId,
        playableSessionId: playable.sessionId,
        mediaItemId: mediaItemId,
        occurredAt: DateTime.now(),
      ),
    );

    logger.debug(
      'Prepared playable session for $mediaItemId (${playable.streamType.displayName})',
      tag: 'StreamEngine',
    );

    return playable;
  }

  /// Prepares an authenticated download for a media item.
  Future<PreparedDownload> prepareDownload({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
    bool validate = true,
  }) async {
    final playable = await resolvePlayback(
      mediaItemId: mediaItemId,
      providerType: providerType,
      itemMetadata: itemMetadata,
      providerId: providerId,
      fallbackUrl: fallbackUrl,
      validate: validate,
    );

    final prepared = await downloadPreparationService.prepare(playable);

    if (prepared.canDownload) {
      eventBus.publish(
        DownloadReadyEvent(
          sessionId: playable.sessionId,
          playableSessionId: playable.sessionId,
          mediaItemId: mediaItemId,
          occurredAt: DateTime.now(),
        ),
      );
    }
    return prepared;
  }

  /// Validates a session using the stream validator.
  Future<bool> validateStream(PlayableSession session) async {
    final result = await streamValidator.validate(session);
    if (result.isValid) {
      healthMonitor.recordSuccess(
        session.sessionId,
        latencyMs: result.latencyMs,
        responseTimeMs: result.latencyMs,
      );
    } else {
      healthMonitor.recordFailure(session.sessionId);
    }
    return result.isValid;
  }

  /// Selects a working candidate (primary or backup) for a session.
  Future<PlayableSession> selectWorkingStream(PlayableSession session) {
    return failoverManager.selectWorking(
      session,
      test: (candidate) => validateStream(candidate),
    );
  }

  StreamHealthSnapshot? healthFor(String sessionId) {
    return healthMonitor.snapshotFor(sessionId);
  }

  /// Retrieves a cached session without re-resolving.
  PlayableSession? cachedSession(String providerId, String mediaItemId) {
    return streamCache.getSession('$providerId:$mediaItemId');
  }

  Future<void> startBackgroundTasks() {
    taskManager?.start();
    return Future.value();
  }

  Future<void> stopBackgroundTasks() {
    taskManager?.stop();
    return Future.value();
  }

  void dispose() {
    taskManager?.stop();
    healthMonitor.dispose();
    eventBus.dispose();
  }

  String? _extractSourceUrl(
    Map<String, dynamic> itemMetadata,
    String? fallbackUrl, {
    ProviderSession? providerSession,
  }) {
    final candidates = <String?>[
      itemMetadata['streamUrl']?.toString(),
      itemMetadata['stream_url']?.toString(),
      itemMetadata['url']?.toString(),
      itemMetadata['directSource']?.toString(),
      itemMetadata['direct_source']?.toString(),
      fallbackUrl,
    ];
    for (final candidate in candidates) {
      if (candidate != null &&
          candidate.isNotEmpty &&
          !candidate.startsWith('series://') &&
          !candidate.startsWith('stalker://')) {
        return candidate;
      }
    }

    // Check Stalker cmd first so Stalker streams resolve via StalkerStreamResolver
    final cmd = itemMetadata['cmd']?.toString();
    if (cmd != null && cmd.isNotEmpty) {
      return 'stalker://$cmd';
    }

    final seriesId = itemMetadata['seriesId']?.toString() ??
        itemMetadata['series_id']?.toString();
    if (seriesId != null &&
        seriesId.isNotEmpty &&
        providerSession?.providerType != MediaSourceType.stalker) {
      return 'series://$seriesId';
    }

    final streamId = itemMetadata['streamId']?.toString() ??
        itemMetadata['stream_id']?.toString();
    if (streamId != null &&
        streamId.isNotEmpty &&
        providerSession != null &&
        providerSession.baseUrl != null &&
        providerSession.baseUrl!.isNotEmpty &&
        providerSession.providerType != MediaSourceType.stalker) {
      final isVod = itemMetadata['isVod'] == true ||
          itemMetadata['containerExtension'] != null ||
          itemMetadata['container_extension'] != null;
      final ext = itemMetadata['containerExtension']?.toString() ??
          itemMetadata['container_extension']?.toString() ??
          (isVod ? 'mp4' : 'ts');
      final typeSegment = isVod ? 'movie' : 'live';
      final u = providerSession.username ?? '';
      final p = providerSession.password ?? '';
      return '${providerSession.baseUrl}/$typeSegment/$u/$p/$streamId.$ext';
    }

    return null;
  }

  /// Whether an end-to-end network probe should gate playback.
  ///
  /// Authenticated raw MPEG-TS live sessions are endless streams served
  /// through token redirects and panel CDNs. Probing them is unreliable:
  /// panels often reject HEAD, CDNs enforce connection limits and return
  /// transient 403/503 responses, and the body never ends. Validation is
  /// therefore limited to local checks (URL, scheme, expiry, headers) and the
  /// player surfaces any real failure during playback. Finite content (HLS,
  /// DASH, MP4, MKV) is still probed so 404/401 issues are caught early.
  bool _shouldProbeNetwork(PlayableSession playable) {
    if (playable.providerType == MediaSourceType.stalker) {
      return false;
    }
    return playable.streamType != StreamType.mpegTs;
  }

  String _resolveProviderId(Map<String, dynamic> itemMetadata) {
    final explicit = itemMetadata['providerId']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return 'unknown_provider';
  }
}
