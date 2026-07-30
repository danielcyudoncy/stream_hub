import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/repositories/session_repository.dart';
import 'package:stream_hub/data/models/playback_session_model.dart';
import 'package:stream_hub/data/services/playback_local_service.dart';

class SessionRepositoryImpl implements SessionRepository {
  final PlaybackLocalService localService;
  final LoggingService logger;

  SessionRepositoryImpl(this.localService, {LoggingService? logger})
      : logger = logger ?? LoggingService();

  @override
  Future<void> saveSession(PlayableMediaSession session) async {
    await localService.saveSession(
      PlaybackSessionModel(
        id: session.id,
        itemId: session.mediaItem.id,
        providerType: session.providerId,
        resumePosition: session.resumePosition,
        completionPercentage: session.completionPercentage,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<PlayableMediaSession?> getSession(String id) async {
    await localService.getSession(id);
    return null;
  }

  @override
  Future<void> deleteSession(String id) async {
    await localService.deleteSession(id);
  }

  @override
  Future<void> clearSessions() async {
    await localService.clearSessions();
  }
}
