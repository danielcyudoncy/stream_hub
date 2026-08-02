import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/prepared_download.dart';
import 'package:stream_hub/core/streaming/models/stream_health_snapshot.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';

/// Drives playback preparation. The player consumes the resulting
/// [PlayableSession] — never raw provider URLs.
class PlaybackSessionController extends GetxController {
  final StreamRepository streamRepository;
  final LoggingService logger;

  final Rx<PlayableSession?> currentSession = Rx<PlayableSession?>(null);
  final RxBool isResolving = false.obs;
  final RxBool isValidating = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<StreamHealthSnapshot?> currentHealth = Rx<StreamHealthSnapshot?>(
    null,
  );

  PlaybackSessionController({
    required this.streamRepository,
    LoggingService? logger,
  }) : logger = logger ?? LoggingService();

  Future<PlayableSession?> resolvePlayback({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
    bool useCache = true,
    bool validate = true,
  }) async {
    isResolving.value = true;
    errorMessage.value = '';
    try {
      final session = await streamRepository.resolvePlayback(
        mediaItemId: mediaItemId,
        providerType: providerType,
        itemMetadata: itemMetadata,
        providerId: providerId,
        fallbackUrl: fallbackUrl,
        useCache: useCache,
        validate: validate,
      );
      currentSession.value = session;
      return session;
    } on StreamEngineException catch (e) {
      errorMessage.value = e.message;
      logger.error(
        'Playback resolution failed',
        tag: 'PlaybackSessionController',
        error: e,
      );
      return null;
    } finally {
      isResolving.value = false;
    }
  }

  Future<bool> revalidate() async {
    final session = currentSession.value;
    if (session == null) return false;
    isValidating.value = true;
    try {
      final valid = await streamRepository.validate(session);
      if (!valid) {
        errorMessage.value = 'Stream is no longer valid. Retrying...';
        currentSession.value = await streamRepository.selectWorking(session);
      }
      return valid;
    } catch (e) {
      errorMessage.value = 'Validation failed: $e';
      logger.error(
        'Stream revalidation failed',
        tag: 'PlaybackSessionController',
        error: e,
      );
      return false;
    } finally {
      isValidating.value = false;
    }
  }

  Future<PreparedDownload?> prepareDownload({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
  }) async {
    isResolving.value = true;
    errorMessage.value = '';
    try {
      return await streamRepository.prepareDownload(
        mediaItemId: mediaItemId,
        providerType: providerType,
        itemMetadata: itemMetadata,
        providerId: providerId,
        fallbackUrl: fallbackUrl,
      );
    } on StreamEngineException catch (e) {
      errorMessage.value = e.message;
      logger.error(
        'Download preparation failed',
        tag: 'PlaybackSessionController',
        error: e,
      );
      return null;
    } finally {
      isResolving.value = false;
    }
  }

  void clear() {
    currentSession.value = null;
    currentHealth.value = null;
    errorMessage.value = '';
  }
}
