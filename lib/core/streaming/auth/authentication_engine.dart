import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/auth/authentication_result.dart';
import 'package:stream_hub/core/streaming/events/stream_event_bus.dart';
import 'package:stream_hub/core/streaming/events/stream_events.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';

/// Provider-specific authentication logic (token refresh, session renewal,
/// credential validation).
///
/// Every provider type registers an [AuthenticationProvider] so the
/// [AuthenticationEngine] remains provider-agnostic.
abstract class AuthenticationProvider {
  MediaSourceType get providerType;

  /// Validates whether the session's credentials are still accepted.
  Future<AuthenticationResult> validate(ProviderSession session);

  /// Produces a renewed session (fresh token, new expiry, updated cookies).
  Future<ProviderSession> refresh(ProviderSession session);

  /// Whether this provider supports automatic refresh.
  bool get supportsRefresh => true;
}

/// Orchestrates authentication for every provider type: session expiry checks,
/// token refresh, session renewal, validation, and secure credential storage.
///
/// The engine never logs credentials. Sensitive data is persisted through the
/// session cache (encrypted) rather than held in plain text.
class AuthenticationEngine {
  final Map<MediaSourceType, AuthenticationProvider> _providers = {};
  final StreamEventBus _eventBus;

  AuthenticationEngine({StreamEventBus? eventBus})
    : _eventBus = eventBus ?? StreamEventBus();

  void registerProvider(AuthenticationProvider provider) {
    _providers[provider.providerType] = provider;
  }

  AuthenticationProvider? providerFor(MediaSourceType type) => _providers[type];

  /// Ensures the session is valid, refreshing it when expired or invalid.
  ///
  /// Throws [StreamAuthException] when the session cannot be renewed.
  Future<ProviderSession> ensureValidSession(ProviderSession session) async {
    final provider = _providers[session.providerType];

    var quickCheckFailed = false;
    if (!session.isExpired && session.requiresAuth) {
      final quickCheck = await validate(session);
      if (quickCheck.isAuthenticated) {
        return session;
      }
      quickCheckFailed = true;
    }

    if (session.isExpired || !session.requiresAuth || quickCheckFailed) {
      if (session.isExpired) {
        _eventBus.publish(
          SessionExpiredEvent(
            sessionId: session.sessionId,
            providerId: session.providerId,
            occurredAt: DateTime.now(),
          ),
        );
      }
      if (provider != null && provider.supportsRefresh) {
        try {
          final refreshed = await provider.refresh(session);
          _eventBus.publish(
            SessionRefreshedEvent(
              sessionId: refreshed.sessionId,
              providerId: refreshed.providerId,
              expiresAt: refreshed.expiresAt,
              occurredAt: DateTime.now(),
            ),
          );
          return refreshed;
        } on StreamEngineException {
          rethrow;
        } catch (e) {
          throw StreamAuthException(
            message:
                'Session refresh failed for provider ${session.providerId}.',
            originalError: e,
          );
        }
      }
    }

    final result = await validate(session);
    if (!result.isAuthenticated) {
      _eventBus.publish(
        AuthenticationFailedEvent(
          providerId: session.providerId,
          reason: result.error ?? 'Authentication validation failed.',
          occurredAt: DateTime.now(),
        ),
      );
      throw StreamAuthException(
        message: 'Provider ${session.providerId} is not authenticated.',
        originalError: result.error,
      );
    }
    return session;
  }

  /// Validates the session using its registered provider.
  Future<AuthenticationResult> validate(ProviderSession session) async {
    final provider = _providers[session.providerType];
    if (provider == null) {
      return AuthenticationResult.authenticated(expiresAt: session.expiresAt);
    }
    try {
      return await provider.validate(session);
    } catch (e) {
      return AuthenticationResult.failed('Validation error: $e');
    }
  }

  /// Refreshes the session using its registered provider.
  Future<ProviderSession> refresh(ProviderSession session) async {
    final provider = _providers[session.providerType];
    if (provider == null || !provider.supportsRefresh) {
      return session;
    }
    final refreshed = await provider.refresh(session);
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

  /// Applies the session's authentication to a stream URL. Providers that
  /// embed credentials in the URL (e.g. Xtream) return an authenticated URL;
  /// header-based providers return the URL unchanged.
  String applyAuthenticationToUrl(ProviderSession session, String url) {
    if (session.portalToken != null && session.username != null) {
      final uri = Uri.parse(url);
      return uri
          .replace(
            queryParameters: {
              ...uri.queryParameters,
              'token': session.portalToken!,
              if (session.username != null) 'username': session.username!,
            },
          )
          .toString();
    }
    return url;
  }
}
