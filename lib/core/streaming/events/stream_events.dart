import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/stream_health_snapshot.dart';

/// Base event published by the Stream Engine.
abstract class StreamEvent {
  final DateTime occurredAt;

  const StreamEvent({required this.occurredAt});
}

/// Published when a provider session is created.
class SessionCreatedEvent extends StreamEvent {
  final String sessionId;
  final String providerId;
  final MediaSourceType providerType;

  const SessionCreatedEvent({
    required this.sessionId,
    required this.providerId,
    required this.providerType,
    required super.occurredAt,
  });
}

/// Published when a provider session is updated.
class SessionUpdatedEvent extends StreamEvent {
  final String sessionId;
  final String providerId;

  const SessionUpdatedEvent({
    required this.sessionId,
    required this.providerId,
    required super.occurredAt,
  });
}

/// Published when a provider session expires.
class SessionExpiredEvent extends StreamEvent {
  final String sessionId;
  final String providerId;

  const SessionExpiredEvent({
    required this.sessionId,
    required this.providerId,
    required super.occurredAt,
  });
}

/// Published when a provider session is refreshed.
class SessionRefreshedEvent extends StreamEvent {
  final String sessionId;
  final String providerId;
  final DateTime? expiresAt;

  const SessionRefreshedEvent({
    required this.sessionId,
    required this.providerId,
    this.expiresAt,
    required super.occurredAt,
  });
}

/// Published when a stream has been resolved.
class StreamResolvedEvent extends StreamEvent {
  final String sessionId;
  final String providerId;
  final String mediaItemId;
  final String resolvedUrl;
  final Duration resolutionTime;

  const StreamResolvedEvent({
    required this.sessionId,
    required this.providerId,
    required this.mediaItemId,
    required this.resolvedUrl,
    required this.resolutionTime,
    required super.occurredAt,
  });
}

/// Published when a playable session is ready for playback.
class PlaybackReadyEvent extends StreamEvent {
  final String sessionId;
  final String playableSessionId;
  final String mediaItemId;

  const PlaybackReadyEvent({
    required this.sessionId,
    required this.playableSessionId,
    required this.mediaItemId,
    required super.occurredAt,
  });
}

/// Published when a playable session is ready for download.
class DownloadReadyEvent extends StreamEvent {
  final String sessionId;
  final String playableSessionId;
  final String mediaItemId;

  const DownloadReadyEvent({
    required this.sessionId,
    required this.playableSessionId,
    required this.mediaItemId,
    required super.occurredAt,
  });
}

/// Published when authentication fails for a provider.
class AuthenticationFailedEvent extends StreamEvent {
  final String providerId;
  final String reason;

  const AuthenticationFailedEvent({
    required this.providerId,
    required this.reason,
    required super.occurredAt,
  });
}

/// Published whenever stream health is updated.
class HealthUpdatedEvent extends StreamEvent {
  final String sessionId;
  final StreamHealthSnapshot health;

  const HealthUpdatedEvent({
    required this.sessionId,
    required this.health,
    required super.occurredAt,
  });
}
