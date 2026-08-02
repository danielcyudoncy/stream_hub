import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/repositories/authentication_repository.dart';
import 'package:stream_hub/core/streaming/repositories/stream_cache_repository.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';

/// Exposes provider session lifecycle state to the UI (e.g. session status
/// badges in the provider manager).
class SessionController extends GetxController {
  final AuthenticationRepository authenticationRepository;
  final StreamCacheRepository streamCacheRepository;
  final StreamRepository streamRepository;
  final LoggingService logger;

  final Rx<ProviderSession?> activeSession = Rx<ProviderSession?>(null);
  final RxMap<String, ProviderSession> sessions =
      <String, ProviderSession>{}.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  SessionController({
    required this.authenticationRepository,
    required this.streamCacheRepository,
    required this.streamRepository,
    LoggingService? logger,
  }) : logger = logger ?? LoggingService();

  Future<ProviderSession?> getOrCreateSession({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    Map<String, dynamic>? providerConfig,
  }) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final playable = await streamRepository.resolvePlayback(
        mediaItemId: mediaItemId,
        providerType: providerType,
        itemMetadata: itemMetadata,
        providerId: providerId,
        useCache: false,
      );
      final session = await authenticationRepository.getSession(
        playable.providerId,
      );
      if (session != null) {
        activeSession.value = session;
        sessions[session.providerId] = session;
      }
      return session;
    } on StreamEngineException catch (e) {
      errorMessage.value = e.message;
      logger.error(
        'Session creation failed',
        tag: 'SessionController',
        error: e,
      );
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshSession(String providerId) async {
    errorMessage.value = '';
    try {
      final refreshed = await authenticationRepository.refreshSession(
        providerId,
      );
      activeSession.value = refreshed;
      sessions[providerId] = refreshed;
    } on StreamEngineException catch (e) {
      errorMessage.value = e.message;
      logger.error(
        'Session refresh failed',
        tag: 'SessionController',
        error: e,
      );
    }
  }

  Future<void> invalidate(String providerId) async {
    await authenticationRepository.invalidate(providerId);
    sessions.remove(providerId);
    if (activeSession.value?.providerId == providerId) {
      activeSession.value = null;
    }
  }

  Future<bool> isAuthenticated(String providerId) async {
    return authenticationRepository.isAuthenticated(providerId);
  }

  Future<void> clearAll() async {
    await streamCacheRepository.clearAll();
    sessions.clear();
    activeSession.value = null;
  }
}
