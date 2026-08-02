import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/repositories/authentication_repository.dart';
import 'package:stream_hub/core/streaming/session/session_manager.dart';

class AuthenticationRepositoryImpl implements AuthenticationRepository {
  final SessionManager sessionManager;

  AuthenticationRepositoryImpl(this.sessionManager);

  @override
  Future<ProviderSession?> getSession(String providerId) {
    return sessionManager.getSession(providerId);
  }

  @override
  Future<void> saveSession(ProviderSession session) {
    return sessionManager.saveSession(session);
  }

  @override
  Future<ProviderSession> refreshSession(String providerId) {
    return sessionManager.refreshSession(providerId);
  }

  @override
  Future<void> invalidate(String providerId) {
    return sessionManager.invalidate(providerId);
  }

  @override
  Future<bool> isAuthenticated(String providerId) {
    return sessionManager.isAuthenticated(providerId);
  }
}
