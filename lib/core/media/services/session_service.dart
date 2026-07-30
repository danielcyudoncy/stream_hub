import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';

class SessionService {
  final LoggingService logger;
  final List<PlayableMediaSession> _activeSessions = [];
  final Map<String, PlayableMediaSession> _sessionMap = {};

  SessionService({LoggingService? logger})
      : logger = logger ?? LoggingService();

  void registerSession(PlayableMediaSession session) {
    _activeSessions.add(session);
    _sessionMap[session.id] = session;
    logger.info('Session registered: ${session.id}', tag: 'SessionService');
  }

  void unregisterSession(String sessionId) {
    _activeSessions.removeWhere((s) => s.id == sessionId);
    _sessionMap.remove(sessionId);
    logger.info('Session unregistered: $sessionId', tag: 'SessionService');
  }

  PlayableMediaSession? getSession(String sessionId) {
    return _sessionMap[sessionId];
  }

  List<PlayableMediaSession> getActiveSessions() {
    return List.unmodifiable(_activeSessions);
  }

  void clearAll() {
    _activeSessions.clear();
    _sessionMap.clear();
    logger.info('All sessions cleared', tag: 'SessionService');
  }
}
