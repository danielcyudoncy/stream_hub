import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/auth/authentication_engine.dart';
import 'package:stream_hub/core/streaming/cache/session_cache.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/events/stream_event_bus.dart';
import 'package:stream_hub/core/streaming/events/stream_events.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory_registry.dart';

/// Manages provider session lifecycle: creation via provider adapters, reuse,
/// persistence, authentication, refresh, and invalidation.
class SessionManager {
  final SessionCache _sessionCache;
  final AuthenticationEngine _authenticationEngine;
  final CookieManager _cookieManager;
  final ProviderSessionFactoryRegistry _registry;
  final StreamEventBus _eventBus;
  final LoggingService _logger;

  SessionManager({
    required SessionCache sessionCache,
    required AuthenticationEngine authenticationEngine,
    required CookieManager cookieManager,
    required ProviderSessionFactoryRegistry registry,
    StreamEventBus? eventBus,
    LoggingService? logger,
  }) : _sessionCache = sessionCache,
       _authenticationEngine = authenticationEngine,
       _cookieManager = cookieManager,
       _registry = registry,
       _eventBus = eventBus ?? StreamEventBus(),
       _logger = logger ?? LoggingService();

  ProviderSessionFactoryRegistry get registry => _registry;

  /// Returns a valid provider session for a media item, creating one when
  /// needed. The session is authenticated and persisted.
  Future<ProviderSession> getOrCreateSession({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    Map<String, dynamic>? providerConfig,
    String? providerId,
  }) async {
    final resolvedProviderId = providerId ?? _resolveProviderId(itemMetadata);
    var session = await _sessionCache.getProviderSession(resolvedProviderId);

    final hasCachedSession = session != null;
    final credentialMismatch = _hasCredentialMismatch(session, providerConfig);
    if (session == null || session.providerType != providerType || credentialMismatch) {
      if (credentialMismatch) {
        _logger.debug(
          'SessionManager.getOrCreateSession: invalidating stale session for $resolvedProviderId due to credential mismatch',
          tag: 'SessionManager',
        );
        await _sessionCache.deleteProviderSession(resolvedProviderId);
        session = null;
      }
      session = await _createSession(
        mediaItemId: mediaItemId,
        providerType: providerType,
        itemMetadata: itemMetadata,
        providerConfig: providerConfig,
        providerId: resolvedProviderId,
      );
    }

    _logger.debug(
      'SessionManager.getOrCreateSession: '
      'providerId=$resolvedProviderId, '
      'hasCachedSession=$hasCachedSession, '
      'sessionUsername=${session.username != null && session.username!.isNotEmpty}, '
      'sessionPassword=${session.password != null && session.password!.isNotEmpty}',
      tag: 'SessionManager',
    );

    session = await _authenticationEngine.ensureValidSession(session);

    if (session.cookies.isNotEmpty) {
      _cookieManager.setCookies(session.providerId, session.cookies);
    }

    await _sessionCache.saveProviderSession(session);
    return session;
  }

  Future<ProviderSession> _createSession({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    required Map<String, dynamic>? providerConfig,
    required String providerId,
  }) async {
    ProviderSessionFactory? factory = _registry.factoryFor(providerType);

    if (factory == null) {
      try {
        return await _registry.createSession(
          type: providerType,
          mediaItemId: mediaItemId,
          itemMetadata: itemMetadata,
          providerConfig: providerConfig,
          existing: await _sessionCache.getProviderSession(providerId),
        );
      } on StreamInvalidSessionException {
        rethrow;
      } catch (_) {
        throw StreamInvalidSessionException(
          message:
              'No provider session factory registered for $providerType.',
        );
      }
    }

    final session = await factory.createSession(
      mediaItemId: mediaItemId,
      itemMetadata: itemMetadata,
      providerConfig: providerConfig,
      existing: await _sessionCache.getProviderSession(providerId),
    );

    _eventBus.publish(
      SessionCreatedEvent(
        sessionId: session.sessionId,
        providerId: session.providerId,
        providerType: providerType,
        occurredAt: DateTime.now(),
      ),
    );

    _logger.info(
      'Provider session created for ${session.providerId} (${providerType.name})',
      tag: 'SessionManager',
    );
    return session;
  }

  Future<ProviderSession?> getSession(String providerId) async {
    return _sessionCache.getProviderSession(providerId);
  }

  Future<void> saveSession(ProviderSession session) async {
    await _sessionCache.saveProviderSession(session);
  }

  Future<ProviderSession> refreshSession(String providerId) async {
    final session = await _sessionCache.getProviderSession(providerId);
    if (session == null) {
      throw StateError('No session for provider $providerId');
    }
    final refreshed = await _authenticationEngine.refresh(session);
    await _sessionCache.saveProviderSession(refreshed);
    _eventBus.publish(
      SessionRefreshedEvent(
        sessionId: refreshed.sessionId,
        providerId: refreshed.providerId,
        expiresAt: refreshed.expiresAt,
        occurredAt: DateTime.now(),
      ),
    );
    return refreshed;
  }

  Future<void> invalidate(String providerId) async {
    await _sessionCache.deleteProviderSession(providerId);
    _cookieManager.clearProvider(providerId);
  }

  Future<bool> isAuthenticated(String providerId) async {
    final session = await _sessionCache.getProviderSession(providerId);
    if (session == null) return false;
    if (session.isExpired) return false;
    final result = await _authenticationEngine.validate(session);
    return result.isAuthenticated;
  }

  String _resolveProviderId(Map<String, dynamic> itemMetadata) {
    final explicit = itemMetadata['providerId']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final sourceUrl = itemMetadata['sourceUrl']?.toString();
    if (sourceUrl != null && sourceUrl.isNotEmpty) {
      return Uri.tryParse(sourceUrl)?.host ?? sourceUrl;
    }
    return itemMetadata['streamUrl']?.toString() ?? 'unknown_provider';
  }

  bool _hasCredentialMismatch(
    ProviderSession? session,
    Map<String, dynamic>? providerConfig,
  ) {
    if (session == null || providerConfig == null) return false;
    final configUsername = providerConfig['username']?.toString();
    final configPassword = providerConfig['password']?.toString();
    if ((configUsername == null || configUsername.isEmpty) &&
        (configPassword == null || configPassword.isEmpty)) {
      return false;
    }
    final sessionUsername = session.username;
    final sessionPassword = session.password;
    if (sessionUsername != configUsername || sessionPassword != configPassword) {
      return true;
    }
    return false;
  }
}
