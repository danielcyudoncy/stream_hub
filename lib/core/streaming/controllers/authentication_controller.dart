import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/auth/authentication_engine.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/repositories/authentication_repository.dart';

/// Drives provider authentication state for the UI (login, logout, refresh).
class AuthenticationController extends GetxController {
  final AuthenticationRepository authenticationRepository;
  final AuthenticationEngine authenticationEngine;
  final LoggingService logger;

  final RxMap<String, bool> authenticatedProviders = <String, bool>{}.obs;
  final RxBool isAuthenticating = false.obs;
  final RxString errorMessage = ''.obs;

  AuthenticationController({
    required this.authenticationRepository,
    required this.authenticationEngine,
    LoggingService? logger,
  }) : logger = logger ?? LoggingService();

  Future<bool> login({
    required String providerId,
    required MediaSourceType providerType,
    required Map<String, dynamic> providerConfig,
  }) async {
    isAuthenticating.value = true;
    errorMessage.value = '';
    try {
      final session = ProviderSession(
        providerId: providerId,
        providerType: providerType,
        sessionId: 'auth_$providerId',
        username: providerConfig['username']?.toString(),
        password: providerConfig['password']?.toString(),
        macAddress: providerConfig['macAddress']?.toString(),
        baseUrl:
            providerConfig['serverUrl']?.toString() ??
            providerConfig['portalUrl']?.toString(),
        userAgent: providerConfig['userAgent']?.toString(),
        referer: providerConfig['referer']?.toString(),
        origin: providerConfig['origin']?.toString(),
        timeout: Duration(seconds: (providerConfig['timeout'] ?? 15)),
      );

      final validated = await authenticationEngine.ensureValidSession(session);
      await authenticationRepository.saveSession(validated);
      authenticatedProviders[providerId] = true;
      return true;
    } on StreamEngineException catch (e) {
      errorMessage.value = e.message;
      logger.error('Login failed', tag: 'AuthenticationController', error: e);
      authenticatedProviders[providerId] = false;
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      logger.error('Login failed', tag: 'AuthenticationController', error: e);
      authenticatedProviders[providerId] = false;
      return false;
    } finally {
      isAuthenticating.value = false;
    }
  }

  Future<void> logout(String providerId) async {
    await authenticationRepository.invalidate(providerId);
    authenticatedProviders.remove(providerId);
  }

  Future<void> refreshStatus(String providerId) async {
    authenticatedProviders[providerId] = await authenticationRepository
        .isAuthenticated(providerId);
  }

  Future<void> refreshAll(List<String> providerIds) async {
    for (final id in providerIds) {
      await refreshStatus(id);
    }
  }
}
