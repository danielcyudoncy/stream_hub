import 'package:stream_hub/core/streaming/models/provider_session.dart';

/// Manages provider session lifecycle: authentication, refresh, and
/// invalidation. Backed by the session cache and the authentication engine.
abstract class AuthenticationRepository {
  Future<ProviderSession?> getSession(String providerId);

  Future<void> saveSession(ProviderSession session);

  Future<ProviderSession> refreshSession(String providerId);

  Future<void> invalidate(String providerId);

  Future<bool> isAuthenticated(String providerId);
}
