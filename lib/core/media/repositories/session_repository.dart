import 'package:stream_hub/core/media/player/playable_media_session.dart';

abstract class SessionRepository {
  Future<void> saveSession(PlayableMediaSession session);
  Future<PlayableMediaSession?> getSession(String id);
  Future<void> deleteSession(String id);
  Future<void> clearSessions();
}
